import 'package:flutter/material.dart';
import '../state.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';
import 'node_admin.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _server.text = AppState.instance.client.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (_, __) {
        final c = AppState.instance.client;
        return Scaffold(
          appBar: const GradientAppBar(title: '🎸 设置'),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('探针服务器',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _server,
                        decoration: const InputDecoration(
                          hintText: 'https://probe.suanran9527.com',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BocchiTheme.pinkDeep,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy ? null : _saveServer,
                          child: const Text('保存服务器地址'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('管理员',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: BocchiTheme.ink)),
                          const Spacer(),
                          if (c.admin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: BocchiTheme.okGreen
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                '已登录${c.username != null ? ' · ${c.username}' : ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: BocchiTheme.okGreen,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!c.admin) ...[
                        TextField(
                          controller: _user,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon:
                                Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            prefixIcon:
                                Icon(Icons.lock_outline),
                          ),
                          onSubmitted: (_) => _doLogin(),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  BocchiTheme.pinkDeep,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                _busy ? null : _doLogin,
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                  )
                                : const Text('登录'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '登录后可管理拨测任务与节点（增删改、启停、立即测试、改名、计费信息、排序）。',
                            style: TextStyle(
                                fontSize: 12,
                                color: BocchiTheme.inkSoft),
                          ),
                        ),
                      ] else ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                              Icons.reorder,
                              color: BocchiTheme.pinkDeep),
                          title: const Text('节点卡片排序'),
                          trailing: const Icon(
                              Icons.chevron_right),
                          onTap: () =>
                              Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const NodeOrderPage()),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  BocchiTheme.warnRed,
                              side: const BorderSide(
                                  color:
                                      BocchiTheme.warnRed),
                            ),
                            onPressed: _busy ? null : () async {
                              setState(() => _busy = true);
                              await AppState.instance.logout();
                              if (mounted) {
                                setState(() => _busy = false);
                                showOk(context, '已退出登录');
                              }
                            },
                            child: const Text('退出登录'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('探针 v1.0.0 · 数据来自自建 MyProbe',
                      style: TextStyle(
                          fontSize: 12,
                          color: BocchiTheme.inkSoft)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveServer() async {
    final u = _server.text.trim();
    if (u.isEmpty) return;
    setState(() => _busy = true);
    try {
      await AppState.instance.setServer(u);
      showOk(context, '已保存');
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doLogin() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      showErr(context, ApiError('请输入用户名和密码'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AppState.instance
          .login(_user.text.trim(), _pass.text);
      _pass.clear();
      showOk(context, '登录成功，管理功能已解锁');
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class NodeOrderPage extends StatefulWidget {
  const NodeOrderPage({super.key});
  @override
  State<NodeOrderPage> createState() => _NodeOrderPageState();
}

class _NodeOrderPageState extends State<NodeOrderPage> {
  List<ProbeNode> _nodes = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final nodes = await AppState.instance.client.getNodes();
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErr(context, e);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppState.instance.client
          .nodesOrder(_nodes.map((n) => n.id).toList());
      showOk(context, '排序已保存');
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '节点卡片排序',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('保存',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _nodes.length,
              onReorderItem: (o, n) {
                setState(() {
                  final it = _nodes.removeAt(o);
                  _nodes.insert(n, it);
                });
              },
              itemBuilder: (_, i) {
                final nd = _nodes[i];
                return Card(
                  key: ValueKey(nd.id),
                  child: ListTile(
                    leading: Text('${i + 1}',
                        style: const TextStyle(
                            color: BocchiTheme.inkSoft)),
                    title: Text(
                        nd.name.isEmpty ? nd.id : nd.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 20,
                              color: BocchiTheme.inkSoft),
                          tooltip: '改名',
                          onPressed: () =>
                              NodeAdmin.renameDialog(
                                  context, nd, _fetch),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: BocchiTheme.warnRed),
                          tooltip: '删除',
                          onPressed: () =>
                              NodeAdmin.deleteNode(
                                  context, nd, _fetch),
                        ),
                        const Icon(Icons.drag_handle,
                            color: BocchiTheme.inkSoft),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
