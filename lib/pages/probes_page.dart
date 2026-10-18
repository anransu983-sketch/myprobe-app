import 'package:flutter/material.dart';
import '../state.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../ui.dart';

class ProbesPage extends StatefulWidget {
  const ProbesPage({super.key});
  @override
  State<ProbesPage> createState() => _ProbesPageState();
}

class _ProbesPageState extends State<ProbesPage> {
  List<ProbeTask> _tasks = [];
  bool _loading = true;
  String _q = '';
  final _search = TextEditingController();

  bool get _admin => AppState.instance.client.admin;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final tasks = _admin
          ? await AppState.instance.client.adminProbes()
          : await AppState.instance.client.getProbes();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e is NeedLogin) {
        await AppState.instance.logout();
      } else {
        showErr(context, e);
      }
    }
  }

  List<ProbeTask> get _filtered {
    if (_q.isEmpty) return _tasks;
    return _tasks
        .where((t) =>
            t.name.contains(_q) ||
            t.host.contains(_q) ||
            t.target.contains(_q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: GradientAppBar(
        title: '🎸 拨测${_tasks.isEmpty ? '' : '（${_tasks.length}）'}',
        fontSize: 18,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetch),
        ],
      ),
      floatingActionButton: _admin
          ? FloatingActionButton(
              onPressed: _addDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索名称 / 目标',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _q = '');
                        }),
              ),
              onChanged: (v) =>
                  setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _TaskTile(task: list[i], onChanged: _fetch),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDialog() async {
    final name = TextEditingController();
    final host = TextEditingController();
    final port = TextEditingController(text: '80');
    String type = 'tcp';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('添加拨测任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: '名称，如 浙江移动')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                        value: 'tcp', child: Text('TCP')),
                    DropdownMenuItem(
                        value: 'ping', child: Text('Ping')),
                    DropdownMenuItem(
                        value: 'http', child: Text('HTTP')),
                  ],
                  onChanged: (v) =>
                      setS(() => type = v ?? 'tcp'),
                  decoration:
                      const InputDecoration(labelText: '类型'),
                ),
                TextField(
                    controller: host,
                    decoration: const InputDecoration(
                        labelText: '目标（IP/域名，http 可填完整 URL）')),
                if (type == 'tcp')
                  TextField(
                      controller: port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'TCP 端口')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('添加')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await AppState.instance.client.probeCreate({
          'name': name.text.trim(),
          'type': type,
          'host': host.text.trim(),
          'port': int.tryParse(port.text.trim()) ?? 0,
          'interval': 60,
          'enabled': true,
        });
        showOk(context, '已添加');
        _fetch();
      } catch (e) {
        showErr(context, e);
      }
    }
  }
}

class _TaskTile extends StatelessWidget {
  final ProbeTask task;
  final VoidCallback onChanged;
  const _TaskTile({required this.task, required this.onChanged});

  bool get _admin => AppState.instance.client.admin;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final sub = t.ok == null
        ? t.target
        : t.ok == true
            ? '${t.latency?.toStringAsFixed(1) ?? '--'}ms · 丢包 ${t.loss?.toStringAsFixed(0) ?? '--'}%'
            : '不可达 · ${t.target}';
    return Opacity(
      opacity: t.enabled ? 1 : 0.55,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.ok == null
                          ? Colors.grey
                          : t.ok == true
                              ? BocchiTheme.okGreen
                              : BocchiTheme.warnRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.ink)),
                  ),
                  Text(t.type.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          color: BocchiTheme.inkSoft)),
                  if (_admin)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (v) =>
                          _menu(context, v),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'edit',
                            child: const Text('编辑')),
                        PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                                t.enabled ? '停用' : '启用')),
                        const PopupMenuItem(
                            value: 'test',
                            child: Text('立即测试')),
                        const PopupMenuItem(
                            value: 'del',
                            child: Text('删除',
                                style: TextStyle(
                                    color:
                                        BocchiTheme.warnRed))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 12,
                      color: BocchiTheme.inkSoft)),
              const SizedBox(height: 6),
              PinkBars(
                latencies:
                    t.bars.map((b) => b.latency).toList(),
                oks: t.bars.map((b) => b.ok).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, String v) async {
    final c = AppState.instance.client;
    try {
      if (v == 'edit') {
        await _editDialog(context);
      } else if (v == 'toggle') {
        await c.probeEnable(task.id, !task.enabled);
        showOk(context, task.enabled ? '已停用' : '已启用');
      } else if (v == 'del') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('删除拨测任务'),
            content: Text('确定删除「${task.name}」吗？'),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, true),
                  child: const Text('删除',
                      style: TextStyle(
                          color: BocchiTheme.warnRed))),
            ],
          ),
        );
        if (ok != true) return;
        await c.probeDelete(task.id);
        showOk(context, '已删除');
      } else if (v == 'test') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('测试中…'),
              ],
            ),
          ),
        );
        try {
          final r = await c.probeTest(task.id);
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            final lat = r['latency'], loss = r['loss'];
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('${task.name} 测试结果'),
                content: Text(lat == null
                    ? '不可达（丢包 ${loss ?? 100}%）'
                    : '延迟 ${lat}ms · 丢包 ${loss ?? 0}%'),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      child: const Text('确定')),
                ],
              ),
            );
          }
        } catch (e) {
          if (context.mounted) Navigator.pop(context);
          rethrow;
        }
      }
      onChanged();
    } catch (e) {
      if (context.mounted) showErr(context, e);
    }
  }

  Future<void> _editDialog(BuildContext context) async {
    final name = TextEditingController(text: task.name);
    final host = TextEditingController(text: task.host);
    final port =
        TextEditingController(text: '${task.port}');
    String type = task.type;
    final interval = TextEditingController(
        text: '${task.interval}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('编辑拨测任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: '名称，如 浙江移动')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                        value: 'tcp', child: Text('TCP')),
                    DropdownMenuItem(
                        value: 'ping',
                        child: Text('Ping')),
                    DropdownMenuItem(
                        value: 'http',
                        child: Text('HTTP')),
                  ],
                  onChanged: (v) =>
                      setS(() => type = v ?? 'tcp'),
                  decoration:
                      const InputDecoration(labelText: '类型'),
                ),
                TextField(
                    controller: host,
                    decoration: const InputDecoration(
                        labelText: '目标（IP/域名）')),
                if (type == 'tcp')
                  TextField(
                      controller: port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'TCP 端口')),
                TextField(
                    controller: interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '间隔（秒）')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await AppState.instance.client.probeUpdate(task.id, {
          'name': name.text.trim(),
          'type': type,
          'host': host.text.trim(),
          'port': int.tryParse(port.text.trim()) ?? 0,
          'interval':
              int.tryParse(interval.text.trim()) ?? 60,
        });
        if (context.mounted) showOk(context, '已保存');
        onChanged();
      } catch (e) {
        if (context.mounted) showErr(context, e);
      }
    }
  }
}
