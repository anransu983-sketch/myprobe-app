import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../terminal.dart';
import '../widgets/widgets.dart';

/// 最近连接记录
class _RecentConn {
  final String name, host, user;
  final int port, ts;
  _RecentConn(this.name, this.host, this.user, this.port, this.ts);
  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'user': user,
        'port': port,
        'ts': ts,
      };
  static _RecentConn fromJson(Map<String, dynamic> j) => _RecentConn(
        '${j['name'] ?? ''}',
        '${j['host'] ?? ''}',
        '${j['user'] ?? 'root'}',
        (j['port'] as num?)?.toInt() ?? 22,
        (j['ts'] as num?)?.toInt() ?? 0,
      );
}

/// 合并主机列表的一行：node 非空 = 探针节点行（recent 只是命中的最近记录，
/// 借它显示时间）；node 为空 = 仅最近连过的临时主机行（recent 本体）
class _HostRow {
  final ProbeNode? node;
  final _RecentConn? recent;
  const _HostRow.node(this.node, this.recent);
  const _HostRow.temp(this.recent) : node = null;
  int get ts => recent?.ts ?? -1;
}

String _ago(int ts) {
  final d = DateTime.now().millisecondsSinceEpoch ~/ 1000 - ts;
  if (d < 60) return '刚刚';
  if (d < 3600) return '${d ~/ 60}分钟前';
  if (d < 86400) return '${d ~/ 3600}小时前';
  return '${d ~/ 86400}天前';
}

