import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../state.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../update.dart';
import '../widgets/widgets.dart';
import 'node_admin.dart';
import 'admin_manage.dart';
import 'ssh_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String _ver = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _ver = p.version);
    });
  }

  /// 界面主题三选一条目（波奇酱 / 夜之城·毛玻璃 / 夜之城·黄昏），放「外观」卡内
  List<Widget> _themeTiles() {
    final cur = AppState.instance.themeId;
    return [
      for (final t in AppThemeDef.all)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: t.wallpaper == null
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(t.wallpaper!,
                      width: 40, height: 40, fit: BoxFit.cover),
                ),
          title: Text(t.name),
          subtitle: Text(t.desc, style: const TextStyle(fontSize: 12)),
          trailing: cur == t.id
              ? Icon(Icons.check_circle, color: BocchiTheme.pinkDeep)
              : Icon(Icons.circle_outlined, color: BocchiTheme.inkSoft),
          onTap: () => AppState.instance.setTheme(t.id),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (_, __) {
        final c = AppState.instance.client;
        final app = AppState.instance;
        return Scaffold(
          appBar: const GradientAppBar(title: '🎸 设置'),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // ── 1. 连接：服务器地址 / SSH 凭据 ──────────────
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('连接',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.link, color: BocchiTheme.pinkDeep),
                        title: const Text('服务器地址'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ServerAddressPage())),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.key, color: BocchiTheme.pinkDeep),
                        title: const Text('SSH 凭据'),
                        subtitle: const Text(
                            '各节点的 SSH 地址与 root 密码（存服务器）',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SshCredsPage())),
                      ),
                    ],
                  ),
                ),
              ),
              // ── 2. 外观：界面主题 / 节点排序 / 遮挡 IP ───────
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('外观',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                      const SizedBox(height: 6),
                      Text('界面主题',
                          style: TextStyle(
                              fontSize: 12, color: BocchiTheme.inkSoft)),
                      ..._themeTiles(),
                      const Divider(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.reorder, color: BocchiTheme.pinkDeep),
                        title: const Text('节点卡片排序'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const NodeOrderPage()),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                            app.hideIp
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: BocchiTheme.pinkDeep),
                        title: const Text('遮挡 IP'),
                        subtitle: const Text(
                            '截图分享时打码节点 IP，与各页顶栏眼睛按钮同步',
                            style: TextStyle(fontSize: 12)),
                        value: app.hideIp,
                        onChanged: (_) => app.toggleHideIp(),
                      ),
                    ],
                  ),
                ),
              ),
              // ── 3. 服务端管理：登录态 + 看板主题/告警/通知 + 退出 ──
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('服务端管理',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: BocchiTheme.ink)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.admin
                                  ? BocchiTheme.okGreen.withValues(alpha: 0.12)
                                  : BocchiTheme.inkSoft
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c.admin
                                  ? '已登录${c.username != null ? ' · ${c.username}' : ''}'
                                  : '未登录',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: c.admin
                                      ? BocchiTheme.okGreen
                                      : BocchiTheme.inkSoft,
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
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          onSubmitted: (_) => _doLogin(),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BocchiTheme.pinkDeep,
                              foregroundColor: BocchiTheme.onAccent,
                            ),
                            onPressed: _busy ? null : _doLogin,
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('登录'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '登录后可管理拨测任务与节点（增删改、启停、立即测试、改名、计费信息、排序）。',
                            style: TextStyle(
                                fontSize: 12, color: BocchiTheme.inkSoft),
                          ),
                        ),
                      ] else ...[
                        _manageTile(
                            context, '🎨', '看板主题', const ThemesPage()),
                        _manageTile(
                            context, '🚨', '告警规则', const AlertRulesPage()),
                        _manageTile(
                            context, '🔔', '通知渠道', const ChannelsPage()),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BocchiTheme.warnRed,
                              side: const BorderSide(
                                  color: BocchiTheme.warnRed),
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
              // ── 4. 应用：检查更新（版本信息在按钮文案与页脚） ──
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('应用',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.system_update_alt),
                          label: Text(_ver.isEmpty
                              ? '检查更新'
                              : '检查更新（当前 v$_ver）'),
                          onPressed: _busy ? null : () => runUpdateCheck(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                      '探针${_ver.isEmpty ? '' : ' v$_ver'} · 数据来自自建 MyProbe',
                      style: TextStyle(
                          fontSize: 12, color: BocchiTheme.inkSoft)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _manageTile(
      BuildContext context, String emoji, String title, Widget page) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => page)),
    );
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

  /// ➕ 添加节点：填 ID+显示名 → 生成 agent 一键安装命令 → 复制去新机器跑
  Future<void> _addNodeDialog(BuildContext context) async {
    final nidC = TextEditingController();
    final nameC = TextEditingController();
    String? token;
    String? tokenErr;
    try {
      token = await AppState.instance.client.agentToken();
    } catch (e) {
      tokenErr = '$e';
    }
    if (!context.mounted) return;
    final base =
        AppState.instance.client.baseUrl.replaceAll(RegExp(r'/+$'), '');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final nid =
              nidC.text.replaceAll(RegExp(r'\s+'), '');
          final nm = nameC.text.trim();
          final cmd = token == null
              ? ''
              : 'curl -fsSL $base/dl/agent-install.sh | bash -s -- $base $token $nid "${nm.isEmpty ? nid : nm}"';
          return AlertDialog(
            title: const Text('➕ 添加节点'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (tokenErr != null)
                    Text('取 Token 失败：$tokenErr',
                        style: const TextStyle(
                            color: BocchiTheme.warnRed)),
                  TextField(
                    controller: nidC,
                    decoration: const InputDecoration(
                        labelText: '节点 ID（英文，如 de-vps）'),
                    onChanged: (_) => setS(() {}),
                  ),
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                        labelText: '显示名（如 德国CF）'),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 12),
                   Text('去新机器上粘贴运行：',
                      style: TextStyle(
                          fontSize: 12,
                          color: BocchiTheme.inkSoft)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BocchiTheme.pinkLight
                          .withValues(alpha: 0.4),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      token == null
                          ? '正在获取 Token…'
                          : nid.isEmpty
                              ? '请先填写节点 ID'
                              : cmd,
                      style:  TextStyle(
                          fontSize: 12,
                          color: BocchiTheme.ink),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx),
                  child: const Text('关闭')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor:
                        BocchiTheme.pinkDeep),
                onPressed: (token == null || nid.isEmpty)
                    ? null
                    : () async {
                        await Clipboard.setData(
                            ClipboardData(text: cmd));
                        if (ctx.mounted) {
                          showOk(ctx, '已复制，去新机器粘贴运行');
                        }
                      },
                child: const Text('复制命令'),
              ),
            ],
          );
        },
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: '添加节点',
            onPressed: () => _addNodeDialog(context),
          ),
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
                return GlassCard(
                  key: ValueKey(nd.id),
                  child: ListTile(
                    leading: Text('${i + 1}',
                        style:  TextStyle(
                            color: BocchiTheme.inkSoft)),
                    title: Text(
                        nd.name.isEmpty ? nd.id : nd.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:  Icon(Icons.edit,
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
                         Icon(Icons.drag_handle,
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

/// 探针服务器地址子页：查看当前地址 / 更换
class ServerAddressPage extends StatefulWidget {
  const ServerAddressPage({super.key});
  @override
  State<ServerAddressPage> createState() =>
      _ServerAddressPageState();
}

class _ServerAddressPageState extends State<ServerAddressPage> {
  final _server = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _server.text = AppState.instance.client.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '探针服务器',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('当前地址',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BocchiTheme.ink)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: BocchiTheme.okGreen
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: BocchiTheme.okGreen
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 18,
                            color: BocchiTheme.okGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppState.instance.client.baseUrl,
                            style: const TextStyle(
                                fontSize: 14,
                                color: BocchiTheme.okGreen,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                   Text('更换地址',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BocchiTheme.ink)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _server,
                    decoration: const InputDecoration(
                      hintText: 'https://probe.example.com',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                   Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '以 https:// 开头，末尾不要带 /。保存后会自动重连并刷新节点数据。',
                      style: TextStyle(
                          fontSize: 12,
                          color: BocchiTheme.inkSoft),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            BocchiTheme.pinkDeep,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _busy ? null : _saveServer,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                            )
                          : const Text('保存服务器地址'),
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

  Future<void> _saveServer() async {
    final u = _server.text.trim();
    if (u.isEmpty) return;
    setState(() => _busy = true);
    try {
      await AppState.instance.setServer(u);
      if (mounted) {
        showOk(context, '已保存');
        setState(() {});
      }
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
