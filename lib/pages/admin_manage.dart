import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';

/// 设置 → 管理：主题 / 告警规则 / 通知渠道（需管理员）

String _metricLabel(String m) => m == 'cpu'
    ? 'CPU%'
    : m == 'mem'
        ? '内存%'
        : m == 'traffic_day'
            ? '单日流量'
            : m == 'traffic_month'
                ? '月累计流量'
                : '节点离线';

String _ruleCond(Map<String, dynamic> r) {
  final m = '${r['metric']}';
  if (m == 'offline') return '节点离线';
  if (m == 'traffic_day' || m == 'traffic_month') {
    final t = (r['threshold'] as num?) ?? 0;
    final ts = t == t.roundToDouble() ? '${t.toInt()}' : '$t';
    return '${m == 'traffic_day' ? '今日流量' : '本月流量'} ≥ ${ts}GB';
  }
  final t = (r['threshold'] as num?) ?? 0;
  final ts = t == t.roundToDouble() ? '${t.toInt()}' : '$t';
  return '${_metricLabel(m)} ≥ $ts%';
}

String _channelLabel(String t) =>
    t == 'telegram' ? 'Telegram' : t == 'email' ? 'Email' : 'Webhook';

// ---------------- 🎨 主题 ----------------

class ThemesPage extends StatefulWidget {
  const ThemesPage({super.key});
  @override
  State<ThemesPage> createState() => _ThemesPageState();
}

