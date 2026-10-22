import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';

/// SSH 凭据（设置 → 探针服务器 → SSH 凭据）：
/// 逐节点维护 SSH 主机/端口/用户名/密码，密码只存服务端
/// （nodes 表 Fernet 加密），App 本地不落存任何密码。
/// v1.11.0：新增 VPS 入口（先经服务端 v6.5 建节点接口存入服务器，
/// 再存 SSH 凭据）+ 标题栏眼睛按钮遮挡 IP（跟节点页/终端页一致）。
class SshCredsPage extends StatefulWidget {
  const SshCredsPage({super.key});
  @override
  State<SshCredsPage> createState() => _SshCredsPageState();
}

class _SshCredsPageState extends State<SshCredsPage> {
  List<ProbeNode>? _nodes;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ns = await AppState.instance.client.getNodes();
      if (mounted) {
        setState(() {
          _nodes = ns;
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听 AppState：切换 IP 遮挡后列表立即重绘（眼睛按钮与节点页一致）
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final admin = AppState.instance.client.admin;
        return Scaffold(
          appBar: GradientAppBar(
            title: 'SSH 凭据',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(AppState.instance.hideIp
                    ? Icons.visibility_off
                    : Icons.visibility),
                tooltip: '显示/隐藏 IP',
                onPressed: () => AppState.instance.toggleHideIp(),
              ),
              if (admin)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '新增 VPS',
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) => const SshCredAddPage()),
                    );
                    if (changed == true) _load();
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
               Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '给每个节点填一次 SSH 地址和 root 密码，之后在终端点节点即可直接连接。密码加密保存在服务器，App 本地不保存。',
                  style: TextStyle(fontSize: 12, color: BocchiTheme.inkSoft),
                ),
              ),
              if (!admin)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('请先在设置页登录管理员，再编辑 SSH 凭据。',
                        style: TextStyle(color: BocchiTheme.warnRed)),
                  ),
                )
              else if (_err != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('加载节点失败：$_err',
                        style: const TextStyle(color: BocchiTheme.warnRed)),
                  ),
                )
              else if (_nodes == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_nodes!.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('暂无节点'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < _nodes!.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _row(_nodes![i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(ProbeNode n) {
    final hasHost = (n.sshHost ?? '').isNotEmpty;
    return ListTile(
      leading:  Icon(Icons.terminal, color: BocchiTheme.pinkDeep),
      title: Text(n.name),
      subtitle: Text(
        hasHost
            ? '${n.sshUser ?? 'root'}@${AppState.instance.showIp(n.sshHost!)}:${n.sshPort ?? 22}'
            : '未配置 SSH 地址',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (n.sshReady ? BocchiTheme.okGreen : BocchiTheme.inkSoft)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              n.sshReady ? '密码已保存' : '密码未保存',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: n.sshReady ? BocchiTheme.okGreen : BocchiTheme.inkSoft,
              ),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => SshCredEditPage(node: n)),
        );
        if (changed == true) _load();
      },
    );
  }
}

/// 新增 VPS：先在服务端建节点（POST /api/admin/nodes，需服务端 v6.5+），
/// 再把 SSH 凭据存入服务器；成功后展示探针一键安装命令。
class SshCredAddPage extends StatefulWidget {
  const SshCredAddPage({super.key});
  @override
  State<SshCredAddPage> createState() => _SshCredAddPageState();
}

class _SshCredAddPageState extends State<SshCredAddPage> {
  static final _idRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

  final _name = TextEditingController();
  final _nodeId = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController(text: 'root');
  final _pass = TextEditingController();
  bool _busy = false;
  bool _showPass = false;

  // 保存成功后的状态：展示安装命令区块
  String? _createdId;
  String? _installCmd;
  bool _createdNoPass = false;

