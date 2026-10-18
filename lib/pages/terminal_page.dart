import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../terminal.dart';
import '../widgets/widgets.dart';


/// 底部第 3 个 Tab：SSH 终端（走服务端内置 Web SSH，需管理员）
class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key});
  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  List<ProbeNode>? _nodes;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _err = null;
    });
    try {
      final nodes = await AppState.instance.client.getNodes();
      if (mounted) setState(() => _nodes = nodes);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: '🎸 终端'),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (_, __) {
          final admin = AppState.instance.client.admin;
          if (!admin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 48, color: BocchiTheme.pink),
                  const SizedBox(height: 12),
                  const Text('终端需要管理员登录',
                      style:
                          TextStyle(color: BocchiTheme.inkSoft)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        AppState.instance.goTab(3),
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
                      style: const TextStyle(
                          color: BocchiTheme.inkSoft)),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _load,
                      child: const Text('重试')),
                ],
              ),
            );
          }
          if (_nodes == null) {
            return const Center(
                child: CircularProgressIndicator(
                    color: BocchiTheme.pinkDeep));
          }
          final nodes = _nodes!
              .where((n) => (n.sshHost ?? '').isNotEmpty)
              .toList();
          if (nodes.isEmpty) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                      child: Text(
                          '没有配置 SSH 的节点\n请先在网页管理页给节点配好 SSH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color:
                                  BocchiTheme.inkSoft))),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(vertical: 8),
              itemCount: nodes.length,
              itemBuilder: (_, i) {
                final n = nodes[i];
                return Card(
                  child: ListTile(
                    leading: OnlineDot(online: n.online),
                    title: Text(n.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${n.sshUser ?? 'root'}@${AppState.instance.showIp(n.sshHost ?? '')}:${n.sshPort ?? 22}',
                        style: const TextStyle(
                            fontFamily: 'monospace')),
                    trailing: const Icon(
                        Icons.chevron_right,
                        color: BocchiTheme.pinkDeep),
                    onTap: () => _openConnect(n),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openConnect(ProbeNode n) {
    final pw = TextEditingController();
    final client = AppState.instance.client;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('连接 ${n.name}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                '${n.sshUser ?? 'root'}@${AppState.instance.showIp(n.sshHost ?? '')}',
                style: const TextStyle(
                    color: BocchiTheme.inkSoft,
                    fontFamily: 'monospace')),
            const SizedBox(height: 12),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'SSH 密码（留空用服务端已存密码）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              onSubmitted: (_) =>
                  _connect(ctx, client, n, pw.text),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  _connect(ctx, client, n, pw.text),
              icon: const Icon(Icons.terminal),
              label: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect(BuildContext ctx, MyProbeClient client,
      ProbeNode n, String pw) async {
    Navigator.of(ctx).pop();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: BocchiTheme.pinkDeep)),
    );
    try {
      final sid = await client.sshConnect(n.id,
          password: pw.isEmpty ? null : pw,
          cols: 100,
          rows: 30);
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop();
      Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => TerminalScreen(
              node: n, sessionId: sid)));
    } catch (e) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop();
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('连接失败：$e')));
    }
  }
}

/// 终端会话页
class TerminalScreen extends StatefulWidget {
  final ProbeNode node;
  final String sessionId;
  const TerminalScreen(
      {super.key, required this.node, required this.sessionId});

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
  }

  void _maybeScroll() {
    if (_atBottom && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll
              .jumpTo(_scroll.position.maxScrollExtent);
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
              const SnackBar(
                  content: Text('SSH 会话已断开')));
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
        _send(
            String.fromCharCode(c - 96) + t.substring(1));
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

  Widget _keyBtn(String label, String seq,
      {bool toggle = false}) {
    final active = toggle && _ctrl;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: active
              ? BocchiTheme.pinkDeep
              : Colors.grey.shade800,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Text(widget.node.name,
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
                  builder: (_, __) =>
                      SingleChildScrollView(
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
                        hintText:
                            _ctrl ? 'Ctrl+?' : '输入命令…',
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
