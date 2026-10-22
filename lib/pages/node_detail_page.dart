import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';
import '../widgets/node_card.dart';
import 'node_admin.dart';

const _ranges = ['1h', '6h', '24h', '7d'];
const _rangeLabels = {'1h': '1小时', '6h': '6小时', '24h': '24小时', '7d': '7天'};

/// 节点详情页（独立页面：AppBar + 内容）
class NodeDetailPage extends StatefulWidget {
  final String nodeId;
  const NodeDetailPage({super.key, required this.nodeId});
  @override
  State<NodeDetailPage> createState() =>
      _NodeDetailPageState();
}

class _NodeDetailPageState extends State<NodeDetailPage> {
  ProbeNode? _node;
  final _bodyKey = GlobalKey<NodeDetailBodyState>();

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
                  context,
                  n,
                  () =>
                      _bodyKey.currentState?.refresh(),
                  popAfterDelete: true),
            ),
        ],
      ),
      body: NodeDetailBody(
        key: _bodyKey,
        nodeId: widget.nodeId,
        onNode: (nn) => setState(() => _node = nn),
      ),
    );
  }
}

/// 节点详情内容（可复用：独立页 / 节点 Tab 的单机分页）
class NodeDetailBody extends StatefulWidget {
  final String nodeId;
  final ValueChanged<ProbeNode?>? onNode;
  const NodeDetailBody(
      {super.key, required this.nodeId, this.onNode});
  @override
  State<NodeDetailBody> createState() =>
      NodeDetailBodyState();
}

class NodeDetailBodyState extends State<NodeDetailBody> {
  String _range = '1h';
  String _trafficTab = 'day'; // day=今日 / week=本周
  HistoryData? _hist;
  HistoryData? _hist24; // 流量统计·今日用（24h 上报历史）
  List<Map<String, dynamic>> _daily = [];
  ProbeNode? _node;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void refresh() => _fetch();