  @override
  void dispose() {
    _name.dispose();
    _nodeId.dispose();
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _genId() {
    // 'vps-' + 毫秒时间戳 base36，保证匹配服务端节点 ID 正则
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'vps-$t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '新增 VPS',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.of(context).pop(_createdId != null),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('新节点信息',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BocchiTheme.ink)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    enabled: _createdId == null,
                    decoration: const InputDecoration(
                      labelText: '显示名（必填）',
                      hintText: '如 日本东京',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nodeId,
                    enabled: _createdId == null,
                    decoration: const InputDecoration(
                      labelText: '节点 ID（选填）',
                      hintText: '留空自动生成',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _host,
                    enabled: _createdId == null,
                    decoration: const InputDecoration(
                      labelText: 'SSH IP（必填）',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _port,
                    enabled: _createdId == null,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口（默认 22）',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _user,
                    enabled: _createdId == null,
                    decoration: const InputDecoration(
                      labelText: '用户名（默认 root）',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pass,
                    enabled: _createdId == null,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: 'root 密码（选填）',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(_showPass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _showPass = !_showPass),
                      ),
                    ),
                  ),
                   Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '节点与凭据都存入服务器（密码 Fernet 加密），App 本地不保存。未填密码将显示「密码未保存」，可稍后在列表里点进该节点补填。',
                      style: TextStyle(
                          fontSize: 12, color: BocchiTheme.inkSoft),
                    ),
                  ),
                  if (_createdId == null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BocchiTheme.pinkDeep,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('保存到服务器'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_createdId != null) _installCard(),
        ],
      ),
    );
  }

  Widget _installCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('✅ 已存入服务器',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: BocchiTheme.ink)),
            const SizedBox(height: 8),
            Text(
              _createdNoPass
                  ? '节点「$_createdId」已创建，SSH 密码未填（列表里显示「密码未保存」）。'
                  : '节点「$_createdId」已创建，SSH 凭据已保存。',
              style:
                   TextStyle(fontSize: 12, color: BocchiTheme.inkSoft),
            ),
            const SizedBox(height: 12),
             Text('探针安装命令',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: BocchiTheme.ink)),
            const SizedBox(height: 6),
             Text(
              '在新机上跑这条命令装探针，节点即上线；不装也能先在终端页用已存凭据直连。',
              style: TextStyle(fontSize: 12, color: BocchiTheme.inkSoft),
            ),
            const SizedBox(height: 8),
            if (_installCmd != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BocchiTheme.ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _installCmd!,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制安装命令'),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _installCmd!));
                    if (mounted) showOk(context, '已复制');
                  },
                ),
              ),
            ] else
              const Text('安装命令获取失败（agent token 拉取失败），可到网页端管理页查看一键安装命令。',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.warnRed)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BocchiTheme.pinkDeep,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showErr(context, ApiError('请填写显示名'));
      return;
    }
    if (name.length > 64) {
      showErr(context, ApiError('显示名最长 64 字'));
      return;
    }
    var id = _nodeId.text.trim();
    if (id.isEmpty) {
      id = _genId();
    } else if (!_idRe.hasMatch(id)) {
      showErr(context,
          ApiError('节点 ID 不合法：字母/数字开头，可含 - _，最长 64 位'));
      return;
    }
    final host = _host.text.trim();
    if (host.isEmpty) {
      showErr(context, ApiError('请填写 SSH IP'));
      return;
    }
    final portText = _port.text.trim().isEmpty ? '22' : _port.text.trim();
    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      showErr(context, ApiError('端口必须是 1-65535 的数字'));
      return;
    }
    final user = _user.text.trim().isEmpty ? 'root' : _user.text.trim();
    final noPass = _pass.text.isEmpty;

    setState(() => _busy = true);
    try {
      final client = AppState.instance.client;
      // 1) 先在服务端建节点（老服务端会由 nodeCreate 给出升级提示）
      await client.nodeCreate(id, name);
      // 2) 再把 SSH 凭据存入服务器（密码仅非空才发送）
      final d = <String, dynamic>{
        'ssh_host': host,
        'ssh_port': portText,
        'ssh_user': user,
      };
      if (!noPass) d['ssh_password'] = _pass.text;
      await client.nodeMeta(id, d);
      // 3) 拼探针一键安装命令（token 拉不到不阻断，成功状态照常展示）
      String? cmd;
      try {
        final tok = await client.agentToken();
        if (tok != null) {
          final origin = client.baseUrl;
          cmd =
              'curl -fsSL $origin/dl/agent-install.sh | bash -s -- $origin $tok $id "$name"';
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _createdId = id;
          _installCmd = cmd;
          _createdNoPass = noPass;
        });
        showOk(context, '已新增并保存到服务器');
      }
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 单节点 SSH 凭据编辑页
class SshCredEditPage extends StatefulWidget {
  final ProbeNode node;
  const SshCredEditPage({super.key, required this.node});
  @override
  State<SshCredEditPage> createState() => _SshCredEditPageState();
}

class _SshCredEditPageState extends State<SshCredEditPage> {
  late final _host = TextEditingController(text: widget.node.sshHost ?? '');
  late final _port =
      TextEditingController(text: (widget.node.sshPort ?? 22).toString());
  late final _user =
      TextEditingController(text: widget.node.sshUser ?? 'root');
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    return Scaffold(
      appBar: GradientAppBar(
        title: n.name,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('SSH 连接信息',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BocchiTheme.ink)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _host,
                    decoration: const InputDecoration(
                      labelText: 'SSH IP（主机）',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口（默认 22）',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _user,
                    decoration: const InputDecoration(
                      labelText: '用户名（默认 root）',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText:
                          'root 密码${n.sshReady ? '（已保存，留空不改）' : ''}',
                      prefixIcon: const Icon(Icons.key),
                    ),
                  ),
                   Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '密码仅在保存时发送到服务器加密存储，本机不保存；留空表示不修改已存密码。',
                      style: TextStyle(
                          fontSize: 12, color: BocchiTheme.inkSoft),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BocchiTheme.pinkDeep,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final d = <String, dynamic>{
        'ssh_host': _host.text.trim(),
        'ssh_port': _port.text.trim(),
        'ssh_user': _user.text.trim(),
      };
      // 密码留空 = 不改，跟网页端一致；只在有输入时才随请求发往服务端
      if (_pass.text.isNotEmpty) {
        d['ssh_password'] = _pass.text;
      }
      await AppState.instance.client.nodeMeta(widget.node.id, d);
      if (mounted) {
        showOk(context, '已保存');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
