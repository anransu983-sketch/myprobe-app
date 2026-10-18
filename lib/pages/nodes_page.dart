import 'dart:async';
import 'package:flutter/material.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'node_detail_page.dart';

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
    final online =
        _nodes.where((n) => n.online).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '探针${_nodes.isEmpty ? '' : '  $online/${_nodes.length} 在线'}'),
        actions: [
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _nodes.length,
                    itemBuilder: (_, i) =>
                        _NodeCard(node: _nodes[i]),
                  ),
                ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final ProbeNode node;
  const _NodeCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final n = node;
    return Opacity(
      opacity: n.online ? 1 : 0.62,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => NodeDetailPage(nodeId: n.id)),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.ink),
                      ),
                    ),
                    if (n.daysLeft != null)
                      _ExpireChip(days: n.daysLeft!),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${n.hostname} · ${n.ip}',
                  style: const TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft),
                ),
                const SizedBox(height: 10),
                MetricBar(label: 'CPU', pct: n.cpu,
                    right: n.cpuCores > 0 && n.cpu != null
                        ? '${n.cpu!.toStringAsFixed(1)}% / ${n.cpuCores}核'
                        : null),
                MetricBar(label: '内存', pct: n.mem),
                MetricBar(label: '硬盘', pct: n.disk),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.arrow_downward,
                        size: 14, color: BocchiTheme.okGreen),
                    Text(' ${fmtSpeed(n.rx)}',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    const Icon(Icons.arrow_upward,
                        size: 14, color: BocchiTheme.pinkDeep),
                    Text(' ${fmtSpeed(n.tx)}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(
                      n.uptime != null
                          ? '运行 ${fmtUptime(n.uptime)}'
                          : (n.online ? '在线' : '离线'),
                      style: const TextStyle(
                          fontSize: 12, color: BocchiTheme.inkSoft),
                    ),
                  ],
                ),
                if (n.monthRxGb + n.monthTxGb > 0 ||
                    n.quotaGb > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '本月 ↓${n.monthRxGb.toStringAsFixed(1)}G ↑${n.monthTxGb.toStringAsFixed(1)}G'
                      '${n.quotaGb > 0 ? ' · 配额已用 ${n.quotaPct.toStringAsFixed(0)}%' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: BocchiTheme.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpireChip extends StatelessWidget {
  final int days;
  const _ExpireChip({required this.days});
  @override
  Widget build(BuildContext context) {
    final urgent = days <= 15;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: urgent
            ? BocchiTheme.warnRed.withValues(alpha: 0.12)
            : BocchiTheme.pinkLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        days < 0 ? '已过期' : '剩 $days 天',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: urgent ? BocchiTheme.warnRed : BocchiTheme.pinkDeep,
        ),
      ),
    );
  }
}