/// 底部第 3 个 Tab：SSH 终端（走服务端内置 Web SSH，需管理员）
/// JuiceSSH 风格：快速连接 / 主机（探针节点与常用连接合并） / 代码片段
class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key});
  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  List<ProbeNode>? _nodes;
  String? _err;

  final _qHost = TextEditingController();
  final _qUser = TextEditingController(text: 'root');
  final _qPort = TextEditingController(text: '22');
  final _qPw = TextEditingController();

  List<_RecentConn> _recents = [];
  List<String> _snippets = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocal();
  }

  @override
  void dispose() {
    _qHost.dispose();
    _qUser.dispose();
    _qPort.dispose();
    _qPw.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final nodes = await AppState.instance.client.getNodes();
      if (mounted) setState(() => _nodes = nodes);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final rj = p.getString('mp_ssh_recent');
      if (rj != null) {
        try {
          _recents = (json.decode(rj) as List)
              .map((e) =>
                  _RecentConn.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      _snippets =
          p.getStringList('mp_ssh_snippets') ?? ['df -h', 'docker ps', 'uptime'];
    });
  }

  Future<void> _saveRecents() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('mp_ssh_recent',
        json.encode(_recents.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveSnippets() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('mp_ssh_snippets', _snippets);
  }

  void _addRecent(String name, String host, String user, int port) {
    _recents.removeWhere(
        (e) => e.host == host && e.port == port && e.user == user);
    _recents.insert(
        0,
        _RecentConn(name, host, user, port,
            DateTime.now().millisecondsSinceEpoch ~/ 1000));
    if (_recents.length > 8) _recents = _recents.sublist(0, 8);
    _saveRecents();
    if (mounted) setState(() {});
  }

  void _removeRecent(_RecentConn r) {
    _recents.remove(r);
    _saveRecents();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🎸 终端',
        actions: [
          IconButton(
            icon: Icon(AppState.instance.hideIp
                ? Icons.visibility_off
                : Icons.visibility),
            tooltip: '显示/隐藏 IP',
            onPressed: () => AppState.instance.toggleHideIp(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (_, __) {
          final admin = AppState.instance.client.admin;
          final pending = AppState.instance.consumeTerminalNode();
          if (pending != null && admin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openConnect(pending);
            });
          }
          if (!admin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.lock_outline,
                      size: 48, color: BocchiTheme.pink),
                  const SizedBox(height: 12),
                   Text('终端需要管理员登录',
                      style: TextStyle(color: BocchiTheme.inkSoft)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => AppState.instance.goTab(3),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            );
          }
          if (_err != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败：$_err',
                      style:
                           TextStyle(color: BocchiTheme.inkSoft)),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _load, child: const Text('重试')),
                ],
              ),
            );
          }
          if (_nodes == null) {
            return  Center(
                child: CircularProgressIndicator(
                    color: BocchiTheme.pinkDeep));
          }
          final nodes = _nodes!
              .where((n) => (n.sshHost ?? '').isNotEmpty)
              .toList();
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                // 终端页保持普通 Card 不玻璃化（既定口径），只借
                // StaggeredEntrance 做同款入场渐进，index 依次 0/1/2 错峰
                StaggeredEntrance(index: 0, child: _quickCard()),
                StaggeredEntrance(index: 1, child: _hostsCard(nodes)),
                StaggeredEntrance(index: 2, child: _snippetCard()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cardHead(String emoji, String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$emoji $title',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(sub,
            style:  TextStyle(
                fontSize: 12, color: BocchiTheme.inkSoft)),
      ],
    );
  }

  /// ⚡ 快速连接
  Widget _quickCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHead('⚡', '快速连接', '连接到任意主机（免事先录入节点）'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _qHost,
                    decoration: const InputDecoration(
                      labelText: '主机 IP/域名',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _qUser,
                    decoration: const InputDecoration(
                      labelText: '用户',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qPort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _qPw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'SSH 密码',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.key),
              ),
              onSubmitted: (_) => _quickGo(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _quickGo,
              icon: const Icon(Icons.bolt),
              label: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }

  void _quickGo() {
    final host = _qHost.text.trim();
    final user = _qUser.text.trim().isEmpty ? 'root' : _qUser.text.trim();
    final port = int.tryParse(_qPort.text.trim()) ?? 22;
    final pw = _qPw.text;
    if (host.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写主机 IP/域名')));
      return;
    }
    if (pw.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写 SSH 密码')));
      return;
    }
    _runConnect(
      sessionTitle: '$user@$host',
      pw: pw,
      dial: (p) => AppState.instance.client
          .sshConnectCustom(host, port, user, p),
      recent: _RecentConn('$user@$host', host, user, port, 0),
    );
    _qPw.clear();
  }

  /// 常用记录与节点是不是同一台机器（与 _addRecent 的去重键一致：host+port+user）
  bool _sameHost(_RecentConn r, ProbeNode n) =>
      r.host == (n.sshHost ?? '') &&
      r.port == (n.sshPort ?? 22) &&
      r.user == (n.sshUser ?? 'root');

  /// 🖥️ 主机：探针节点（已存凭据）与常用连接（最近连过）合并成一个列表。
  /// 原先两个列表装着同一批机器、同台出现两次。现在一台一行：
  /// 命中节点的最近记录只借它的时间（显示「最近 xx 前」小字），行本身
  /// 仍走节点直连；没进节点的临时主机单独成行，点一下输密码连，保留 × 删历史。
  /// 排序：有最近记录的行（节点行+临时行）按最近时间倒序置顶，
  /// 其余节点按节点原序随后。
  Widget _hostsCard(List<ProbeNode> nodes) {
    final matched = <ProbeNode, _RecentConn>{};
    final temps = <_RecentConn>[];
    for (final r in _recents) {
      ProbeNode? hit;
      for (final n in nodes) {
        if (_sameHost(r, n)) {
          hit = n;
          break;
        }
      }
      if (hit != null) {
        final old = matched[hit];
        if (old == null || r.ts > old.ts) matched[hit] = r;
      } else {
        temps.add(r);
      }
    }
    final rows = <_HostRow>[
      ...[
        for (final n in nodes)
          if (matched.containsKey(n)) _HostRow.node(n, matched[n]),
        for (final r in temps) _HostRow.temp(r),
      ]..sort((a, b) => b.ts.compareTo(a.ts)),
      for (final n in nodes)
        if (!matched.containsKey(n)) _HostRow.node(n, null),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHead('🖥️', '主机', '已存凭据的节点点按直连；仅最近连过的点一下输密码连'),
            const SizedBox(height: 4),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('没有配置 SSH 的节点\n请先在网页管理页给节点配好 SSH',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BocchiTheme.inkSoft)),
              )
            else
              for (final row in rows) _hostTile(row),
          ],
        ),
      ),
    );
  }

  Widget _hostTile(_HostRow row) {
    final n = row.node;
    if (n != null) {
      // 节点行：已存凭据，点按走 _openConnect（可留空用服务端已存密码）
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: OnlineDot(online: n.online),
        title: Row(
          children: [
            Flexible(
              child: Text(n.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            _connTag('可直连', true),
          ],
        ),
        subtitle: Text(
          '${n.sshUser ?? 'root'}@${AppState.instance.showIp(n.sshHost ?? '')}:${n.sshPort ?? 22}',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.recent != null)
              Text(_ago(row.recent!.ts),
                  style: TextStyle(
                      fontSize: 11, color: BocchiTheme.inkSoft)),
            Icon(Icons.chevron_right, color: BocchiTheme.pinkDeep),
          ],
        ),
        onTap: () => _openConnect(n),
      );
    }
    // 临时主机行：仅最近连过，点一下输密码连，× 删历史（原常用连接行为）
    final r = row.recent!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const OnlineDot(online: true),
      title: Row(
        children: [
          Flexible(
            child: Text(r.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          _connTag('输密码连', false),
        ],
      ),
      subtitle: Text(
        '${r.user}@${AppState.instance.showIp(r.host)}:${r.port}',
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_ago(r.ts),
              style: TextStyle(fontSize: 11, color: BocchiTheme.inkSoft)),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: BocchiTheme.inkSoft,
            onPressed: () => _removeRecent(r),
          ),
        ],
      ),
      onTap: () => _openCustomConnect(r),
    );
  }

  /// 行内小标签：一眼区分这行点下去是直连还是要输密码
  Widget _connTag(String text, bool direct) {
    final c = direct ? BocchiTheme.okGreen : BocchiTheme.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }

  /// 📝 代码片段
  Widget _snippetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHead('📝', '代码片段', '常用命令存这，会话里点一下即发送'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _snippets.length; i++)
                  _snippetChip(_snippets[i], i),
                ActionChip(
                  label: const Text('＋ 添加'),
                  onPressed: _addSnippet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snippetChip(String s, int i) {
    return GestureDetector(
      onLongPress: () => _delSnippet(i),
      child: ActionChip(
        label: Text(s,
            style: const TextStyle(fontFamily: 'monospace')),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: s));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制到剪贴板（长按删除）')));
        },
      ),
    );
  }

  void _addSnippet() {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // v1.16: 与省份选择一致改走 GlassSheet 玻璃抽屉（调用处底色透明，
      // BackdropFilter 才能采样到背后的页面/壁纸）
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('添加代码片段',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '命令（不含回车，发送时自动加）',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                Navigator.of(ctx).pop();
                _saveSnippet(c.text.trim());
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _saveSnippet(c.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _saveSnippet(String s) {
    if (s.isEmpty) return;
    setState(() => _snippets.add(s));
    _saveSnippets();
  }

  void _delSnippet(int i) {
    final s = _snippets[i];
    setState(() => _snippets.removeAt(i));
    _saveSnippets();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除：$s')));
  }

  /// 节点连接：密码弹窗
  void _openConnect(ProbeNode n) {
    _askPassword(
      title: '连接 ${n.name}',
      subtitle:
          '${n.sshUser ?? 'root'}@${AppState.instance.showIp(n.sshHost ?? '')}',
      onGo: (pw) => _runConnect(
        sessionTitle: n.name,
        pw: pw,
        dial: (p) => AppState.instance.client.sshConnect(
            n.id,
            password: p.isEmpty ? null : p,
            cols: 100,
            rows: 30),
        recent: _RecentConn(n.name, n.sshHost ?? '',
            n.sshUser ?? 'root', n.sshPort ?? 22, 0),
      ),
    );
  }

  /// 常用连接：密码弹窗
  void _openCustomConnect(_RecentConn r) {
    _askPassword(
      title: '连接 ${r.name}',
      subtitle:
          '${r.user}@${AppState.instance.showIp(r.host)}:${r.port}',
      onGo: (pw) => _runConnect(
        sessionTitle: r.name,
        pw: pw,
        dial: (p) => AppState.instance.client
            .sshConnectCustom(r.host, r.port, r.user, p),
        recent: r,
      ),
    );
  }

  void _askPassword({
    required String title,
    required String subtitle,
    required void Function(String pw) onGo,
  }) {
    final pw = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // v1.16: 与省份选择一致改走 GlassSheet 玻璃抽屉（调用处底色透明，
      // BackdropFilter 才能采样到背后的页面/壁纸）
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                style:  TextStyle(
                    color: BocchiTheme.inkSoft,
                    fontFamily: 'monospace')),
            const SizedBox(height: 12),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'SSH 密码（节点可留空用服务端已存密码）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              onSubmitted: (_) {
                Navigator.of(ctx).pop();
                onGo(pw.text);
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                onGo(pw.text);
              },
              icon: const Icon(Icons.terminal),
              label: const Text('连接'),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// 通用连接流程：loading（必关）→ 建会话 → 进终端 → 记入常用
  /// 用页面级 context，v1.6.1 已修菊花关不掉的 bug
  Future<void> _runConnect({
    required String sessionTitle,
    required String pw,
    required Future<String> Function(String pw) dial,
    _RecentConn? recent,
  }) async {
    final nav = Navigator.of(context);
    var loading = true;
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>  Center(
          child: CircularProgressIndicator(
              color: BocchiTheme.pinkDeep)),
    ).then((_) => loading = false));
    void closeLoading() {
      if (loading) {
        loading = false;
        nav.pop();
      }
    }

    try {
      final sid = await dial(pw);
      closeLoading();
      if (recent != null) {
        _addRecent(
            recent.name, recent.host, recent.user, recent.port);
      }
      if (!mounted) return;
      nav.push(MaterialPageRoute(
          builder: (_) =>
              TerminalScreen(title: sessionTitle, sessionId: sid)));
    } catch (e) {
      closeLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败：$e')));
    }
  }
}

