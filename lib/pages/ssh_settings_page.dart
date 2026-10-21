import 'package:flutter/material.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';

/// SSH 凭据（设置 → 探针服务器 → SSH 凭据）：
/// 逐节点维护 SSH 主机/端口/用户名/密码，密码只存服务端
/// （nodes 表 Fernet 加密），App 本地不落存任何密码。
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
    final admin = AppState.instance.client.admin;
    return Scaffold(
      appBar: GradientAppBar(
        title: 'SSH 凭据',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
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
  }

  Widget _row(ProbeNode n) {
    final hasHost = (n.sshHost ?? '').isNotEmpty;
    return ListTile(
      leading: const Icon(Icons.terminal, color: BocchiTheme.pinkDeep),
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
                  const Text('SSH 连接信息',
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
                  const Padding(
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
