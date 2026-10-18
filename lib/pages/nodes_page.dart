import 'dart:async';
import 'package:flutter/material.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'node_detail_page.dart';
import 'node_admin.dart';

class NodesPage extends StatefulWidget {
  const NodesPage({super.key});
  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  List<ProbeNode> _nodes = [];
  bool _loading = true;
  String? _err;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(
        const Duration(seconds: 5), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final nodes = await AppState.instance.client.getNodes();
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _err = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _nodes.where((n) => n.online).length;
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (_, __) => Scaffold(
        appBar: GradientAppBar(
          title:
              '🎸 探针${_nodes.isEmpty ? '' : '  $online/${_nodes.length} 在线'}',
          fontSize: 18,
          actions: [
            IconButton(
              icon: Icon(AppState.instance.hideIp
                  ? Icons.visibility_off
                  : Icons.visibility),
              tooltip: '显示/隐藏 IP',
              onPressed: () =>
                  AppState.instance.toggleHideIp(),
            ),
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetch()),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _err != null && _nodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('加载失败：$_err',
                            style: const TextStyle(
                                color: BocchiTheme.inkSoft)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: () => _fetch(),
                            child: const Text('重试')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetch(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _nodes.length,
                      itemBuilder: (_, i) => _NodeCard(
                          node: _nodes[i],
                          onChanged: () =>
                              _fetch(silent: true)),
                    ),
                  ),
      ),
    );
  }
}

/// 网页版风格节点卡：指标 2 列网格 + 3 个小统计盒
class _NodeCard extends StatelessWidget {
  final ProbeNode node;
  final VoidCallback onChanged;
  const _NodeCard(
      {required this.node, required this.onChanged});

  String _uptime(ProbeNode n) {
    if (n.uptime == null) return n.online ? '在线' : '离线';
    return '在线 ${fmtUptime(n.uptime)}';
  }

  static double _used(double? pct, int total) =>
      pct == null ? 0 : (pct / 100 * total);

  static String _gb(num b) => b <= 0
      ? '--'
      : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}G';

  @override
  Widget build(BuildContext context) {
    final n = node;
    final admin = AppState.instance.client.admin;
    return Opacity(
      opacity: n.online ? 1 : 0.62,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) =>
                    NodeDetailPage(nodeId: n.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OnlineDot(online: n.online),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        n.name.isEmpty ? n.id : n.name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.ink),
                      ),
                    ),
                    _StatusPill(node: n),
                    if (admin)
                      IconButton(
                        icon: const Icon(Icons.more_vert,
                            color: BocchiTheme.inkSoft),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(),
                        onPressed: () => NodeAdmin.sheet(
                            context, n, onChanged),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${n.hostname} · ${AppState.instance.showIp(n.ip)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: BocchiTheme.inkSoft),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: WebMetric(
                            icon: '🖥️',
                            label: 'CPU',
                            pct: n.cpu,
                            value: n.cpu == null
                                ? '--'
                                : '${n.cpu!.toStringAsFixed(1)}%',
                            caption: n.load1 == null
                                ? ''
                                : '负载 ${n.load1!.toStringAsFixed(2)}${n.cpuCores > 0 ? ' / ${n.cpuCores}核' : ''}')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: WebMetric(
                            icon: '🧠',
                            label: '内存',
                            pct: n.mem,
                            value: n.mem == null
                                ? '--'
                                : '${n.mem!.toStringAsFixed(1)}%',
                            caption: n.memTotal > 0
                                ? '${_gb(_used(n.mem, n.memTotal))} / ${_gb(n.memTotal)}'
                                : '')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: WebMetric(
                            icon: '🗄️',
                            label: '硬盘',
                            pct: n.disk,
                            value: n.disk == null
                                ? '--'
                                : '${n.disk!.toStringAsFixed(1)}%',
                            caption: n.diskTotal > 0
                                ? '${_gb(_used(n.disk, n.diskTotal))} / ${_gb(n.diskTotal)}'
                                : '')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: WebMetric(
                            icon: '⚡',
                            label: '流量',
                            pct: n.quotaGb > 0
                                ? n.quotaPct
                                : null,
                            value: n.quotaGb > 0
                                ? '${n.quotaPct.toStringAsFixed(0)}%'
                                : '—',
                            caption: n.quotaGb > 0
                                ? '配额 ${n.quotaGb.toStringAsFixed(0)}G'
                                : '未设配额')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: WebStatBox(
                            line1:
                                '↑${fmtSpeed(n.tx)}\n↓${fmtSpeed(n.rx)}',
                            line2: '实时网速')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: WebStatBox(
                            line1:
                                '↑${n.monthTxGb.toStringAsFixed(1)}G\n↓${n.monthRxGb.toStringAsFixed(1)}G',
                            line2: '本月流量')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: WebStatBox(
                            line1: n.daysLeft != null
                                ? (n.daysLeft! < 0
                                    ? '已过期'
                                    : '剩${n.daysLeft}天')
                                : _uptime(n),
                            line2: '到期 / 运行')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ProbeNode node;
  const _StatusPill({required this.node});
  @override
  Widget build(BuildContext context) {
    final online = node.online;
    String text;
    if (!online) {
      text = '离线';
    } else if (node.uptime != null) {
      text = '在线 ${fmtUptime(node.uptime)}';
    } else {
      text = '在线';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: online
            ? BocchiTheme.pinkLight
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: online
              ? BocchiTheme.pinkDeep
              : Colors.grey.shade600,
        ),
      ),
    );
  }
}
