import 'dart:io';
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
  // v6.7：三网 / MTR / 解锁 / 在线时间线 / 硬盘预测
  Map<String, dynamic> _netq = {};
  String _netqRange = '24h'; // v1.17.3：三网图 24h/7d 切换
  Map<String, dynamic> _mtr = {};
  List<Map<String, dynamic>> _unlock = [];
  Map<String, dynamic>? _uptime;
  Map<String, dynamic>? _diskFc;
  // PickMyVPS 式排名行：三网平均在 N 台节点中排第 X（另起请求算，失败不显示）
  String? _rankText;
  // 去程本机直测：手机直连节点 TCP 握手耗时（_probeOutbound）。
  // 服务端测不了去程（拨测全在 VPS 上跑），这行是唯一能拿到去程数的办法。
  double? _outboundMs;
  int? _outboundPort;
  bool _outboundBusy = false;
  bool _outboundFailed = false;
  bool _outboundVpn = false; // 测时发现代理开着：数字不可信，直接明示
  String? _outboundFor; // 已测过哪台节点（进页自动测一次，切节点才重测）

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void refresh() => _fetch();

  /// 只重拉三网数据（切 24h/7d 时不用整页重拉）
  Future<void> _fetchNetq() async {
    try {
      final netq = await AppState.instance.client
          .getNetq(widget.nodeId, range: _netqRange);
      if (!mounted) return;
      setState(() => _netq = netq);
    } catch (_) {}
  }

  /// 三网平均排名（PickMyVPS 式「在 N 台中排第 X」）：各节点 24h
  /// netq 最新延迟取三网均值排个序；拿不到数据的节点不参与排名。
  /// 主内容不受影响，失败就悄悄不显示。
  Future<void> _fetchRank(List<ProbeNode> nodes) async {
    try {
      final avgs = <String, double>{};
      final cur = _avgNetq(_netq);
      if (cur != null) avgs[widget.nodeId] = cur;
      for (final n in nodes) {
        if (n.id == widget.nodeId) continue;
        try {
          final d = await AppState.instance.client
              .getNetq(n.id, range: '24h');
          final a = _avgNetq(d);
          if (a != null) avgs[n.id] = a;
        } catch (_) {}
      }
      if (!mounted ||
          avgs.length < 2 ||
          !avgs.containsKey(widget.nodeId)) {
        return;
      }
      final sorted = avgs.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final rank =
          sorted.indexWhere((e) => e.key == widget.nodeId) + 1;
      setState(() => _rankText =
          '三网平均在 ${avgs.length} 台节点中排第 $rank');
    } catch (_) {}
  }

  /// netq 各运营商最新延迟的均值（无数据返回 null）
  double? _avgNetq(Map<String, dynamic> netq) {
    final vals = <double>[];
    for (final isp in _ispNames.keys) {
      final lt = (netq[isp] as Map<String, dynamic>?)?['latest']
          as Map<String, dynamic>?;
      final lat = lt?['lat'];
      if (lat != null) vals.add((lat as num).toDouble());
    }
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

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
      // v6.7 新数据：各自失败不影响主内容
      Map<String, dynamic> netq = {}, mtr = {};
      List<Map<String, dynamic>> unlock = [];
      Map<String, dynamic>? uptime, diskFc;
      try {
        netq = await c.getNetq(widget.nodeId, range: _netqRange);
      } catch (_) {}
      try {
        mtr = await c.getMtr(widget.nodeId);
      } catch (_) {}
      try {
        unlock = await c.getUnlock(widget.nodeId);
      } catch (_) {}
      try {
        uptime = await c.getUptime(widget.nodeId);
      } catch (_) {}
      try {
        diskFc = await c.getDiskForecast(widget.nodeId);
      } catch (_) {}
      if (!mounted) return;
      final nn = nodes.firstWhere((n) => n.id == widget.nodeId,
          orElse: () => nodes.first);
      setState(() {
        _node = nn;
        _hist = hist;
        _hist24 = hist24;
        _daily = daily;
        _netq = netq;
        _mtr = mtr;
        _unlock = unlock;
        _uptime = uptime;
        _diskFc = diskFc;
        _rankText = null;
        _loading = false;
      });
      widget.onNode?.call(nn);
      _fetchRank(nodes);
      // 进页自动测一次去程（本机直连）；下拉刷新不重测，点行内刷新才重测
      if (_outboundFor != nn.id) {
        _outboundFor = nn.id;
        _probeOutbound(nn);
      }
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
          PhoneNodeCard(
              node: n,
              onChanged: _fetch,
              compact: true,
              probesStyle: ProbesStyle.slim,
              netq: _netq,
              rankText: _rankText),
          // PickMyVPS 式卡片顺序：延迟（顶部节点卡内）→ 线路 → 套餐与规格 →
          // 网络与性能，再往下是图表/流量/概览/三网图/解锁，末尾是自动小结
          _mtrCard(),
          _specCard(n),
          _netPerfCard(n),
          // 图表范围选择器紧贴图表上方（原在页底、流量卡之下，控制关系反了）；
          // 流量卡自带的今日/本周开关在流量卡内，两者作用域从此分开
          _rangeCard(),
          _chartCard('CPU / 内存 (%)', [
            _Series('CPU', _hist?.cpu, BocchiTheme.pinkDeep),
            _Series('内存', _hist?.mem, const Color(0xFF7B61FF)),
          ], (v) => '${v.toStringAsFixed(0)}%',
              forceMinY: 0, forceMaxY: 100, yInterval: 25),
          _chartCard('实时网速', [
            _Series('下行', _hist?.rx.map((e) => e == null ? null : e / 1024).toList(), BocchiTheme.okGreen),
            _Series('上行', _hist?.tx.map((e) => e == null ? null : e / 1024).toList(), BocchiTheme.pinkDeep),
          ], (v) => v >= 1024 ? '${(v / 1024).toStringAsFixed(1)}M' : '${v.toStringAsFixed(0)}K',
              softCap: true),
          if (_daily.isNotEmpty) _trafficCard(),
          // 稀疏信息合一张「状态概览」：IP 质量 / 流量超额预测 / 在线状态 /
          // 硬盘写满预测原来各占一张全宽大卡、每张只有一两行字，留白巨大
          _overviewCard(n),
          _netqCard(),
          _unlockCard(),
          _summaryCard(n),
        ],
      ),
    );
  }

  // 图表范围：只是一行小开关，不配占一张全宽大卡，改成无卡片的细条
  Widget _rangeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
           Text('图表范围',
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
    );
  }

  Widget _chartCard(String title, List<_Series> series,
      String Function(double) fmtY,
      {bool softCap = false,
      String? subtitle,
      Widget? topExtra,
      int? xCount,
      double? forceMinY,
      double? forceMaxY,
      double? yInterval}) {
    final h = _hist;
    final xLen = xCount ?? (h?.ts.length ?? 0);
    // 量程软化（仅网速图 softCap）：单个尖峰会把自动量程顶爆、其余曲线压成
    // 直线。改为：全部数据点的 95 分位 ×1.25 当 maxY，尖峰照真实高度画、
    // 超出部分被图顶截断（clipData）；数据点一个不改，触摸提示仍是真实值。
    // 尖峰不够突出（最大值 ≤ 95 分位 ×2）时不干预，沿用自动量程。
    // 负值下限裁剪：速率异常值会冲到零线以下、线掉出坐标轴，先钳到 0。
    double? softMaxY;
    if (softCap) {
      final all = <double>[];
      for (final s in series) {
        for (final v in s.values ?? const <double?>[]) {
          if (v != null) all.add(v < 0 ? 0 : v);
        }
      }
      if (all.isNotEmpty) {
        all.sort();
        final maxV = all.last;
        final p95 = all[((all.length - 1) * 0.95).floor()];
        if (p95 > 0 && maxV > p95 * 2) softMaxY = p95 * 1.25;
      }
    }
    final spots = <List<FlSpot>>[];
    var hasData = false;
    for (final s in series) {
      final pts = <FlSpot>[];
      final vals = s.values ?? [];
      for (var i = 0; i < vals.length && i < xLen; i++) {
        final v = vals[i];
        if (v != null) {
          pts.add(FlSpot(i.toDouble(), softCap && v < 0 ? 0 : v));
          hasData = true;
        }
      }
      spots.add(pts);
    }
    final gridColor = BocchiTheme.inkSoft.withValues(alpha: 0.28);
    final gridColorFaint = BocchiTheme.inkSoft.withValues(alpha: 0.16);
    return GlassCard(
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
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: BocchiTheme.inkSoft)),
              ),
            if (topExtra != null) ...[
              topExtra,
              const SizedBox(height: 8),
            ],
            // 图区给一层淡淡的底色 + 看得见的网格和左侧 Y 刻度：
            // 原先图区是卡片本色、网格淡到几乎看不见，整张图显得空
            Container(
              decoration: BoxDecoration(
                color: BocchiTheme.pinkLight.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(4, 10, 10, 6),
              child: SizedBox(
                height: 180,
                child: !hasData
                    ?  Center(
                        child: Text('暂无数据',
                            style:
                                TextStyle(color: BocchiTheme.inkSoft)))
                    : LineChart(
                        LineChartData(
                          minY: forceMinY ?? (softCap ? 0 : null),
                          maxY: forceMaxY ?? softMaxY,
                          clipData: const FlClipData.all(),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            bottomTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                interval: yInterval,
                                getTitlesWidget: (v, meta) => Text(
                                  fmtY(v),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: BocchiTheme.inkSoft),
                                ),
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            getDrawingHorizontalLine: (_) => FlLine(
                                color: gridColor, strokeWidth: 1),
                            getDrawingVerticalLine: (_) => FlLine(
                                color: gridColorFaint, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                                color: gridColorFaint, width: 1),
                          ),
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

    return GlassCard(
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
            // 流量单价（v1.17.3）：价格或配额缺失时不显示这一行
            if (_node != null && pricePerTb(_node!) != null) ...[
              const SizedBox(height: 4),
              Text('流量单价 ${pricePerTb(_node!)}',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: BocchiTheme.inkSoft)),
            ],
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: BocchiTheme.pinkLight.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(4, 10, 10, 2),
              child: SizedBox(
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
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                              color: BocchiTheme.inkSoft
                                  .withValues(alpha: 0.28),
                              strokeWidth: 1),
                        ),
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

  // ---------- v6.7 新增卡片 ----------

  static const _ispNames = {
    'telecom': '电信',
    'unicom': '联通',
    'mobile': '移动',
  };

  static const _unlockNames = {
    'netflix': 'Netflix',
    'disney': 'Disney+',
    'youtube_premium': 'YouTube Premium',
    'chatgpt': 'ChatGPT',
    'gemini': 'Gemini',
    'tiktok': 'TikTok',
    'prime_video': 'Prime Video',
    'hbo_max': 'HBO Max',
    'dazn': 'DAZN',
    'steam': 'Steam',
  };

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: BocchiTheme.ink));

  Widget _emptyHint(String s) => Text(s,
      style: TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft));

  /// 状态概览：一张卡里收四行稀疏信息（IP 质量 / 流量超额预测 /
  /// 在线状态 / 硬盘写满预测），原来每样各占一张全宽大卡、每张只有
  /// 一两行字，留白巨大
  Widget _overviewCard(ProbeNode n) {
    final hasIp = n.ipCountry != null || n.ipIsp != null;
    // 流量超额预测文案
    final String fcBody;
    if (n.quotaGb <= 0) {
      fcBody = '未设置流量配额';
    } else if (n.quotaForecastDays == null) {
      fcBody = '按当前日均用量，本月不会超额';
    } else if (n.quotaForecastDays == 0) {
      fcBody = '本月流量已达到配额';
    } else {
      fcBody =
          '按当前日均用量，预计 ${n.quotaForecastDays} 天后超额（${n.quotaForecastDate ?? ''}）';
    }
    // 在线状态 7 天时间条
    final u = _uptime;
    final segs = <({int start, int end, bool online})>[];
    var offCount = 0;
    var offSecs = 0;
    if (u != null) {
      final since = (u['since'] as num?)?.toInt() ?? 0;
      final now = (u['now'] as num?)?.toInt() ?? 0;
      final events =
          ((u['events'] as List?) ?? []).cast<Map<String, dynamic>>();
      var cursor = since;
      var cur = events.isEmpty
          ? (u['online'] == true)
          : (events.first['event'] != 'online');
      for (final e in events) {
        final ts = (e['ts'] as num?)?.toInt() ?? 0;
        if (ts > cursor) {
          segs.add((start: cursor, end: ts, online: cur));
        }
        if (e['event'] == 'offline') offCount++;
        cur = e['event'] == 'online';
        cursor = ts;
      }
      if (now > cursor) {
        segs.add((start: cursor, end: now, online: cur));
      }
      for (final s in segs) {
        if (!s.online) offSecs += s.end - s.start;
      }
    }
    final offH = (offSecs / 3600).toStringAsFixed(1);
    // 硬盘写满预测文案
    final d = _diskFc;
    final String diskBody;
    if (d == null) {
      diskBody = '暂无数据';
    } else if (d['slope_per_day'] == null) {
      final latest = d['latest'];
      diskBody =
          '${d['note'] ?? '数据不足，无法预测'}（当前 ${latest == null ? '--' : '$latest%'}）';
    } else {
      final days = d['days_left'] as num?;
      diskBody = days == null
          ? '当前 ${d['latest']}% · 每天约 +${d['slope_per_day']}% · 暂无写满风险'
          : '当前 ${d['latest']}% · 每天约 +${d['slope_per_day']}% · 预计 $days 天后写满';
    }
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ovRow(
              '🌐 IP 质量',
              hasIp
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment:
                              WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${n.ipCountry ?? ''} ${n.ipIsp ?? ''}'
                                  .trim(),
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: BocchiTheme.ink),
                            ),
                            if (n.ipHosting)
                              _miniBadge('机房', BocchiTheme.warnRed),
                            if (n.ipProxy)
                              _miniBadge('代理', BocchiTheme.warnRed),
                            if (n.ipMobile)
                              _miniBadge('移动', BocchiTheme.okGreen),
                          ],
                        ),
                        if (n.ipAsn != null) ...[
                          const SizedBox(height: 2),
                          Text(n.ipAsn!,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: BocchiTheme.inkSoft)),
                        ],
                      ],
                    )
                  : _emptyHint('暂无数据 · 服务端每小时检测一次'),
            ),
            _ovDivider(),
            _ovRow(
              '💰 流量超额预测',
              Text(
                '已用 ${_fmtGb(n.quotaUsedGb)} / ${_fmtGb(n.quotaGb)} · $fcBody',
                style:
                    TextStyle(fontSize: 13, color: BocchiTheme.ink),
              ),
            ),
            _ovDivider(),
            _ovRow(
              '🟢 在线状态（近7天）',
              u == null || segs.isEmpty
                  ? _emptyHint('暂无数据')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 16,
                            child: Row(
                              children: [
                                for (final s in segs)
                                  Flexible(
                                    flex: (s.end - s.start)
                                        .clamp(1, 1 << 30),
                                    child: Container(
                                      color: s.online
                                          ? BocchiTheme.okGreen
                                          : BocchiTheme.warnRed,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '掉线 $offCount 次 · 离线共 $offH 小时',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: BocchiTheme.inkSoft),
                        ),
                      ],
                    ),
            ),
            _ovDivider(),
            _ovRow(
              '💾 硬盘写满预测',
              Text(diskBody,
                  style:
                      TextStyle(fontSize: 13, color: BocchiTheme.ink)),
            ),
          ],
        ),
      ),
    );
  }

  /// 概览区的一行：小标题 + 内容
  Widget _ovRow(String title, Widget content) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: BocchiTheme.ink)),
          const SizedBox(height: 4),
          content,
        ],
      );

  Widget _ovDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(
            height: 1,
            color: BocchiTheme.inkSoft.withValues(alpha: 0.18)),
      );

  Widget _miniBadge(String s, Color c) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(s,
            style: TextStyle(
                fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );

  /// 三网延迟三线图（GET /api/netq/<nid>?range=24h|7d，v1.17.3 加 7d 档；
  /// 30d 服务端有接口但数据从 v6.7 才开始攒，详情页先不给）
  Widget _netqCard() {
    final series = <_Series>[];
    final lts = <String>[];
    final colorMap = {
      'telecom': BocchiTheme.pinkDeep,
      'unicom': const Color(0xFF7B61FF),
      'mobile': BocchiTheme.okGreen,
    };
    for (final isp in _ispNames.keys) {
      final d = _netq[isp] as Map<String, dynamic>?;
      final lats = ((d?['lat'] as List?) ?? [])
          .map((e) =>
              e == null ? null : (e as num).toDouble())
          .toList();
      series.add(_Series(_ispNames[isp]!, lats, colorMap[isp]!));
      final lt = d?['latest'] as Map<String, dynamic>?;
      if (lt != null && lt['lat'] != null) {
        lts.add(
            '${_ispNames[isp]} ${(lt['lat'] as num).toStringAsFixed(1)}ms');
      }
    }
    var xLen = 0;
    for (final s in series) {
      final l = s.values?.length ?? 0;
      if (l > xLen) xLen = l;
    }
    return _chartCard('📶 三网延迟（${_netqRange == '7d' ? '7天' : '24小时'}）', series,
        (v) => '${v.toStringAsFixed(0)}ms',
        xCount: xLen,
        topExtra: Row(
          children: [
            for (final r in ['24h', '7d'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(r == '24h' ? '24小时' : '7天',
                      style: const TextStyle(fontSize: 12)),
                  selected: _netqRange == r,
                  selectedColor: BocchiTheme.pinkDeep,
                  labelStyle: TextStyle(
                      color: _netqRange == r
                          ? Colors.white
                          : BocchiTheme.ink),
                  onSelected: (_) {
                    if (_netqRange == r) return;
                    setState(() => _netqRange = r);
                    _fetchNetq();
                  },
                ),
              ),
          ],
        ),
        subtitle: lts.isEmpty
            ? '暂无数据 · agent 每 5 分钟采集一次'
            : '最新：${lts.join(' · ')}（晚高峰 20:00–23:00）');
  }

  /// 解锁检测徽章（GET /api/unlock/<nid>，10 项；未返回的算未知）
  Widget _unlockCard() {
    final bySvc = {
      for (final u in _unlock) '${u['service']}': u
    };
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('🔓 解锁检测'),
            const SizedBox(height: 10),
            if (_unlock.isEmpty)
              _emptyHint('暂无数据 · agent 每小时检测一次')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _unlockNames.entries)
                    _unlockChip(e.key, e.value, bySvc[e.key]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _unlockChip(
      String svc, String label, Map<String, dynamic>? u) {
    final bool? ok = u == null ? null : u['ok'] == true;
    final color = ok == null
        ? BocchiTheme.inkSoft
        : ok
            ? BocchiTheme.okGreen
            : BocchiTheme.warnRed;
    final mark = ok == null ? '未知' : (ok ? '✓ 通' : '✗ 拦');
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text('$label $mark',
          style: TextStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  /// 本机是否开了 VPN（TUN）：梦盒/strangers 开着时，所有流量都走代理，
  /// 直连节点的握手会在代理出口落地，测出来的不是真实去程——1.17.6 实测
  /// 4ms 就是这么来的（代理节点本身就是这台英国机，等于本机回环）。
  /// 零依赖做法：扫网卡名，tun*/ppp* 在即为 VPN 在线；扫不到就当没开，
  /// 宁可多测一次也不错杀。
  Future<bool> _vpnActive() async {
    try {
      final ifs = await NetworkInterface.list();
      return ifs.any((i) =>
          i.name.startsWith('tun') || i.name.startsWith('ppp'));
    } catch (_) {
      return false;
    }
  }

  /// 去程本机直测：服务端测不了去程（全部拨测都在 VPS 上跑），改由手机
  /// 直连节点测 TCP 握手耗时——手机在国内，这条就是去程方向。3 次取中位，
  /// 端口先走节点的 SSH 端口（各 VPS 必开），不通再试 443；只建连就关，
  /// 不发任何应用层数据。测的是手机当前网络（流量卡/ WiFi）到节点的延迟，
  /// 不是分运营商的去程线路名（那要 traceroute，手机无 root 做不了）。
  /// 代理开着时不测：数字是假的，直接明示测不准，不拿假数充数。
  Future<double?> _tcpRtt(String ip, int port) async {
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 5));
      sw.stop();
      s.destroy();
      return sw.elapsedMilliseconds.toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<void> _probeOutbound(ProbeNode n) async {
    final ip = n.ip.trim();
    if (ip.isEmpty) {
      if (mounted) setState(() => _outboundFailed = true);
      return;
    }
    // 代理开着时不测：握手在代理出口落地，数字是假的（1.17.6 的 4ms）。
    if (await _vpnActive()) {
      if (mounted) {
        setState(() {
          _outboundBusy = false;
          _outboundVpn = true;
          _outboundMs = null;
          _outboundFailed = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _outboundBusy = true;
        _outboundFailed = false;
        _outboundVpn = false;
        _outboundMs = null;
      });
    }
    final ports = <int>[];
    for (final p in [n.sshPort ?? 22, 443]) {
      if (!ports.contains(p)) ports.add(p);
    }
    double? best;
    int? bestPort;
    for (final port in ports) {
      final samples = <double>[];
      for (var i = 0; i < 3; i++) {
        final r = await _tcpRtt(ip, port);
        if (r != null) samples.add(r);
        if (!mounted) return;
      }
      if (samples.isNotEmpty) {
        samples.sort();
        best = samples[samples.length ~/ 2];
        bestPort = port;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _outboundBusy = false;
      _outboundMs = best;
      _outboundPort = bestPort;
      _outboundFailed = best == null;
    });
  }

  /// 线路（PickMyVPS 式：每运营商一行 跳数·末跳延迟·末跳 host，
  /// 回程线路判定（TcpQuality 同款前缀规则，见 workspace/tq-clean/
  /// runTcpQuality-core.sh 的 route_label_from_ip_trace；无 ASN 数据，
  /// 只看跳点里的公网 IPv4）。
  /// 去程不在 MTR 里：全部拨测都在 VPS 上跑，去程由本机直测（_probeOutbound）。
  /// 电信：只剩 59.43.* 且无 163 跳 = CN2GIA；59.43 与 163 混走 = CN2GT；
  /// 只有 163 跳 = 163。联通：210.14/210.51/210.78/218.105 = 9929，
  /// 否则 219.158 = 4837。移动：223.120/223.119 = CMIN2，否则 221.183/
  /// 111.24/111.13 = CMNET。
  /// 注意：跳点里没有这些前缀就判不出（英国 9929 电信实测：跳点是 Zayo
  /// 中转 64.125.* + 几跳不回包，59.43/163 全程不出现），此时行尾写
  /// “回程未识别”，不瞎猜——中转 IP 不是骨干网，不能拿它当线路名。
  String? _routeLabel(String target, List<Map<String, dynamic>> hops) {
    final ips = <String>[];
    final ipRe = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
    for (final h in hops) {
      final m = ipRe.firstMatch('${h['host'] ?? ''}');
      if (m != null) ips.add(m.group(0)!);
    }
    bool has(List<String> pres) =>
        ips.any((ip) => pres.any((p) => ip.startsWith(p)));
    switch (target) {
      case 'telecom':
        final cn2 = has(['59.43.']);
        final v163 = has([
          '202.97.',
          '202.96.',
          '219.141.',
          '219.142.',
          '106.37.'
        ]);
        if (cn2 && !v163) return 'CN2GIA';
        if (cn2 && v163) return 'CN2GT';
        if (v163) return '163';
        return null;
      case 'unicom':
        if (has(['210.14.', '210.51.', '210.78.', '218.105.'])) {
          return '9929';
        }
        if (has(['219.158.'])) return '4837';
        return null;
      case 'mobile':
        if (has(['223.120.', '223.119.'])) return 'CMIN2';
        if (has(['221.183.', '111.24.', '111.13.'])) return 'CMNET';
        return null;
    }
    return null;
  }

  /// 本页三网回程（运营商名 → 线路名），只有能判定的才进 map
  Map<String, String> _routeLabels() {
    final out = <String, String>{};
    for (final t in _mtr.keys.where((k) => _ispNames.containsKey(k))) {
      final hops = (((_mtr[t] as Map<String, dynamic>?)?['hops'] as List?) ??
              [])
          .cast<Map<String, dynamic>>();
      final label = _routeLabel(t, hops);
      if (label != null) out[_ispNames[t]!] = label;
    }
    return out;
  }

  /// 点开展开逐跳；GET /api/mtr/<nid>，agent 每 30 分钟跑一次）。
  /// 丢包列已删：agent 根本没报逐跳丢包，每行一个「丢包 --」毫无意义
  Widget _mtrCard() {
    final targets = _mtr.keys
        .where((k) => _ispNames.containsKey(k))
        .toList();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('🛣 线路'),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _emptyHint('暂无数据 · agent 每 30 分钟跑一次'),
              )
            else
              for (final t in targets) _mtrGroup(t),
            // 去程（本机直测）：手机直连节点 TCP 握手耗时，进页自动测一次，
            // 点行或点刷新重测；回程行在上面，去程只有这一行（不分运营商）
            const SizedBox(height: 4),
            Divider(
                height: 1,
                color:
                    BocchiTheme.inkSoft.withValues(alpha: 0.12)),
            InkWell(
              onTap: _node == null
                  ? null
                  : () => _probeOutbound(_node!),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text('去程',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.ink)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _outboundBusy
                            ? '本机直测中…'
                            : _outboundVpn
                                ? '代理已开启，去程测不准 · 关代理后点按重测'
                                : _outboundMs != null
                                    ? '约 ${_outboundMs!.toStringAsFixed(0)} ms · 本机直连（TCP，端口 $_outboundPort）'
                                    : _outboundFailed
                                        ? '测不到，点按重试'
                                        : '点按测量',
                        style: TextStyle(
                            fontSize: 12,
                            color: BocchiTheme.inkSoft),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.refresh,
                        size: 16, color: BocchiTheme.inkSoft),
                  ],
                ),
              ),
            ),
            if (targets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('回程由 MTR 跳点判定；去程为本机直连实测',
                    style: TextStyle(
                        fontSize: 11.5, color: BocchiTheme.inkSoft)),
              ),
          ],
        ),
      ),
    );
  }

  /// 套餐与规格（PickMyVPS 式一行规格 + 一行价格/到期/余值）：
  /// 只有已有的数据才拼，没数据的段直接省掉，全空就不画这张卡。
  /// 带宽测速/性能跑分：服务端没数据，不写、不造（国际延迟已挪到网络与性能卡）。
  Widget _specCard(ProbeNode n) {
    final specs = <String>[];
    if (n.cpuCores > 0) specs.add('${n.cpuCores}核');
    if (n.memTotal > 0) {
      specs.add('${PhoneNodeCard.mb(n.memTotal)}内存');
    }
    if (n.diskTotal > 0) {
      specs.add('${PhoneNodeCard.gb(n.diskTotal)}硬盘');
    }
    if (n.quotaGb > 0) {
      specs.add(
          '${n.quotaGb.toStringAsFixed(n.quotaGb % 1 == 0 ? 0 : 1)} GB 流量');
    }
    final prices = <String>[];
    if ((n.price ?? 0) > 0) {
      prices.add(
          '${n.currency ?? '¥'}${n.price!.toStringAsFixed(n.price! % 1 == 0 ? 0 : 2)} / ${n.billCycle == 'yearly' ? '年' : '月'}');
    }
    final perTb = pricePerTb(n);
    if (perTb != null) prices.add('流量单价 $perTb');
    if (n.expireDate != null && n.expireDate!.isNotEmpty) {
      prices.add(
          '到期 ${n.expireDate}${n.daysLeft == null ? '' : '（余 ${n.daysLeft} 天）'}');
    }
    if (n.remainValue != null) {
      prices.add(
          '余值 ${n.currency ?? '¥'}${n.remainValue!.toStringAsFixed(2)}');
    }
    if (specs.isEmpty && prices.isEmpty) {
      return const SizedBox.shrink();
    }
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('📦 套餐与规格'),
            if (specs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(specs.join(' · '),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: BocchiTheme.ink)),
            ],
            if (prices.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(prices.join(' · '),
                  style: TextStyle(
                      fontSize: 12.5, color: BocchiTheme.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  /// 网络与性能（PickMyVPS 式）：国际延迟 / BGP / IP 质量。
  /// 只有已有的数据才画行，全空就不画这张卡。
  /// 带宽测速、性能跑分：agent 没有 speedtest/跑分能力，不写、不造。
  Widget _netPerfCard(ProbeNode n) {
    final rows = <({String title, Widget body})>[];
    // 国际延迟：服务端 v6.9 自种的 AWS东京拨测任务（tcp 443），
    // 结果走节点 probes；服务端没升级、任务没建出来时这行不画
    NodeProbe? intl;
    for (final p in n.nodeProbes) {
      if (p.name == 'AWS东京') {
        intl = p;
        break;
      }
    }
    final ilat = intl?.latencyMs;
    if (ilat != null) {
      rows.add((
        title: '🌍 国际延迟',
        body: Text('AWS 东京 ${ilat.toStringAsFixed(0)} ms',
            style: TextStyle(fontSize: 13, color: BocchiTheme.ink)),
      ));
    }
    // BGP：ip-api 的 as 字段如 "AS48266 Catixs Ltd"，只取 AS 号
    final asn = n.ipAsn == null
        ? null
        : RegExp(r'AS\d+').firstMatch(n.ipAsn!)?.group(0);
    if (asn != null) {
      rows.add((
        title: '📶 BGP',
        body: Text(asn,
            style: TextStyle(fontSize: 13, color: BocchiTheme.ink)),
      ));
    }
    // IP 质量：原生按 ip-api 代理标记判定（非代理即原生）；低风险同口径
    final hasIp =
        n.ipCountry != null || n.ipIsp != null || n.ipAsn != null;
    if (hasIp) {
      rows.add((
        title: '🛡 IP 质量',
        body: Text(n.ipProxy ? '代理 IP · 高风险' : '原生 IP · 低风险',
            style: TextStyle(fontSize: 13, color: BocchiTheme.ink)),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('🌐 网络与性能'),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) _ovDivider(),
              _ovRow(rows[i].title, rows[i].body),
            ],
          ],
        ),
      ),
    );
  }

  /// 小结（PickMyVPS 式自动总结段落）：探测省份视角三网延迟 + 排名 +
  /// 配置价格 + 解锁情况 + 在线/余期；只有已有的数据才写进句子。
  Widget _summaryCard(ProbeNode n) {
    final parts = <String>[];
    // 探测省份视角（与顶部探测目标同口径：存过的省份优先）
    final groups = groupProbesByRegion(n.nodeProbes);
    String? region;
    if (groups.isNotEmpty) {
      final regions = groups.keys.toList();
      final saved = AppState.instance.probeRegion;
      region = (saved != null && regions.contains(saved))
          ? saved
          : regions.contains('浙江')
              ? '浙江'
              : regions.first;
    }
    // 回程线路（MTR 跳点判定）：广东视角回程：电信 CN2GIA、联通 9929、移动 CMIN2
    final routes = _routeLabels();
    if (routes.isNotEmpty && region != null) {
      parts.add(
          '$region视角回程：${routes.entries.map((e) => '${e.key} ${e.value}').join('、')}');
    }
    // 去程（本机直测）：只有测出数才写
    if (_outboundMs != null) {
      parts.add('本机去程约 ${_outboundMs!.toStringAsFixed(0)} ms');
    }
    // 探测省份视角三网延迟
    if (groups.isNotEmpty) {
      final ps = groups[region] ?? [];
      const order = ['电信', '联通', '移动'];
      final lats = <String>[];
      for (final c in order) {
        NodeProbe? p;
        for (final e in ps) {
          if (e.name.endsWith(c)) {
            p = e;
            break;
          }
        }
        final lat = p?.latencyMs;
        if (lat != null) lats.add('$c ${lat.toStringAsFixed(0)}ms');
      }
      if (lats.isNotEmpty) {
        parts.add(
            '$region视角三网延迟：${lats.join('、')}${_rankText == null ? '' : '，$_rankText'}');
      } else if (_rankText != null) {
        parts.add(_rankText!);
      }
    } else if (_rankText != null) {
      parts.add(_rankText!);
    }
    // 配置与价格
    final specs = <String>[];
    if (n.cpuCores > 0) specs.add('${n.cpuCores}核');
    if (n.memTotal > 0) {
      specs.add('${PhoneNodeCard.mb(n.memTotal)}内存');
    }
    if (n.diskTotal > 0) {
      specs.add('${PhoneNodeCard.gb(n.diskTotal)}硬盘');
    }
    if (n.quotaGb > 0) {
      specs.add(
          '每月 ${n.quotaGb.toStringAsFixed(n.quotaGb % 1 == 0 ? 0 : 1)}GB 流量');
    }
    final priceBits = <String>[];
    if ((n.price ?? 0) > 0) {
      priceBits.add(
          '价格 ${n.currency ?? '¥'}${n.price!.toStringAsFixed(n.price! % 1 == 0 ? 0 : 2)}/${n.billCycle == 'yearly' ? '年' : '月'}');
    }
    final perTb = pricePerTb(n);
    if (perTb != null) priceBits.add('流量单价 $perTb');
    final cfgBits = <String>[];
    if (specs.isNotEmpty) cfgBits.add('配置：${specs.join('、')}');
    if (priceBits.isNotEmpty) cfgBits.add(priceBits.join('，'));
    if (cfgBits.isNotEmpty) parts.add(cfgBits.join('；'));
    // 解锁情况
    if (_unlock.isNotEmpty) {
      final okCount = _unlock.where((u) => u['ok'] == true).length;
      final blocked = _unlock
          .where((u) => u['ok'] == false)
          .map((u) =>
              _unlockNames['${u['service']}'] ?? '${u['service']}')
          .toList();
      parts.add(blocked.isEmpty
          ? '解锁 $okCount/${_unlock.length}，全部通过'
          : '解锁 $okCount/${_unlock.length}，仅 ${blocked.join('、')} 拦截');
    }
    // 在线与余期
    final upBits = <String>[];
    if (n.uptime != null) upBits.add('已在线 ${fmtUptime(n.uptime)}');
    if (n.daysLeft != null) {
      upBits.add(n.daysLeft! < 0 ? '已过期' : '余期 ${n.daysLeft} 天');
    }
    if (upBits.isNotEmpty) parts.add(upBits.join('，'));
    if (parts.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('📝 小结'),
            const SizedBox(height: 8),
            Text(parts.map((p) => p.endsWith('。') ? p : '$p。').join(),
                style:
                    TextStyle(fontSize: 13, color: BocchiTheme.ink)),
          ],
        ),
      ),
    );
  }

  Widget _mtrGroup(String t) {
    final hops = (((_mtr[t] as Map<String, dynamic>?)?['hops']
                as List?) ??
            [])
        .cast<Map<String, dynamic>>();
    final last = hops.isEmpty ? null : hops.last['avg'];
    final lastHost =
        hops.isEmpty ? '' : '${hops.last['host'] ?? ''}';
    final route = _routeLabel(t, hops);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        collapsedIconColor: BocchiTheme.inkSoft,
        iconColor: BocchiTheme.inkSoft,
        title: Row(
          children: [
            Text(_ispNames[t]!,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${hops.length} 跳${hops.isEmpty ? '' : (route == null ? ' · 回程未识别' : ' · 回 $route')}${last == null ? '' : ' · 末跳 ${(last as num).toStringAsFixed(1)} ms'}${lastHost.isEmpty ? '' : ' · $lastHost'}',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        children: [
          for (var i = 0; i < hops.length; i++) ...[
            _mtrRow(hops[i]),
            if (i < hops.length - 1)
              Divider(
                  height: 1,
                  color: BocchiTheme.inkSoft
                      .withValues(alpha: 0.12)),
          ],
        ],
      ),
    );
  }

  Widget _mtrRow(Map<String, dynamic> hop) {
    final avg = hop['avg'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${hop['n'] ?? ''}',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft)),
          ),
          Expanded(
            child: Text('${hop['host'] ?? ''}',
                style:
                    TextStyle(fontSize: 12, color: BocchiTheme.ink),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 64,
            child: Text(
              avg == null
                  ? '-- ms'
                  : '${(avg as num).toStringAsFixed(1)} ms',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12, color: BocchiTheme.ink),
            ),
          ),
        ],
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