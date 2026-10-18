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
  HistoryData? _hist;
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
          _webCard(n),
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
    );
  }

  /// 网页版机器卡：名字+图标+余期+💻 / pills / 指标2x2 / 三统计盒
  Widget _webCard(ProbeNode n) {
    String mb(int b) =>
        b <= 0 ? '--' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    String gb(num b) => b <= 0
        ? '--'
        : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}G';
    final cur = n.currency ?? '¥';
    final rv = _remainValue(n);
    final osIcon =
        n.os.toLowerCase().contains('linux') ? '🐧' : '🖥️';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    n.name.isEmpty ? n.id : n.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.ink),
                  ),
                ),
                Text(osIcon,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                const Text('🌐',
                    style: TextStyle(fontSize: 18)),
                if (n.daysLeft != null) ...[
                  const SizedBox(width: 8),
                  PinkPill(
                      text: n.daysLeft! < 0
                          ? '已过期'
                          : '余期${n.daysLeft}天'),
                ],
                if ((n.sshHost ?? '').isNotEmpty)
                  IconButton(
                    icon: const Text('💻',
                        style: TextStyle(fontSize: 20)),
                    tooltip: 'SSH 终端',
                    onPressed: () => AppState.instance
                        .openTerminalFor(n),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PinkPill(
                    text: n.online
                        ? (n.uptime != null
                            ? '在线 ${fmtUptime(n.uptime)}'
                            : '在线')
                        : '离线',
                    dim: true),
                if ((n.price ?? 0) > 0)
                  PinkPill(
                      text:
                          '${n.billCycle == 'yearly' ? '年付' : '月付'} · $cur${n.price!.toStringAsFixed(n.price! % 1 == 0 ? 0 : 2)}',
                      dim: true),
              ],
            ),
            const SizedBox(height: 12),
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
                        caption:
                            '${mb(_usedBytes(n.mem, n.memTotal).toInt())} / ${mb(n.memTotal)}')),
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
                        caption:
                            '${gb(_usedBytes(n.disk, n.diskTotal))} / ${gb(n.diskTotal)}')),
                const SizedBox(width: 12),
                Expanded(
                    child: WebMetric(
                        icon: '⚡',
                        label: '流量',
                        pct: n.quotaGb > 0
                            ? n.quotaPct
                            : null,
                        value: n.quotaGb > 0
                            ? '${n.quotaPct.toStringAsFixed(1)}%'
                            : '—',
                        caption: n.quotaGb > 0
                            ? '${(n.monthRxGb + n.monthTxGb).toStringAsFixed(1)} GB / ${n.quotaGb.toStringAsFixed(0)} GB'
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
                            '↑${n.monthTxGb.toStringAsFixed(1)} GB\n↓${n.monthRxGb.toStringAsFixed(1)} GB',
                        line2: '本月流量')),
                const SizedBox(width: 8),
                Expanded(
                    child: WebStatBox(
                        line1: n.daysLeft != null
                            ? '余期${n.daysLeft}天\n${rv != null ? '余值$cur${rv.toStringAsFixed(2)}' : ''}'
                            : '${n.online ? '在线' : '离线'}\n${AppState.instance.showIp(n.ip)}',
                        line2: n.daysLeft != null
                            ? '余期 / 余值'
                            : '状态 / IP')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _usedBytes(double? pct, int total) =>
      pct == null ? 0 : (pct / 100 * total);

  /// 余值 = 价格 × 剩余天数 / 周期总天数（跟网页端同口径）
  double? _remainValue(ProbeNode n) {
    if ((n.price ?? 0) <= 0 || n.daysLeft == null) return null;
    var total =
        n.billCycle == 'yearly' ? 365 : 30;
    try {
      if ((n.buyDate ?? '').length >= 10 &&
          (n.expireDate ?? '').length >= 10) {
        final buy = DateTime.parse(n.buyDate!.substring(0, 10));
        final exp =
            DateTime.parse(n.expireDate!.substring(0, 10));
        final d = exp.difference(buy).inDays;
        if (d > 0) total = d;
      }
    } catch (_) {}
    return n.price! * (n.daysLeft! < 0 ? 0 : n.daysLeft!) / total;
  }

  /// 探测目标：按地区分组，只看一个地区的三网，可切换地区
  String? _region;

  Map<String, List<NodeProbe>> _groupByRegion(
      List<NodeProbe> ps) {
    final map = <String, List<NodeProbe>>{};
    for (final p in ps) {
      var region = '其他';
      for (final c in ['移动', '电信', '联通']) {
        if (p.name.endsWith(c) && p.name.length > c.length) {
          region =
              p.name.substring(0, p.name.length - c.length);
          break;
        }
      }
      map.putIfAbsent(region, () => []).add(p);
    }
    const order = ['移动', '电信', '联通'];
    for (final list in map.values) {
      list.sort((a, b) {
        var ai = order.indexWhere((c) => a.name.endsWith(c));
        var bi = order.indexWhere((c) => b.name.endsWith(c));
        if (ai < 0) ai = 99;
        if (bi < 0) bi = 99;
        return ai.compareTo(bi);
      });
    }
    return map;
  }

  Widget _rangeCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Text('时间范围',
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

  /// 网页版风格：探测目标表（地区三网 + 粉条，地区可切换）
  Widget _probesCard(ProbeNode n) {
    final groups = _groupByRegion(n.nodeProbes);
    if (groups.isEmpty) return const SizedBox.shrink();
    final regions = groups.keys.toList();
    if (_region == null || !regions.contains(_region)) {
      _region = regions.contains('浙江') ? '浙江' : regions.first;
    }
    final ps = groups[_region] ?? [];
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
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: regions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final r = regions[i];
                  final sel = r == _region;
                  return ChoiceChip(
                    label: Text(r),
                    selected: sel,
                    selectedColor: BocchiTheme.pinkDeep,
                    labelStyle: TextStyle(
                        color: sel
                            ? Colors.white
                            : BocchiTheme.ink,
                        fontSize: 13),
                    onSelected: (_) =>
                        setState(() => _region = r),
                  );
                },
              ),
            ),
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