  Future<void> _fetch() async {
    if (mounted) setState(() => _loading = true);
    final c = AppState.instance.client;
    try {
      final nodes = await c.getNodes();
      final hist = await c.getHistory(widget.nodeId, _range);
      final hist24 = await c.getHistory(widget.nodeId, '24h');
      List<Map<String, dynamic>> daily = [];
      try {
        daily = await c.getTrafficDaily(widget.nodeId, 14);
      } catch (_) {}
      if (!mounted) return;
      final nn = nodes.firstWhere((n) => n.id == widget.nodeId,
          orElse: () => nodes.first);
      setState(() {
        _node = nn;
        _hist = hist;
        _hist24 = hist24;
        _daily = daily;
        _loading = false;
      });
      widget.onNode?.call(nn);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _node;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (n == null) {
      return const Center(child: Text('节点不存在'));
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          PhoneNodeCard(node: n, onChanged: _fetch),
          _chartCard('CPU / 内存 (%)', [
            _Series('CPU', _hist?.cpu, BocchiTheme.pinkDeep),
            _Series('内存', _hist?.mem, const Color(0xFF7B61FF)),
          ], (v) => '${v.toStringAsFixed(0)}%'),
          _chartCard('实时网速', [
            _Series('下行', _hist?.rx.map((e) => e == null ? null : e / 1024).toList(), BocchiTheme.okGreen),
            _Series('上行', _hist?.tx.map((e) => e == null ? null : e / 1024).toList(), BocchiTheme.pinkDeep),
          ], (v) => v >= 1024 ? '${(v / 1024).toStringAsFixed(1)}M' : '${v.toStringAsFixed(0)}K'),
          if (_daily.isNotEmpty) _trafficCard(),
          _rangeCard(),
        ],
      ),
    );
  }

  Widget _rangeCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
             Text('时间范围',
                style: TextStyle(
                    color: BocchiTheme.inkSoft,
                    fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in _ranges)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_rangeLabels[r]!,
                              style: const TextStyle(
                                  fontSize: 12)),
                          selected: _range == r,
                          selectedColor:
                              BocchiTheme.pinkDeep,
                          labelStyle: TextStyle(
                              color: _range == r
                                  ? Colors.white
                                  : BocchiTheme.ink),
                          onSelected: (_) {
                            setState(() => _range = r);
                            _fetch();
                          },
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
                    style:  TextStyle(
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
                            style:  TextStyle(
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
                  ?  Center(
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

  /// 流量统计：今日（24h 按小时）/ 本周（按天）切换，大数字 + 上下行 + 柱状图
  Widget _trafficCard() {
    final isDay = _trafficTab == 'day';
    List<double> vals = [];
    List<String> xLabels = [];
    double downGb = 0, upGb = 0;
    String foot = '';
    if (isDay) {
      final h = _hist24;
      if (h != null) {
        final b = _bucket24h(h);
        vals = b.tot.map((e) => e / 1024 / 1024 / 1024).toList();
        downGb = b.down.fold(0.0, (a, e) => a + e) / 1024 / 1024 / 1024;
        upGb = b.up.fold(0.0, (a, e) => a + e) / 1024 / 1024 / 1024;
        xLabels = List.generate(24, (i) => '$i');
      }
      foot = '按小时汇总 · 数据来自探针上报';
    } else {
      final week =
          _daily.length > 7 ? _daily.sublist(_daily.length - 7) : _daily;
      vals = week
          .map((e) => ((e['total_gb'] as num?) ?? 0).toDouble())
          .toList();
      downGb = week.fold(
          0.0, (a, e) => a + (((e['rx_gb'] as num?) ?? 0).toDouble()));
      upGb = week.fold(
          0.0, (a, e) => a + (((e['tx_gb'] as num?) ?? 0).toDouble()));
      xLabels = week
          .map((e) => (e['day'] as String? ?? '').substring(5))
          .toList();
      foot = '按天汇总 · 数据来自探针上报';
    }
    final totalGb = downGb + upGb;
    final maxV =
        vals.fold<double>(0.01, (m, e) => e > m ? e : m);
    final hasData = vals.any((e) => e > 0);

    Widget tab(String key, String label) {
      final sel = _trafficTab == key;
      return GestureDetector(
        onTap: () => setState(() => _trafficTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? BocchiTheme.pinkDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? Colors.white
                      : BocchiTheme.inkSoft)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 Text('⚡ 流量统计',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: BocchiTheme.ink)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: BocchiTheme.pinkLight
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tab('day', '今日'),
                      tab('week', '本周'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_fmtGb(totalGb),
                style:  TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style:  TextStyle(
                    fontSize: 12.5,
                    color: BocchiTheme.inkSoft),
                children: [
                  TextSpan(
                      text: isDay ? '今日流量 · ' : '本周流量 · '),
                  const TextSpan(text: '下行 '),
                  TextSpan(
                      text: _fmtGb(downGb),
                      style:  TextStyle(
                          color: BocchiTheme.pinkDeep,
                          fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' · 上行 '),
                  TextSpan(
                      text: _fmtGb(upGb),
                      style:  TextStyle(
                          color: BocchiTheme.pinkDeep,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: !hasData
                  ?  Center(
                      child: Text('暂无数据',
                          style: TextStyle(
                              color: BocchiTheme.inkSoft)))
                  : BarChart(
                      BarChartData(
                        maxY: maxV * 1.15,
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 ||
                                    i >= xLabels.length) {
                                  return const SizedBox
                                      .shrink();
                                }
                                String? label;
                                if (isDay) {
                                  if (i % 6 == 0) {
                                    label =
                                        '${xLabels[i].padLeft(2, '0')}:00';
                                  }
                                } else {
                                  label = xLabels[i];
                                }
                                if (label == null) {
                                  return const SizedBox
                                      .shrink();
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: BocchiTheme
                                              .inkSoft)),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData:
                            FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0;
                              i < vals.length;
                              i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: vals[i],
                                  color: vals[i] >
                                          maxV * 0.35
                                      ? BocchiTheme.pinkDeep
                                      : BocchiTheme.pink
                                          .withValues(
                                              alpha: 0.55),
                                  width: isDay ? 8 : 22,
                                  borderRadius:
                                      BorderRadius.circular(
                                          3),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(foot,
                  style:  TextStyle(
                      fontSize: 11,
                      color: BocchiTheme.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }

  /// 24h 上报历史按小时桶汇总（本地时区），返回每 GB 小时的 down/up/total（bytes）
  ({List<double> tot, List<double> down, List<double> up}) _bucket24h(
      HistoryData h) {
    final tot = List<double>.filled(24, 0);
    final down = List<double>.filled(24, 0);
    final up = List<double>.filled(24, 0);
    final n = h.ts.length;
    for (var i = 0; i < n; i++) {
      final dt = (i + 1 < n)
          ? (h.ts[i + 1] - h.ts[i]) / 1000.0
          : 5.0;
      if (dt <= 0 || dt > 3600) continue;
      final hr =
          DateTime.fromMillisecondsSinceEpoch(h.ts[i]).hour;
      final r = (i < h.rx.length) ? (h.rx[i] ?? 0) : 0;
      final t = (i < h.tx.length) ? (h.tx[i] ?? 0) : 0;
      down[hr] += r * dt;
      up[hr] += t * dt;
      tot[hr] += (r + t) * dt;
    }
    return (tot: tot, down: down, up: up);
  }

  static String _fmtGb(double gb) => gb >= 1
      ? '${gb.toStringAsFixed(1)} GB'
      : '${(gb * 1024).toStringAsFixed(0)} MB';

  // ---------- 管理员操作（见 node_admin.dart） ----------
}

class _Series {
  final String name;
  final List<double?>? values;
  final Color color;
  _Series(this.name, this.values, this.color);
}