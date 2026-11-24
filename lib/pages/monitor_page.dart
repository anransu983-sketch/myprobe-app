// 持续监测子页（PickMyVPS 式）：目标集 TCP / ICMP、实时 / 24h / 7d /
// 30d、地区选择器、三网 Avg / Jitter / Loss / Last、延迟分布。
// 数据诚实边界（2026-11-24 核代码）：统计表取拨测任务近 22 次采样
// （Avg=均值、Jitter=标准差、Loss=最新丢包、Last=最新延迟），协议
// 以任务实际 type 为准（现任务表是 TCP，不写死）；折线图是服务端
// netq 序列（agent 每 5 分钟 ICMP ping 全国 DNS，非分省，范围可切
// 1h/24h/7d/30d）；延迟分布需要 7 天分省历史，服务端拨测历史只保
// 留近 22 次，暂无数据，不编。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:myprobe_app/models.dart';
import 'package:myprobe_app/probe_stats.dart';
import 'package:myprobe_app/state.dart';
import 'package:myprobe_app/theme.dart';
import 'package:myprobe_app/tq_snapshot.dart';
import 'package:myprobe_app/widgets/node_card.dart';
import 'package:myprobe_app/widgets/region_picker.dart';
import 'package:myprobe_app/widgets/widgets.dart';

