import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';
import 'node_admin.dart';

const _ranges = ['1h', '6h', '24h', '7d'];
const _rangeLabels = {'1h': '1小时', '6h': '6小时', '24h': '24小时', '7d': '7天'};

class NodeDetailPage extends StatefulWidget {
  final String nodeId;
  const NodeDetailPage({super.key, required this.nodeId});
  @override
  State<NodeDetailPage> createState() => _NodeDetailPageState();
}

class _NodeDetailPageState extends State<NodeDetailPage> {
  String _range = '1h';
  HistoryData? _hist;
  List<Map<String, dynamic>> _daily = [];
  ProbeNode? _node;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final c = AppState.instance.client;
    try {
      final nodes = await c.getNodes();
      final hist = await c.getHistory(widget.nodeId, _range);
      List<Map<String, dynamic>> daily = [];
      try {
        daily = await c.getTrafficDaily(widget.nodeId, 14);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _node = nodes.firstWhere((n) => n.id == widget.nodeId,
            orElse: () => nodes.first);
        _hist = hist;
        _daily = daily;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _node;
    return Scaffold(
      appBar: GradientAppBar(
        title: n == null
            ? '节点详情'
            : (n.name.isEmpty ? n.id : n.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (AppState.instance.client.admin && n != null)
            IconButton(
              icon: const Icon(
                  Icons.admin_panel_settings_outlined),
              onPressed: () => NodeAdmin.sheet(
                  context, n, _fetch,
                  popAfterDelete: true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : n == null
              ? const Center(child: Text('节点不存在'))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _infoCard(n),
                      _probesCard(n),
                      _chartCard('CPU / 内存 (%)', [
                        _Series('CPU', _hist?.cpu, BocchiTheme.pinkDeep),
                        _Series('内存', _hist?.mem, const Color(0xFF7B61FF)),
                      ], (v) => '${v.toStringAsFixed(0)}%'),
                      _chartCard('实时网速', [
                        _Series('下行', _hist?.rx.map((e) => e == null ? null : e / 1024).toList(), BocchiTheme.okGreen),
                        _Series('上行', _hist?.tx.map((e) => e == null ? null : e / 1024).toList(), BocchiTheme.pinkDeep),
                      ], (v) => v >= 1024 ? '${(v / 1024).toStringAsFixed(1)}M' : '${v.toStringAsFixed(0)}K'),
                      if (_daily.isNotEmpty) _dailyCard(),
                      _rangeCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard(ProbeNode n) {
    String gb(int b) => b <= 0 ? '--' : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}G';
    final rows = [
      ['状态', n.online ? '在线' : '离线'],
      ['系统', n.os.isEmpty ? '--' : n.os],
      ['IP', AppState.instance.showIp(n.ip)],
      ['负载', n.load1?.toStringAsFixed(2) ?? '--'],
      ['运行', fmtUptime(n.uptime)],
      ['内存', '${gb(n.memTotal)}'],
      ['硬盘', '${gb(n.diskTotal)}'],
      ['到期', n.expireDate ?? '--${n.daysLeft != null ? '（剩${n.daysLeft}天）' : ''}'],
      if ((n.price ?? 0) > 0)
        ['价格', '${n.currency ?? ''}${n.price} / ${n.billCycle == 'yearly' ? '年' : '月'}'],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 64,
                        child: Text(r[0],
                            style: const TextStyle(
                                color: BocchiTheme.inkSoft,
                                fontSize: 13))),
                    Expanded(
                        child: Text(r[1],
                            style: const TextStyle(
                                color: BocchiTheme.ink, fontSize: 13))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Text('时间范围',
                style: TextStyle(color: BocchiTheme.inkSoft, fontSize: 13)),
            const Spacer(),
            SegmentedButton<String>(
              segments: [
                for (final r in _ranges)
                  ButtonSegment(value: r, label: Text(_rangeLabels[r]!)),
              ],
              selected: {_range},
              onSelectionChanged: (s) {
                setState(() => _range = s.first);
                _fetch();
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(String title, List<_Series> series,
      String Function(double) fmtY) {
    final h = _hist;
    final spots = <List<FlSpot>>[];
    var hasData = false;
    for (final s in series) {
      final pts = <FlSpot>[];
      final vals = s.values ?? [];
      for (var i = 0; i < vals.length && i < (h?.ts.length ?? 0); i++) {
        final v = vals[i];
        if (v != null) {
          pts.add(FlSpot(i.toDouble(), v));
          hasData = true;
        }
      }
      spots.add(pts);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.ink)),
                const Spacer(),
                for (final s in series)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Row(
                      children: [
                        Container(
                            width: 12,
                            height: 4,
                            decoration: BoxDecoration(
                                color: s.color,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Text(s.name,
                            style: const TextStyle(
                                fontSize: 11,
                                color: BocchiTheme.inkSoft)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: !hasData
                  ? const Center(
                      child: Text('暂无数据',
                          style:
                              TextStyle(color: BocchiTheme.inkSoft)))
                  : LineChart(
                      LineChartData(
                        titlesData: const FlTitlesData(show: false),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          for (var i = 0; i < series.length; i++)
                            LineChartBarData(
                              spots: spots[i],
                              isCurved: true,
                              color: series[i].color,
                              barWidth: 2,
                              dotData:
                                  const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: series[i]
                                    .color
                                    .withValues(alpha: 0.15),
                              ),
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

  Widget _dailyCard() {
    final maxV = _daily.fold<double>(
        1, (m, e) => (e['total_gb'] as num).toDouble() > m ? (e['total_gb'] as num).toDouble() : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('每日流量（GB）',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: BocchiTheme.ink)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < _daily.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (_daily[i]['total_gb'] as num).toDouble(),
                            color: BocchiTheme.pink,
                            width: 8,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Text(
                '近14天峰值 ${maxV.toStringAsFixed(1)}G · 最近 ${_daily.last['day']}',
                style: const TextStyle(
                    fontSize: 11, color: BocchiTheme.inkSoft)),
          ],
        ),
      ),
    );
  }

  /// 网页版风格：探测目标表（延迟/丢包 + 粉条）
  Widget _probesCard(ProbeNode n) {
    final ps = n.nodeProbes;
    if (ps.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('探测目标',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 4),
            const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('目标',
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                BocchiTheme.inkSoft))),
                Expanded(
                    flex: 2,
                    child: Text('延迟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                BocchiTheme.inkSoft))),
                Expanded(
                    flex: 2,
                    child: Text('丢包',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                BocchiTheme.inkSoft))),
              ],
            ),
            const Divider(height: 12),
            ...ps.map((p) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(p.name,
                                style: const TextStyle(
                                    fontSize: 13)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              p.latencyMs == null
                                  ? '--'
                                  : '${p.latencyMs!.toStringAsFixed(0)} ms',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              p.lossPct == null
                                  ? '--'
                                  : '${p.lossPct!.toStringAsFixed(1)}%',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      PinkBars(
                          latencies: p.histLat,
                          oks: p.bars,
                          height: 26),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ---------- 管理员操作（见 node_admin.dart） ----------
}

class _Series {
  final String name;
  final List<double?>? values;
  final Color color;
  _Series(this.name, this.values, this.color);
}