/// 终端会话页
class TerminalScreen extends StatefulWidget {
  final String title;
  final String sessionId;
  const TerminalScreen(
      {super.key, required this.title, required this.sessionId});

  @override
  State<TerminalScreen> createState() =>
      _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final TermBuffer _term;
  Timer? _poll;
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _ctrl = false;
  bool _closed = false;
  bool _atBottom = true;
  List<String> _snippets = [];

  MyProbeClient get _api => AppState.instance.client;

  @override
  void initState() {
    super.initState();
    _term = TermBuffer(cols: 100, rows: 30);
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      _atBottom = _scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 40;
    });
    _term.addListener(_maybeScroll);
    _poll = Timer.periodic(
        const Duration(milliseconds: 300), (_) => _doPoll());
    _doPoll();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _snippets = p.getStringList('mp_ssh_snippets') ??
            ['df -h', 'docker ps', 'uptime'];
      });
    });
  }

  void _maybeScroll() {
    if (_atBottom && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _doPoll() async {
    if (_closed || !mounted) return;
    try {
      final r = await _api.sshPoll(widget.sessionId);
      final data = r['data'] as String;
      if (data.isNotEmpty) _term.write(data);
      if (r['closed'] == true && !_closed) {
        _closed = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SSH 会话已断开')));
        }
      }
    } catch (_) {
      // 轮询失败忽略，下次继续
    }
  }

  Future<void> _send(String s) async {
    if (_closed) return;
    try {
      await _api.sshInput(widget.sessionId, s);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败：$e')));
      }
    }
  }

  void _submitInput() {
    final t = _input.text;
    _input.clear();
    if (_ctrl && t.isNotEmpty) {
      final c = t[0].toLowerCase().codeUnitAt(0);
      if (c >= 97 && c <= 122) {
        _send(String.fromCharCode(c - 96) + t.substring(1));
      } else {
        _send(t);
      }
      setState(() => _ctrl = false);
    } else {
      _send('$t\n');
    }
    _focus.requestFocus();
  }

  void _special(String seq) {
    if (_ctrl) setState(() => _ctrl = false);
    _send(seq);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _term.removeListener(_maybeScroll);
    _term.dispose();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    _api.sshClose(widget.sessionId).catchError((_) {});
    super.dispose();
  }

  Widget _keyBtn(String label, String seq, {bool toggle = false}) {
    final active = toggle && _ctrl;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color:
              active ? BocchiTheme.pinkDeep : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => toggle
                ? setState(() => _ctrl = !_ctrl)
                : _special(seq),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(label,
                  style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.grey.shade300,
                      fontSize: 13,
                      fontFamily: 'monospace')),
            ),
          ),
        ),
      ),
    );
  }

  /// 📝 代码片段快捷栏：点一下即发送
  Widget _snippetBar() {
    if (_snippets.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text('📝',
                  style: TextStyle(fontSize: 14)),
            ),
            for (final s in _snippets)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink.shade200,
                    side:  BorderSide(
                        color: BocchiTheme.pink),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _send('$s\n'),
                  child: Text(s,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '断开',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: ListenableBuilder(
                  listenable: _term,
                  builder: (_, __) => SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(8),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.25,
                            color: Colors.white),
                        children:
                            _term.buildSpans(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  _keyBtn('ESC', ''),
                  _keyBtn('TAB', '\t'),
                  _keyBtn('CTRL', '', toggle: true),
                  _keyBtn('↑', '[A'),
                  _keyBtn('↓', '[B'),
                  _keyBtn('←', '[D'),
                  _keyBtn('→', '[C'),
                ],
              ),
            ),
            _snippetBar(),
            Container(
              color: Colors.grey.shade900,
              padding:
                  const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _ctrl ? 'Ctrl+?' : '输入命令…',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10),
                      ),
                      onSubmitted: (_) => _submitInput(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            BocchiTheme.pinkDeep),
                    onPressed: _submitInput,
                    child: const Text('发送'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