class MonitorBody extends StatefulWidget {
  final ProbeNode node;
  const MonitorBody({super.key, required this.node});
  @override
  State<MonitorBody> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorBody> {
  String _targetSet = 'tcp'; // tcp | icmp（默认 TCP：统计表就是拨测任务数据）
  String _range = '24h'; // realtime | 24h | 7d | 30d
  String _mapCarrier = 'telecom'; // 全国地图切换运营商
  late String _region;
  Map<String, dynamic> _netq = {};
  bool _netqLoading = false;

  Set<String> get _availableRegions =>
      groupProbesByRegion(widget.node.nodeProbes).keys.toSet();

  @override
  void initState() {
    super.initState();
    _region = _availableRegions.contains('广东')
        ? '广东'
        : (_availableRegions.isNotEmpty
            ? _availableRegions.first
            : '广东');
    _fetchNetq();
  }

  String get _netqRange => _range == 'realtime' ? '1h' : _range;

  Future<void> _fetchNetq() async {
    setState(() => _netqLoading = true);
    try {
      final d = await AppState.instance.client
          .getNetq(widget.node.id, range: _netqRange);
      if (mounted) setState(() => _netq = d);
    } catch (_) {
      // 失败留空，图区显示暂无数据
    } finally {
      if (mounted) setState(() => _netqLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text('持续监测',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: BocchiTheme.ink)),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _targetSet,
                onSelected: (v) => setState(() => _targetSet = v),
                itemBuilder: (ctx) => [
                  for (final t in [
                    ('tcp', 'TCP'),
                    ('icmp', 'ICMP'),
                  ])
                    PopupMenuItem<String>(
                      value: t.$1,
                      child: Row(
                        children: [
                          Text(t.$2),
                          const Spacer(),
                          if (_targetSet == t.$1)
                            Icon(Icons.check,
                                size: 18,
                                color: BocchiTheme.pinkDeep),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: BocchiTheme.inkSoft.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_targetSet == 'tcp' ? 'TCP' : 'ICMP',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 范围：实时 / 24h / 7d / 30d（只影响 ICMP 的 netq 图）
          if (_targetSet == 'icmp')
            SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in [
                  ('realtime', '实时'),
                  ('24h', '24h'),
                  ('7d', '7d'),
                  ('30d', '30d'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.$2),
                      selected: _range == r.$1,
                      selectedColor: BocchiTheme.pinkDeep,
                      labelStyle: TextStyle(
                          color: _range == r.$1
                              ? Colors.white
                              : BocchiTheme.ink),
                      onSelected: (_) {
                        if (_range == r.$1) return;
                        setState(() => _range = r.$1);
                        _fetchNetq();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_targetSet == 'tcp') InkWell(
                onTap: () async {
                  final r = await showRegionPicker(context,
                      available: _availableRegions, current: _region);
                  if (r != null) setState(() => _region = r);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color:
                        BocchiTheme.inkSoft.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 2),
                      Text(_region,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              if (_targetSet == 'tcp') const SizedBox(width: 10),
              Text(
                  _targetSet == 'tcp'
                      ? '统计表按此地区拨测任务'
                      : '折线图为全国 DNS 目标（ICMP），不分省',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
            ],
          ),
          const SizedBox(height: 12),
          if (_targetSet == 'tcp') ...[
            _statsCard(),
          ] else ...[
            _chartCard(),
          ],
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('延迟分布',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BocchiTheme.ink)),
                  const SizedBox(height: 4),
                  // v1.17.10：原来这里抄了对方的副标题（「近 7 天 TCP ·
                  // 每列 1 小时 · 每行 1ms」），看着像有热力图，实际是空
                  // ——副标题删掉，只留诚实的空状态。
                  Text(
                    '暂无分布数据 · 需服务端保留 7 天分省拨测历史（画中位/P10/P90 热力图），当前拨测历史只保留近 22 次',
                    style: TextStyle(
                        fontSize: 13, color: BocchiTheme.inkSoft),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _tqTableCard(),
          const SizedBox(height: 12),
          _mapCard(),
        ],
    );
  }

  /// 全国回程（TQ 快照对照）：31 省 × 三网回程标签 + 延迟。
  /// 只对圣何塞节点显示快照；其他节点写 未测。延迟只填快照摘录里
  /// 给出的数，其余为 —；93/93 全部 0% 丢包。
  /// 注意：TQ 与 NQ 均写广东电信 CN2GIA，但 MyProbe 自测 MTR 判回程
  /// 未识别，以 MyProbe 自测为准，TQ/NQ 表只作对照。
  Widget _tqTableCard() {
    final isSj = widget.node.id == tqSnapshotNodeId;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全国回程（TQ 快照对照）',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 4),
            Text(
                isSj
                    ? 'TcpQuality $tqSnapshotTime · 93/93 全部 0% 丢包'
                    : '本节点暂无 TQ 快照',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft)),
            const SizedBox(height: 10),
            if (!isSj)
              Text('未测 · 只有圣何塞节点有 2026-11-24 的 TQ 快照',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft))
            else ...[
              Row(
                children: [
                  const SizedBox(width: 52),
                  for (final c in ['telecom', 'unicom', 'mobile'])
                    Expanded(
                      child: Text(ispNames[c]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.inkSoft)),
                    ),
                ],
              ),
              const Divider(height: 12),
              for (var i = 0; i < tqProvinces.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(tqProvinces[i],
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                    ),
                    for (final c in ['telecom', 'unicom', 'mobile'])
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                                tqReturnLatency[tqProvinces[i]]?[c] ==
                                        null
                                    ? '—'
                                    : '${tqReturnLatency[tqProvinces[i]]![c]!.toStringAsFixed(0)}ms',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: BocchiTheme.ink)),
                            const SizedBox(height: 2),
                            Text(tqReturnLabel(tqProvinces[i], c),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: const Color(0xFF1F9E8E))),
                          ],
                        ),
                      ),
                  ],
                ),
                if (i < tqProvinces.length - 1)
                  Divider(
                      height: 12,
                      color:
                          BocchiTheme.inkSoft.withValues(alpha: 0.1)),
              ],
              const SizedBox(height: 10),
              Text(
                  '教育网回程：广东 CTGGIA 173ms、浙江 144ms、上海 136ms；丢包云南 4%、天津 28%，其余 0%。大包回程 91 项零重传（安徽移动、云南电信各 4%）。UDP 回程 31 省全是电信 CN2GIA / 联通 CN2GIA / 移动 CMIN2，只有标签无延迟。',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
              const SizedBox(height: 6),
              Text(
                  '对照口径：TQ 写广东电信 CN2GIA，但 MyProbe 自测 MTR 判回程未识别（跳点是 Zayo 中转 64.125.*，59.43/163 前缀全程不出现）——详情页回程 pill 以 MyProbe 自测为准。',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
              const SizedBox(height: 6),
              Text(
                  'NodeQuality TCP 大包延迟（$nqSnapshotTime）：$nqTcpLargeNote',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  /// 全国地图（TQ 快照对照）：按区域分块的 31 省回程 tile 图。
  /// 不是地理形状地图，是按华北/东北/华东/华中/华南/西南/西北分组
  /// 的方块图；格内数字是该运营商回程延迟（快照未给的写 —），格内
  /// 小字是回程标签。只用 tq_snapshot.dart 里的数据，不编数。
  /// 只对圣何塞节点显示快照；其他节点写 未测。
  Widget _mapCard() {
    final isSj = widget.node.id == tqSnapshotNodeId;
    const carriers = ['telecom', 'unicom', 'mobile'];
    const groups = [
      '华北',
      '东北',
      '华东',
      '华中',
      '华南',
      '西南',
      '西北',
    ];
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全国地图（TQ 快照对照）',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 4),
            Text(
                isSj
                    ? 'TcpQuality $tqSnapshotTime · 31 省回程 · 按区域分块'
                    : '本节点暂无 TQ 快照',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft)),
            const SizedBox(height: 10),
            if (!isSj)
              Text('未测 · 只有圣何塞节点有 2026-11-24 的 TQ 快照',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft))
            else ...[
              Row(
                children: [
                  for (final c in carriers)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(ispNames[c]!,
                            style: const TextStyle(fontSize: 12)),
                        selected: _mapCarrier == c,
                        selectedColor: BocchiTheme.pinkDeep,
                        labelStyle: TextStyle(
                            color: _mapCarrier == c
                                ? Colors.white
                                : BocchiTheme.ink),
                        onSelected: (_) =>
                            setState(() => _mapCarrier = c),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (final g in groups) ...[
                Text(g,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.inkSoft)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final prov in regionGroups[g]!)
                      _mapTile(prov, _mapCarrier),
                  ],
                ),
                if (g != groups.last) const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              Text(
                  '格内数字为回程延迟（ms），— 表示 TQ 摘录未给该省延迟；格内小字为回程标签（TQ 口径）。对照口径：TQ 写广东电信 CN2GIA，但 MyProbe 自测 MTR 判回程未识别，以 MyProbe 自测为准。',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mapTile(String province, String carrier) {
    final lat = tqReturnLatency[province]?[carrier];
    final label = tqReturnLabel(province, carrier);
    return Container(
      width: 74,
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: BocchiTheme.pinkLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(province,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BocchiTheme.ink)),
          const SizedBox(height: 2),
          Text(lat == null ? '—' : '${lat.toStringAsFixed(0)}ms',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: BocchiTheme.ink)),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: Color(0xFF1F9E8E))),
        ],
      ),
    );
  }

  Widget _chartCard() {
    final colorMap = {
      'telecom': BocchiTheme.pinkDeep,
      'unicom': const Color(0xFF7B61FF),
      'mobile': BocchiTheme.okGreen,
    };
    final spots = <List<FlSpot>>[];
    var hasData = false;
    for (final isp in ispNames.keys) {
      final d = _netq[isp] as Map<String, dynamic>?;
      final lats = ((d?['lat'] as List?) ?? [])
          .map((e) => e == null ? null : (e as num).toDouble())
          .toList();
      final pts = <FlSpot>[];
      for (var i = 0; i < lats.length; i++) {
        if (lats[i] != null) {
          pts.add(FlSpot(i.toDouble(), lats[i]!));
          hasData = true;
        }
      }
      spots.add(pts);
    }
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                    _range == 'realtime'
                        ? '实时（近 1 小时）'
                        : _range == '24h'
                            ? '近 24 小时'
                            : _range == '7d'
                                ? '近 7 天'
                                : '近 30 天',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.ink)),
                const Spacer(),
                for (final isp in ispNames.keys)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Row(
                      children: [
                        Container(
                            width: 12,
                            height: 4,
                            decoration: BoxDecoration(
                                color: colorMap[isp],
                                borderRadius:
                                    BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Text(ispNames[isp]!,
                            style: TextStyle(
                                fontSize: 11,
                                color: BocchiTheme.inkSoft)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: BocchiTheme.pinkLight.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(4, 10, 10, 6),
              child: SizedBox(
                height: 180,
                child: _netqLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !hasData
                        ? Center(
                            child: Text('暂无数据',
                                style: TextStyle(
                                    color: BocchiTheme.inkSoft)))
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              clipData: const FlClipData.all(),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                bottomTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 42,
                                    getTitlesWidget: (v, meta) => Text(
                                      '${v.toStringAsFixed(0)}ms',
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
                                    color: BocchiTheme.inkSoft
                                        .withValues(alpha: 0.28),
                                    strokeWidth: 1),
                                getDrawingVerticalLine: (_) => FlLine(
                                    color: BocchiTheme.inkSoft
                                        .withValues(alpha: 0.16),
                                    strokeWidth: 1),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                    color: BocchiTheme.inkSoft
                                        .withValues(alpha: 0.16),
                                    width: 1),
                              ),
                              lineBarsData: [
                                for (var i = 0;
                                    i < ispNames.length;
                                    i++)
                                  LineChartBarData(
                                    spots: spots[i],
                                    isCurved: false,
                                    dotData: const FlDotData(show: false),
                                    color: colorMap[
                                        ispNames.keys.elementAt(i)],
                                    barWidth: 1.5,
                                  ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 6),
            Text('折线图：服务端 netq 序列（全国 DNS 目标，非分省）',
                style:
                    TextStyle(fontSize: 11.5, color: BocchiTheme.inkSoft)),
          ],
        ),
      ),
    );
  }

  /// 该地区三网拨测任务的实际协议（取任务上报的 type，不写死）：
  /// 全 TCP → 'TCP'，全 ping → 'ICMP'，混合 → '混合'；任一任务
  /// 缺 type（服务端 v6.12 前）或缺探针 → null，不猜。
  String? _protoLabelForRegion() {
    final types = <String>{};
    for (final isp in ispNames.keys) {
      final p = probeForRegionCarrier(
          widget.node.nodeProbes, _region, ispNames[isp]!);
      if (p?.type == null) return null;
      types.add(p!.type!);
    }
    if (types.isEmpty) return null;
    if (types.length == 1) {
      final t = types.single;
      if (t == 'tcp') return 'TCP';
      if (t == 'ping') return 'ICMP';
      return t.toUpperCase();
    }
    return '混合';
  }

  Widget _statsCard() {
    final colorMap = {
      'telecom': BocchiTheme.pinkDeep,
      'unicom': const Color(0xFF7B61FF),
      'mobile': BocchiTheme.okGreen,
    };
    String f(double? v, String unit) =>
        v == null ? '--' : '${v.toStringAsFixed(1)}$unit';
    final proto = _protoLabelForRegion();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('目标',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.inkSoft)),
                const Spacer(),
                for (final h in ['Avg', 'Jitter', 'Loss', 'Last'])
                  SizedBox(
                    width: 62,
                    child: Text(h,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.inkSoft)),
                  ),
              ],
            ),
            const Divider(height: 14),
            for (final isp in ispNames.keys) ...[
              _statRow(isp, colorMap[isp]!, f),
              if (isp != 'mobile') const Divider(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
                'Avg/Jitter 取该地区拨测近 22 次采样；Loss/Last 为最新一次'
                '${proto == null ? '' : '；协议：$proto'}',
                style:
                    TextStyle(fontSize: 11.5, color: BocchiTheme.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
      String isp, Color color, String Function(double?, String) f) {
    final p = probeForRegionCarrier(
        widget.node.nodeProbes, _region, ispNames[isp]!);
    final avg = p == null ? null : meanOf(p.histLat);
    final jit = p == null ? null : stddevOf(p.histLat);
    final loss = p?.lossPct;
    final last = p?.latencyMs;
    final bars = p?.bars ?? const <bool>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bars.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                for (final ok in bars)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.only(right: 1),
                      decoration: BoxDecoration(
                        color: ok
                            ? BocchiTheme.okGreen
                            : const Color(0xFFE5484D),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(ispNames[isp]!,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const Spacer(),
            SizedBox(
                width: 62,
                child: Text(f(avg, 'ms'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13, color: BocchiTheme.ink))),
            SizedBox(
                width: 62,
                child: Text(f(jit, 'ms'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13, color: BocchiTheme.ink))),
            SizedBox(
                width: 62,
                child: Text(f(loss, '%'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13, color: BocchiTheme.ink))),
            SizedBox(
                width: 62,
                child: Text(f(last, 'ms'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13, color: BocchiTheme.ink))),
          ],
        ),
      ],
    );
  }
}