class _ThemesPageState extends State<ThemesPage> {
  List<Map<String, dynamic>>? _themes;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final ts = await AppState.instance.client.themes();
      if (mounted) setState(() => _themes = ts);
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _activate(String tid) async {
    try {
      await AppState.instance.client.themeActivate(tid);
      showOk(context, '已切换主题');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除主题'),
        content: Text('确定删除「${t['name']}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: BocchiTheme.warnRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppState.instance.client.themeDelete('${t['id']}');
      showOk(context, '已删除');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _upload() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = files.isEmpty ? null : files.single.path;
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      await AppState.instance.client.themeUpload(path);
      showOk(context, '主题已上传');
      _fetch();
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🎨 主题',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _themes == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  for (final t in _themes!)
                    GlassCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${t['name']}${(t['version'] ?? '').toString().isEmpty ? '' : '  ${t['version']}'}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                            ),
                            if (t['active'] == true)
                              _badge('使用中', BocchiTheme.pinkDeep),
                            if (t['builtin'] == true)
                              _badge('内建', BocchiTheme.inkSoft),
                          ],
                        ),
                        subtitle: Text(
                            '${t['author'] ?? ''}${(t['description'] ?? '').toString().isEmpty ? '' : ' · ${t['description']}'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (t['active'] != true)
                              TextButton(
                                onPressed: () =>
                                    _activate('${t['id']}'),
                                child: const Text('启用'),
                              ),
                            if (t['builtin'] != true &&
                                t['active'] != true)
                              IconButton(
                                icon: const Icon(
                                    Icons.delete_outline,
                                    color: BocchiTheme.warnRed),
                                onPressed: () => _delete(t),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.upload),
                    label: Text(
                        _uploading ? '上传中…' : '上传主题（zip 包）'),
                    onPressed:
                        _uploading ? null : _upload,
                  ),
                   Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'zip 内须包含 theme.json。内建 default 主题不可删，正在使用的主题请先切换。',
                      style: TextStyle(
                          fontSize: 12,
                          color: BocchiTheme.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _badge(String s, Color c) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(s,
            style: TextStyle(
                fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );
}

// ---------------- 🚨 告警规则 ----------------

class AlertRulesPage extends StatefulWidget {
  const AlertRulesPage({super.key});
  @override
  State<AlertRulesPage> createState() => _AlertRulesPageState();
}

class _AlertRulesPageState extends State<AlertRulesPage> {
  List<Map<String, dynamic>>? _rules;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final rs = await AppState.instance.client.alertRules();
      if (mounted) setState(() => _rules = rs);
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _toggle(Map<String, dynamic> r, bool v) async {
    try {
      await AppState.instance.client.alertRuleSave(
        id: (r['id'] as num).toInt(),
        name: '${r['name']}',
        metric: '${r['metric']}',
        threshold: ((r['threshold'] as num?) ?? 0).toDouble(),
        duration: ((r['duration'] as num?) ?? 0).toInt(),
        enabled: v,
      );
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定删除「${r['name']}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: BocchiTheme.warnRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppState.instance.client
          .alertRuleDelete((r['id'] as num).toInt());
      showOk(context, '已删除');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  void _addSheet() {
    final nameC = TextEditingController();
    final thC = TextEditingController(text: '90');
    final duC = TextEditingController(text: '5');
    String metric = 'cpu';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => GlassSheet(topRadius: 20, child: Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom:
                  MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Text('添加告警规则',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: '规则名称（如 CPU 过高告警）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: metric,
                decoration: const InputDecoration(
                  labelText: '指标',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'cpu', child: Text('CPU%')),
                  DropdownMenuItem(
                      value: 'mem', child: Text('内存%')),
                  DropdownMenuItem(
                      value: 'offline',
                      child: Text('节点离线')),
                  DropdownMenuItem(
                      value: 'traffic_day',
                      child: Text('单日流量')),
                  DropdownMenuItem(
                      value: 'traffic_month',
                      child: Text('月累计流量')),
                ],
                onChanged: (v) =>
                    setS(() => metric = v ?? 'cpu'),
              ),
              if (metric != 'offline') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: thC,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  decoration: InputDecoration(
                    labelText: (metric == 'traffic_day' ||
                            metric == 'traffic_month')
                        ? '阈值 GB'
                        : '阈值 %（1~100）',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: duC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '持续 N 分钟后告警（0=立即）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final name = nameC.text.trim();
                  if (name.isEmpty) {
                    showErr(ctx, '请填写规则名称');
                    return;
                  }
                  try {
                    await AppState.instance.client
                        .alertRuleSave(
                      name: name,
                      metric: metric,
                      threshold: metric == 'offline'
                          ? 0
                          : double.tryParse(
                                  thC.text.trim()) ??
                              0,
                      duration:
                          int.tryParse(duC.text.trim()) ??
                              0,
                      enabled: true,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    showOk(context, '已添加');
                    _fetch();
                  } catch (e) {
                    showErr(ctx, e);
                  }
                },
                child: const Text('添加'),
              ),
            ],
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🚨 告警规则',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addSheet,
          ),
        ],
      ),
      body: _rules == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _rules!.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 80),
                        Center(
                            child: Text('暂无规则，点右上角 ＋ 添加',
                                style: TextStyle(
                                    color: BocchiTheme
                                        .inkSoft))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _rules!.length,
                      itemBuilder: (_, i) {
                        final r = _rules![i];
                        final en = (r['enabled'] as num?) != 0;
                        return GlassCard(
                          child: ListTile(
                            title: Text('${r['name']}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                            subtitle: Text(
                                '${_ruleCond(r)} · 持续 ${r['duration'] ?? 0} 分钟'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: en,
                                  activeColor:
                                      BocchiTheme.pinkDeep,
                                  onChanged: (v) =>
                                      _toggle(r, v),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color:
                                          BocchiTheme.warnRed),
                                  onPressed: () =>
                                      _delete(r),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ---------------- 🔔 通知渠道 ----------------

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});
  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  List<Map<String, dynamic>>? _chs;
  int? _testing;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final cs = await AppState.instance.client.alertChannels();
      if (mounted) setState(() => _chs = cs);
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _toggle(Map<String, dynamic> c, bool v) async {
    try {
      await AppState.instance.client.alertChannelSave(
        id: (c['id'] as num).toInt(),
        type: '${c['type']}',
        name: '${c['name']}',
        config:
            Map<String, dynamic>.from(c['config'] ?? {}),
        enabled: v,
      );
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _test(Map<String, dynamic> c) async {
    final id = (c['id'] as num).toInt();
    setState(() => _testing = id);
    try {
      await AppState.instance.client.alertChannelTest(id);
      showOk(context, '测试通知已发送，请查收');
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _testing = null);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除渠道'),
        content: Text('确定删除「${c['name']}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: BocchiTheme.warnRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppState.instance.client
          .alertChannelDelete((c['id'] as num).toInt());
      showOk(context, '已删除');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  /// 添加 / 编辑渠道
  void _editSheet({Map<String, dynamic>? c}) {
    final isNew = c == null;
    final nameC = TextEditingController(
        text: isNew ? '' : '${c['name']}');
    String type = isNew ? 'webhook' : '${c['type']}';
    final cfg = isNew
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(c['config'] ?? {});
    // 各类型字段控制器
    final f = <String, TextEditingController>{};
    TextEditingController fc(String k, String def) {
      return f.putIfAbsent(
          k, () => TextEditingController(text: def));
    }

    if (type == 'webhook') {
      fc('url', '${cfg['url'] ?? ''}');
    } else if (type == 'telegram') {
      fc('bot_token', '${cfg['bot_token'] ?? ''}');
      fc('chat_id', '${cfg['chat_id'] ?? ''}');
    } else {
      fc('smtp_host', '${cfg['smtp_host'] ?? ''}');
      fc('smtp_port', '${cfg['smtp_port'] ?? '465'}');
      fc('username', '${cfg['username'] ?? ''}');
      fc('password', isNew ? '' : '******');
      fc('from', '${cfg['from'] ?? ''}');
      fc('to', '${cfg['to'] ?? ''}');
    }
    bool useTls = cfg['use_tls'] != false;

    Widget field(String k, String label,
        {bool obscure = false,
        TextInputType? keyboard}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: fc(k, ''),
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // 切换类型时重建字段
          List<Widget> typeFields() {
            if (type == 'webhook') {
              return [field('url', 'Webhook 地址（POST JSON）')];
            } else if (type == 'telegram') {
              return [
                field('bot_token', 'Bot Token', obscure: true),
                field('chat_id', 'Chat ID',
                    keyboard: TextInputType.number),
              ];
            }
            return [
              Row(
                children: [
                  Expanded(
                      child:
                          field('smtp_host', 'SMTP 服务器')),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 90,
                      child: field('smtp_port', '端口',
                          keyboard:
                              TextInputType.number)),
                ],
              ),
              field('username', '用户名'),
              field('password', '密码（不改请留 ******）',
                  obscure: true),
              field('from', '发件人'),
              field('to', '收件人'),
              Row(
                children: [
                  const Text('TLS 加密'),
                  const Spacer(),
                  Switch(
                    value: useTls,
                    activeColor: BocchiTheme.pinkDeep,
                    onChanged: (v) =>
                        setS(() => useTls = v),
                  ),
                ],
              ),
            ];
          }

          return GlassSheet(topRadius: 20, child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx)
                        .viewInsets
                        .bottom +
                    20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(isNew ? '添加通知渠道' : '编辑渠道',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: '名称（如 我的TG）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'webhook',
                          child: Text('Webhook')),
                      DropdownMenuItem(
                          value: 'telegram',
                          child: Text('Telegram')),
                      DropdownMenuItem(
                          value: 'email',
                          child: Text('Email')),
                    ],
                    onChanged: isNew
                        ? (v) {
                            // 新建时切换类型：重建控制器
                            for (final cc
                                in f.values) {
                              cc.dispose();
                            }
                            f.clear();
                            setS(
                                () => type = v ?? 'webhook');
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  ...typeFields(),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: () async {
                      final name = nameC.text.trim();
                      if (name.isEmpty) {
                        showErr(ctx, '请填写名称');
                        return;
                      }
                      final config = <String, dynamic>{};
                      for (final k in f.keys) {
                        config[k] = f[k]!.text.trim();
                      }
                      if (type == 'email') {
                        config['use_tls'] = useTls;
                        if (isNew &&
                            (config['password'] as String)
                                .isEmpty) {
                          showErr(ctx, '请填写邮箱密码');
                          return;
                        }
                      }
                      if (type == 'webhook' &&
                          (config['url'] as String)
                              .isEmpty) {
                        showErr(ctx, '请填写 Webhook 地址');
                        return;
                      }
                      try {
                        await AppState.instance.client
                            .alertChannelSave(
                          id: isNew
                              ? null
                              : (c!['id'] as num)
                                  .toInt(),
                          type: type,
                          name: name,
                          config: config,
                          enabled: isNew
                              ? true
                              : (c!['enabled'] as num?) !=
                                  0,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        showOk(context,
                            isNew ? '已添加' : '已保存');
                        _fetch();
                      } catch (e) {
                        showErr(ctx, e);
                      }
                    },
                    child:
                        Text(isNew ? '添加' : '保存'),
                  ),
                ],
              ),
            ),
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🔔 通知渠道',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _editSheet(),
          ),
        ],
      ),
      body: _chs == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _chs!.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 80),
                        Center(
                            child: Text('暂无渠道，点右上角 ＋ 添加',
                                style: TextStyle(
                                    color: BocchiTheme
                                        .inkSoft))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _chs!.length,
                      itemBuilder: (_, i) {
                        final c = _chs![i];
                        final en =
                            (c['enabled'] as num?) != 0;
                        final id =
                            (c['id'] as num).toInt();
                        return GlassCard(
                          child: ListTile(
                            title: Text('${c['name']}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                            subtitle: Text(
                                _channelLabel(
                                    '${c['type']}')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_testing == id)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2),
                                  )
                                else
                                  TextButton(
                                    onPressed: () =>
                                        _test(c),
                                    child:
                                        const Text('测试'),
                                  ),
                                Switch(
                                  value: en,
                                  activeColor:
                                      BocchiTheme.pinkDeep,
                                  onChanged: (v) =>
                                      _toggle(c, v),
                                ),
                                IconButton(
                                  icon: Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: BocchiTheme
                                          .inkSoft),
                                  onPressed: () =>
                                      _editSheet(c: c),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color:
                                          BocchiTheme.warnRed),
                                  onPressed: () =>
                                      _delete(c),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
