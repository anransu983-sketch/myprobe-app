import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models.dart';
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
                              : (c['id'] as num)
                                  .toInt(),
                          type: type,
                          name: name,
                          config: config,
                          enabled: isNew
                              ? true
                              : (c['enabled'] as num?) !=
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

// ---------------- v6.7 新增管理页 ----------------

String _fmtTs(int? ts) {
  if (ts == null) return '--';
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  String p(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
}

String _fmtDate(int? ts) {
  if (ts == null) return '--';
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  String p(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)}';
}

/// YYYY-MM-DD 距今天数（负=已过期）
int? _daysLeft(String? ymd) {
  if (ymd == null || ymd.isEmpty) return null;
  try {
    final d = DateTime.parse(ymd);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.difference(today).inDays;
  } catch (_) {
    return null;
  }
}

Future<bool> _confirmDelete(
    BuildContext context, String title, String content) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
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
  return ok == true;
}

// ---------------- 💰 账单与续费 ----------------

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});
  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  List<Map<String, dynamic>>? _items;
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final items = await AppState.instance.client.billingList();
      final sum = await AppState.instance.client.billingSummary();
      if (mounted) {
        setState(() {
          _items = items;
          _summary = sum;
        });
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  String _cycleLabel(int? m) {
    if (m == 1) return '月付';
    if (m == 12) return '年付';
    return '每${m ?? 12}月';
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await _confirmDelete(context, '删除账单',
        '确定删除「${b['vendor']} ${b['plan'] ?? ''}」吗？');
    if (!ok) return;
    try {
      await AppState.instance.client
          .billingDelete((b['id'] as num).toInt());
      showOk(context, '已删除');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  void _editSheet({Map<String, dynamic>? b}) {
    final isNew = b == null;
    final vendorC = TextEditingController(
        text: isNew ? '' : '${b['vendor']}');
    final planC =
        TextEditingController(text: isNew ? '' : '${b['plan'] ?? ''}');
    final priceC = TextEditingController(
        text: isNew ? '' : '${b['price'] ?? ''}');
    final currencyC = TextEditingController(
        text: isNew ? '¥' : '${b['currency'] ?? '¥'}');
    final cycleC = TextEditingController(
        text: isNew ? '12' : '${b['cycle_months'] ?? 12}');
    final renewC = TextEditingController(
        text: isNew ? '' : '${b['renew_date']}');
    final quotaC = TextEditingController(
        text: isNew
            ? ''
            : (b['quota_gb'] == null ? '' : '${b['quota_gb']}'));
    final noteC =
        TextEditingController(text: isNew ? '' : '${b['note'] ?? ''}');
    final nodeC = TextEditingController(
        text: isNew ? '' : '${b['node_id'] ?? ''}');

    Widget field(TextEditingController c, String label,
        {TextInputType? keyboard}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
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
      builder: (ctx) => GlassSheet(
          topRadius: 20,
          child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isNew ? '添加账单' : '编辑账单',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  field(vendorC, '商家（如 六六云）*'),
                  field(planC, '套餐名'),
                  Row(
                    children: [
                      Expanded(
                          child: field(priceC, '价格 *',
                              keyboard: const TextInputType
                                  .numberWithOptions(decimal: true))),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 80,
                          child: field(currencyC, '币种')),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 90,
                          child: field(cycleC, '周期（月）',
                              keyboard: TextInputType.number)),
                    ],
                  ),
                  field(renewC, '续费日 YYYY-MM-DD *'),
                  Row(
                    children: [
                      Expanded(
                          child: field(quotaC, '流量配额 GB（可空）',
                              keyboard: const TextInputType
                                  .numberWithOptions(decimal: true))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: field(nodeC, '绑定节点 ID（可空）')),
                    ],
                  ),
                  field(noteC, '备注'),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: () async {
                      final vendor = vendorC.text.trim();
                      final renew = renewC.text.trim();
                      if (vendor.isEmpty || renew.isEmpty) {
                        showErr(ctx, '商家和续费日必填');
                        return;
                      }
                      try {
                        await AppState.instance.client
                            .billingSave(
                          id: isNew
                              ? null
                              : (b['id'] as num).toInt(),
                          d: {
                            'vendor': vendor,
                            'plan': planC.text.trim(),
                            'price': double.tryParse(
                                    priceC.text.trim()) ??
                                0,
                            'currency':
                                currencyC.text.trim().isEmpty
                                    ? '¥'
                                    : currencyC.text.trim(),
                            'cycle_months':
                                int.tryParse(cycleC.text.trim()) ??
                                    12,
                            'renew_date': renew,
                            'quota_gb': quotaC.text.trim().isEmpty
                                ? null
                                : double.tryParse(
                                    quotaC.text.trim()),
                            'note': noteC.text.trim(),
                            'node_id': nodeC.text.trim().isEmpty
                                ? null
                                : nodeC.text.trim(),
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        showOk(context, isNew ? '已添加' : '已保存');
                        _fetch();
                      } catch (e) {
                        showErr(ctx, e);
                      }
                    },
                    child: Text(isNew ? '添加' : '保存'),
                  ),
                ],
              ),
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '💰 账单与续费',
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
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  if (_summary.isNotEmpty)
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('按商家月花费',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: BocchiTheme.ink)),
                            const SizedBox(height: 6),
                            for (final e in _summary.entries)
                              Text(
                                '${e.key}：${((e.value as List?) ?? []).map((v) => '${v['currency'] ?? ''}${v['monthly']}/月').join(' + ')}',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: BocchiTheme.ink),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_items!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                          child: Text('暂无账单，点右上角 ＋ 添加',
                              style: TextStyle(
                                  color: BocchiTheme.inkSoft))),
                    ),
                  for (final b in _items!)
                    GlassCard(
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                        title: Text(
                            '${b['vendor']} ${b['plan'] ?? ''}'.trim(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${b['currency'] ?? '¥'}${b['price']} · ${_cycleLabel((b['cycle_months'] as num?)?.toInt())} · 续费 ${b['renew_date']}${(() {
                            final d = _daysLeft('${b['renew_date']}');
                            if (d == null) return '';
                            return d < 0 ? ' · 已过期 ${-d} 天' : ' · 剩 $d 天';
                          })()}${(b['note'] ?? '').toString().isEmpty ? '' : '\n${b['note']}'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit,
                                  size: 20,
                                  color: BocchiTheme.inkSoft),
                              onPressed: () =>
                                  _editSheet(b: b),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.delete_outline,
                                  color: BocchiTheme.warnRed),
                              onPressed: () => _delete(b),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ---------------- 🌐 域名到期 ----------------

class DomainsPage extends StatefulWidget {
  const DomainsPage({super.key});
  @override
  State<DomainsPage> createState() => _DomainsPageState();
}

class _DomainsPageState extends State<DomainsPage> {
  List<Map<String, dynamic>>? _items;
  int? _syncing;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final items = await AppState.instance.client.domainsList();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await _confirmDelete(
        context, '删除域名', '确定删除「${d['domain']}」吗？');
    if (!ok) return;
    try {
      await AppState.instance.client
          .domainDelete((d['id'] as num).toInt());
      showOk(context, '已删除');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _rdap(Map<String, dynamic> d) async {
    final id = (d['id'] as num).toInt();
    setState(() => _syncing = id);
    try {
      final exp =
          await AppState.instance.client.domainRdap(id);
      showOk(context, '已同步，到期日 $exp');
      _fetch();
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _syncing = null);
    }
  }

  void _editSheet({Map<String, dynamic>? d}) {
    final isNew = d == null;
    final domainC = TextEditingController(
        text: isNew ? '' : '${d['domain']}');
    final regC = TextEditingController(
        text: isNew ? '' : '${d['registrar'] ?? ''}');
    final expC = TextEditingController(
        text: isNew ? '' : '${d['expire_date'] ?? ''}');
    final noteC = TextEditingController(
        text: isNew ? '' : '${d['note'] ?? ''}');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GlassSheet(
          topRadius: 20,
          child: Padding(
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
                Text(isNew ? '添加域名' : '编辑域名',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: domainC,
                  decoration: const InputDecoration(
                    labelText: '域名 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regC,
                  decoration: const InputDecoration(
                    labelText: '注册商',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expC,
                  decoration: const InputDecoration(
                    labelText: '到期日 YYYY-MM-DD（可空，RDAP 可自动拉）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteC,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final domain = domainC.text.trim();
                    if (domain.isEmpty) {
                      showErr(ctx, '请填写域名');
                      return;
                    }
                    try {
                      await AppState.instance.client.domainSave(
                        id: isNew
                            ? null
                            : (d['id'] as num).toInt(),
                        d: {
                          'domain': domain,
                          'registrar': regC.text.trim(),
                          'expire_date': expC.text.trim().isEmpty
                              ? null
                              : expC.text.trim(),
                          'note': noteC.text.trim(),
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      showOk(context, isNew ? '已添加' : '已保存');
                      _fetch();
                    } catch (e) {
                      showErr(ctx, e);
                    }
                  },
                  child: Text(isNew ? '添加' : '保存'),
                ),
              ],
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🌐 域名到期',
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
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _items!.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                            child: Text('暂无域名，点右上角 ＋ 添加',
                                style: TextStyle(
                                    color: BocchiTheme
                                        .inkSoft))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _items!.length,
                      itemBuilder: (_, i) {
                        final d = _items![i];
                        final days =
                            _daysLeft('${d['expire_date'] ?? ''}');
                        final id = (d['id'] as num).toInt();
                        return GlassCard(
                          child: ListTile(
                            title: Text('${d['domain']}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                            subtitle: Text(
                              '${d['registrar'] ?? ''}${(d['registrar'] ?? '').toString().isEmpty ? '' : ' · '}${d['expire_date'] ?? '到期日未填'}${days == null ? '' : (days < 0 ? ' · 已过期 ${-days} 天' : ' · 剩 $days 天')}${(d['note'] ?? '').toString().isEmpty ? '' : '\n${d['note']}'}',
                              style: TextStyle(
                                  color: days != null && days <= 7
                                      ? BocchiTheme.warnRed
                                      : BocchiTheme.inkSoft),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_syncing == id)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => _rdap(d),
                                    child: const Text('同步'),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      size: 20,
                                      color: BocchiTheme.inkSoft),
                                  onPressed: () =>
                                      _editSheet(d: d),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color:
                                          BocchiTheme.warnRed),
                                  onPressed: () => _delete(d),
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

// ---------------- 📊 运行周报 ----------------

class WeeklyPage extends StatefulWidget {
  const WeeklyPage({super.key});
  @override
  State<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends State<WeeklyPage> {
  bool _enabled = false;
  String _channel = '';
  String _lastSent = '';
  List<Map<String, dynamic>> _channels = [];
  bool _loaded = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final w = await AppState.instance.client.weeklyGet();
      final chs = await AppState.instance.client.alertChannels();
      if (mounted) {
        setState(() {
          _enabled = w['enabled'] == true;
          _channel = '${w['channel'] ?? ''}';
          _lastSent = '${w['last_sent'] ?? ''}';
          _channels = chs;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _save() async {
    try {
      await AppState.instance.client
          .weeklySave(enabled: _enabled, channel: _channel);
      showOk(context, '已保存');
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await AppState.instance.client.weeklyTest();
      showOk(context, '测试周报已发送，请查收');
    } catch (e) {
      showErr(context, e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '📊 运行周报',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                  child: Text('每周一 08:00 发送',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                              Switch(
                                value: _enabled,
                                activeThumbColor:
                                    BocchiTheme.pinkDeep,
                                onChanged: (v) =>
                                    setState(() => _enabled = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _channel,
                            decoration: const InputDecoration(
                              labelText: '发送渠道',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: '',
                                  child: Text('全部启用渠道')),
                              for (final c in _channels)
                                DropdownMenuItem(
                                  value: '${c['id']}',
                                  child: Text('${c['name']}'),
                                ),
                            ],
                            onChanged: (v) => setState(
                                () => _channel = v ?? ''),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _lastSent.isEmpty
                                ? '尚未发送过周报'
                                : '上次发送：$_lastSent（自然周）',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: BocchiTheme.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _save,
                            child: const Text('保存设置'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2))
                                : const Icon(Icons.send),
                            label: Text(
                                _testing ? '发送中…' : '立即测试发送'),
                            onPressed: _testing ? null : _test,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------- 🤖 AI 分析 ----------------

class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _epC = TextEditingController();
  final _modelC = TextEditingController();
  final _keyC = TextEditingController();
  bool _configured = false;
  bool _loaded = false;
  List<ProbeNode> _nodes = [];
  String? _selNode;
  String? _analysis;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _epC.dispose();
    _modelC.dispose();
    _keyC.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final cfg = await AppState.instance.client.aiGet();
      final nodes = await AppState.instance.client.getNodes();
      if (mounted) {
        setState(() {
          _epC.text = '${cfg['endpoint'] ?? ''}';
          _modelC.text = '${cfg['model'] ?? ''}';
          _configured = cfg['configured'] == true;
          _nodes = nodes;
          _selNode ??= nodes.isEmpty ? null : nodes.first.id;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _save() async {
    try {
      await AppState.instance.client.aiSave(
        endpoint: _epC.text.trim(),
        model: _modelC.text.trim(),
        key: _keyC.text.trim(),
      );
      _keyC.clear();
      showOk(context, '已保存');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  Future<void> _analyze() async {
    if (_selNode == null) {
      showErr(context, '暂无节点');
      return;
    }
    setState(() {
      _analyzing = true;
      _analysis = null;
    });
    try {
      final r =
          await AppState.instance.client.aiAnalyze(_selNode!);
      if (mounted) setState(() => _analysis = r);
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🤖 AI 分析',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text('模型设置',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold)),
                              const Spacer(),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_configured
                                          ? BocchiTheme.okGreen
                                          : BocchiTheme.inkSoft)
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                    _configured ? '已配置' : '未配置',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _configured
                                            ? BocchiTheme.okGreen
                                            : BocchiTheme.inkSoft,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _epC,
                            decoration: const InputDecoration(
                              labelText: 'Endpoint（OpenAI 兼容，如 https://api.openai.com/v1）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _modelC,
                            decoration: const InputDecoration(
                              labelText: '模型名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _keyC,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '密钥（留空保持不变，服务端永不回显）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _save,
                            child: const Text('保存设置'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text('一键分析',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selNode,
                            decoration: const InputDecoration(
                              labelText: '节点',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final n in _nodes)
                                DropdownMenuItem(
                                  value: n.id,
                                  child: Text(n.name.isEmpty
                                      ? n.id
                                      : n.name),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selNode = v),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: _analyzing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                : const Icon(Icons.auto_awesome),
                            label: Text(
                                _analyzing ? '分析中…' : '分析该节点（近 24h 数据）'),
                            onPressed:
                                _analyzing ? null : _analyze,
                          ),
                          if (_analysis != null) ...[
                            const SizedBox(height: 12),
                            SelectableText(_analysis!,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: BocchiTheme.ink,
                                    height: 1.5)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------- 🔐 两步验证 ----------------

class TotpPage extends StatefulWidget {
  const TotpPage({super.key});
  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  bool _enabled = false;
  bool _configured = false;
  bool _loaded = false;
  String? _secret;
  String? _otpauthUrl;
  final _codeC = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final t = await AppState.instance.client.totpGet();
      if (mounted) {
        setState(() {
          _enabled = t['enabled'] == true;
          _configured = t['configured'] == true;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _setup() async {
    setState(() => _busy = true);
    try {
      final r = await AppState.instance.client.totpSetup();
      if (mounted) {
        setState(() {
          _secret = '${r['secret'] ?? ''}';
          _otpauthUrl = '${r['otpauth_url'] ?? ''}';
        });
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeC.text.trim();
    if (code.isEmpty) {
      showErr(context, '请填写 6 位验证码');
      return;
    }
    setState(() => _busy = true);
    try {
      final codes =
          await AppState.instance.client.totpVerify(code);
      if (!mounted) return;
      setState(() => _busy = false);
      _codeC.clear();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('两步验证已开启'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('备用码（只显示一次，请立即保存）：'),
                const SizedBox(height: 8),
                SelectableText(codes.join('\n'),
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('我已保存'),
            ),
          ],
        ),
      );
      _fetch();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErr(context, e);
      }
    }
  }

  Future<void> _disable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭两步验证'),
        content: const Text('确定关闭两步验证吗？密钥与备用码将一并清除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: BocchiTheme.warnRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppState.instance.client.totpDisable();
      showOk(context, '已关闭两步验证');
      if (mounted) {
        setState(() {
          _secret = null;
          _otpauthUrl = null;
        });
      }
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🔐 两步验证',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                  _enabled
                                      ? '已开启'
                                      : (_configured
                                          ? '已生成密钥，未开启'
                                          : '未配置'),
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold)),
                              const Spacer(),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_enabled
                                          ? BocchiTheme.okGreen
                                          : BocchiTheme.inkSoft)
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                    _enabled ? '保护中' : '未保护',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _enabled
                                            ? BocchiTheme.okGreen
                                            : BocchiTheme.inkSoft,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '开启后，网页端登录除密码外还要 6 位验证码。备用码各只能用一次，请妥善保存。',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: BocchiTheme.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          if (!_enabled) ...[
                            FilledButton(
                              onPressed: _busy ? null : _setup,
                              child: Text(_configured
                                  ? '查看密钥'
                                  : '生成密钥'),
                            ),
                            if (_secret != null &&
                                _secret!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text('密钥（填进验证器 App）：',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                              const SizedBox(height: 4),
                              SelectableText(_secret!,
                                  style: const TextStyle(
                                      fontSize: 15)),
                              const SizedBox(height: 8),
                              const Text('或复制 otpauth 链接导入：',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                              const SizedBox(height: 4),
                              SelectableText(
                                  _otpauthUrl ?? '',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          BocchiTheme.inkSoft)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _codeC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '验证器上的 6 位验证码',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed:
                                    _busy ? null : _verify,
                                child: const Text('验证并开启'),
                              ),
                            ],
                          ] else ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    BocchiTheme.warnRed,
                                side: const BorderSide(
                                    color: BocchiTheme.warnRed),
                              ),
                              onPressed: _disable,
                              child: const Text('关闭两步验证'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------- 📋 操作审计 ----------------

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});
  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final items =
          await AppState.instance.client.auditList(limit: 100);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '📋 操作审计',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _items!.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                            child: Text('暂无审计记录',
                                style: TextStyle(
                                    color: BocchiTheme
                                        .inkSoft))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _items!.length,
                      itemBuilder: (_, i) {
                        final a = _items![i];
                        final detail = '${a['detail'] ?? ''}';
                        return GlassCard(
                          child: ListTile(
                            title: Text('${a['action'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                            subtitle: Text(
                              '${_fmtTs((a['ts'] as num?)?.toInt())} · ${a['user'] ?? ''} · ${a['ip'] ?? ''}${detail.isEmpty ? '' : '\n$detail'}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ---------------- 🔑 公开 API 令牌 ----------------

class ApiTokensPage extends StatefulWidget {
  const ApiTokensPage({super.key});
  @override
  State<ApiTokensPage> createState() => _ApiTokensPageState();
}

class _ApiTokensPageState extends State<ApiTokensPage> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final items =
          await AppState.instance.client.apiTokensList();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await _confirmDelete(
        context, '吊销令牌', '确定吊销「${t['name']}」吗？用它调用的接口将立即失效。');
    if (!ok) return;
    try {
      await AppState.instance.client
          .apiTokenDelete((t['id'] as num).toInt());
      showOk(context, '已吊销');
      _fetch();
    } catch (e) {
      showErr(context, e);
    }
  }

  void _createSheet() {
    final nameC = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GlassSheet(
          topRadius: 20,
          child: Padding(
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
                const Text('创建 API 令牌',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: '名称（如 监控脚本）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final name = nameC.text.trim();
                    if (name.isEmpty) {
                      showErr(ctx, '请填写名称');
                      return;
                    }
                    try {
                      final r = await AppState
                          .instance.client
                          .apiTokenCreate(name);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('令牌已创建'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    '明文只显示这一次，请立即复制保存，关闭后服务端只存哈希、无法再看：'),
                                const SizedBox(height: 8),
                                SelectableText('${r['token'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                          actions: [
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dctx),
                              child: const Text('我已保存'),
                            ),
                          ],
                        ),
                      );
                      _fetch();
                    } catch (e) {
                      showErr(ctx, e);
                    }
                  },
                  child: const Text('创建'),
                ),
              ],
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '🔑 API 令牌',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createSheet,
          ),
        ],
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _items!.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                            child: Text('暂无令牌，点右上角 ＋ 创建',
                                style: TextStyle(
                                    color: BocchiTheme
                                        .inkSoft))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _items!.length,
                      itemBuilder: (_, i) {
                        final t = _items![i];
                        final lastUsed =
                            (t['last_used'] as num?)?.toInt();
                        return GlassCard(
                          child: ListTile(
                            title: Text('${t['name']}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                            subtitle: Text(
                                '创建 ${_fmtDate((t['created'] as num?)?.toInt())} · ${lastUsed == null ? '未使用过' : '上次使用 ${_fmtDate(lastUsed)}'}'),
                            trailing: IconButton(
                              icon: const Icon(
                                  Icons.delete_outline,
                                  color: BocchiTheme.warnRed),
                              onPressed: () => _delete(t),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
