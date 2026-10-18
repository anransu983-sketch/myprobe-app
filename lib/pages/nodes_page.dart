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
    final online =
        _nodes.where((n) => n.online).length;
    return Scaffold(
      appBar: GradientAppBar(
        title:
            '🎸 探针${_nodes.isEmpty ? '' : '  $online/${_nodes.length} 在线'}',
        fontSize: 18,
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _nodes.length,
                    itemBuilder: (_, i) => _NodeCard(
                        node: _nodes[i],
                        onChanged: () =>
                            _fetch(silent: true)),
                  ),
                ),
    );
  }
}

/// 网页版风格节点卡：指标 2 列网格 + 3 个小统计盒
class _NodeCard extends StatelessWidget {
  final ProbeNode node;
  final VoidCallback onChanged;
  const _NodeCard({required this.node, required this.onChanged});

  String _uptime(ProbeNode n) {
    if (n.uptime == null) return n.online ? '在线' : '离线';
    return '在线 ${fmtUptime(n.uptime)}';
  }

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
                  '${n.hostname} · ${n.ip}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: BocchiTheme.inkSoft),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _Metric(
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
                        child: _Metric(
                            icon: '🧠',
                            label: '内存',
                            pct: n.mem,
                            value: n.mem == null
                                ? '--'
                                : '${n.mem!.toStringAsFixed(1)}%',
                            caption: n.memTotal > 0
                                ? '${gbStr(_usedBytes(n.mem, n.memTotal))} / ${gbStr(n.memTotal)}'
                                : '')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _Metric(
                            icon: '🗄️',
                            label: '硬盘',
                            pct: n.disk,
                            value: n.disk == null
                                ? '--'
                                : '${n.disk!.toStringAsFixed(1)}%',
                            caption: n.diskTotal > 0
                                ? '${gbStr(_usedBytes(n.disk, n.diskTotal))} / ${gbStr(n.diskTotal)}'
                                : '')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Metric(
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
                        child: _StatBox(
                            line1:
                                '↑${fmtSpeed(n.tx)}\n↓${fmtSpeed(n.rx)}',
                            line2: '实时网速')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatBox(
                            line1:
                                '↑${n.monthTxGb.toStringAsFixed(1)}G\n↓${n.monthRxGb.toStringAsFixed(1)}G',
                            line2: '本月流量')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatBox(
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

double _usedBytes(double? pct, int total) =>
    pct == null ? 0 : (pct / 100 * total);

String gbStr(num b) =>
    b <= 0 ? '--' : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}G';

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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _Metric extends StatelessWidget {
  final String icon;
  final String label;
  final double? pct;
  final String value;
  final String caption;
  const _Metric(
      {required this.icon,
      required this.label,
      required this.pct,
      required this.value,
      required this.caption});

  @override
  Widget build(BuildContext context) {
    final v = (pct ?? 0).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: BocchiTheme.inkSoft)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: v / 100,
            minHeight: 7,
            backgroundColor: BocchiTheme.pinkLight,
            valueColor: const AlwaysStoppedAnimation(
                BocchiTheme.pinkDeep),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(caption,
                style: const TextStyle(
                    fontSize: 11,
                    color: BocchiTheme.inkSoft)),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String line1;
  final String line2;
  const _StatBox({required this.line1, required this.line2});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: BocchiTheme.pinkLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(line1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BocchiTheme.pinkDeep,
                  height: 1.4)),
          const SizedBox(height: 2),
          Text(line2,
              style: const TextStyle(
                  fontSize: 10,
                  color: BocchiTheme.inkSoft)),
        ],
      ),
    );
  }
}
