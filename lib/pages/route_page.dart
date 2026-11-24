// 回程路由子页（PickMyVPS 式）：模式 TCP / TCP 大包 / ICMP、逐跳 / 按 AS
// 折叠视图、地区选择器、MTR 逐跳表。
// 数据诚实边界：agent 只上报一组 ICMP MTR（mtr 默认协议），无 TCP/
// TCP 大包数据，无 ASN/位置/Wrst，且 MTR 目标是全国 DNS（电信
// 114.114.114.114 / 联通 123.125.81.6 / 移动 211.136.192.6），不分
// 地区——没有的数据一律写 未测/--，不编；地区切换只换下方中位延迟行。
import 'package:flutter/material.dart';
import 'package:myprobe_app/models.dart';
import 'package:myprobe_app/outbound_routes.dart';
import 'package:myprobe_app/probe_stats.dart';
import 'package:myprobe_app/route_history.dart';
import 'package:myprobe_app/route_labels.dart';
import 'package:myprobe_app/theme.dart';
import 'package:myprobe_app/tq_snapshot.dart';
import 'package:myprobe_app/widgets/node_card.dart';
import 'package:myprobe_app/widgets/region_picker.dart';
import 'package:myprobe_app/widgets/route_pill.dart';
import 'package:myprobe_app/widgets/widgets.dart';

class RouteBody extends StatefulWidget {
  final ProbeNode node;
  final Map<String, dynamic> mtr;
  const RouteBody({super.key, required this.node, required this.mtr});
  @override
  State<RouteBody> createState() => _RoutePageState();
}

class _RoutePageState extends State<RouteBody> {
  String _mode = 'icmp'; // tcp | tcp-big | icmp（只有 icmp 有数据）
  String _view = 'hops'; // hops | as
  late String _region;
  String _carrier = 'telecom';
  Map<String, String> _outLabels = {};
  Map<String, String> _outDates = {};
  // 线路变化记录（本机存）：详情页每次进页记一次回程标签快照。
  List<RouteSnapshot> _routeHist = [];

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
    _reloadOut();
    _loadHist();
  }

  Future<void> _loadHist() async {
    final h = await loadRouteHistory(widget.node.id);
    if (mounted) setState(() => _routeHist = h);
  }

  Future<void> _reloadOut() async {
    final r = await loadOutRoutes(widget.node.id);
    if (mounted) {
      setState(() {
        _outLabels = r.labels;
        _outDates = r.dates;
      });
    }
  }

  Future<void> _record(String carrier) async {
    final change = await recordOutboundRoute(context,
        nodeId: widget.node.id,
        carrier: carrier,
        carrierName: ispNames[carrier]!,
        nodeIp: widget.node.ip.trim(),
        savedLabel: _outLabels[carrier],
        savedDate: _outDates[carrier]);
    if (change != null) await _reloadOut();
  }

  List<Map<String, dynamic>> _hops(String carrier) {
    final m = widget.mtr[carrier];
    if (m is! Map<String, dynamic>) return const [];
    return ((m['hops'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  String? _tsText(String carrier) {
    final m = widget.mtr[carrier];
    final ts = m is Map<String, dynamic> ? m['ts'] : null;
    if (ts is! num) return null;
    final ms = ts > 1000000000000 ? ts.toInt() : ts.toInt() * 1000;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final hops = _hops(_carrier);
    final medians = medianLatencyByRegion(widget.node.nodeProbes, _region);
    final tsText = _tsText(_carrier);
    return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text('回程路由',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: BocchiTheme.ink)),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _mode,
                onSelected: (v) => setState(() => _mode = v),
                itemBuilder: (ctx) => [
                  for (final m in [
                    ('tcp', 'TCP'),
                    ('tcp-big', 'TCP 大包'),
                    ('icmp', 'ICMP'),
                  ])
                    PopupMenuItem<String>(
                      value: m.$1,
                      child: Row(
                        children: [
                          Text(m.$2),
                          const Spacer(),
                          if (_mode == m.$1)
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
                      Text(
                          _mode == 'tcp'
                              ? 'TCP'
                              : _mode == 'tcp-big'
                                  ? 'TCP 大包'
                                  : 'ICMP',
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
          // 逐跳 / 按 AS 折叠
          Container(
            decoration: BoxDecoration(
              color: BocchiTheme.inkSoft.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final v in [
                  ('hops', '逐跳'),
                  ('as', '按 AS 折叠'),
                ])
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _view = v.$1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _view == v.$1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(v.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _view == v.$1
                                    ? BocchiTheme.ink
                                    : BocchiTheme.inkSoft)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
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
            ],
          ),
          const SizedBox(height: 12),
          // 三网 pill：运营商 + 回程线路名
          Row(
            children: [
              for (final c in ['telecom', 'unicom', 'mobile'])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: c == 'mobile' ? 0 : 8),
                    child: InkWell(
                      onTap: () => setState(() => _carrier = c),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: _carrier == c
                              ? const Color(0xFF1F9E8E)
                                  .withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _carrier == c
                                ? const Color(0xFF1F9E8E)
                                : BocchiTheme.inkSoft
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(ispNames[c]!,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: BocchiTheme.ink)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                routeLabelFromHops(c, _hops(c)) ??
                                    '未识别',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        routeLabelFromHops(c, _hops(c)) ==
                                                null
                                            ? BocchiTheme.inkSoft
                                            : const Color(0xFF1F9E8E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            medians.isEmpty
                ? '$_region暂无拨测'
                : '$_region三网中位延迟：${[
                    for (final c in ['telecom', 'unicom', 'mobile'])
                      if (medians[c] != null)
                        '${ispNames[c]} ${medians[c]!.toStringAsFixed(0)}ms'
                  ].join(' · ')}',
            style:
                TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(
            'MTR · ICMP${tsText == null ? '' : ' · $tsText'} · 单组测量（目标全国 DNS），不分地区',
            style:
                TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft),
          ),
          const SizedBox(height: 12),
          if (_mode != 'icmp')
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '该模式暂无数据 · agent 仅上报 ICMP MTR，没有 ${_mode == 'tcp' ? 'TCP' : 'TCP 大包'} 的逐跳数据（需 agent 改跑 ${_mode == 'tcp' ? 'TCP' : 'TCP 大包'} MTR 并上报）',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft),
                ),
              ),
            )
          else if (_view == 'as')
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '无 ASN 数据，无法按 AS 折叠 · agent 只报跳点 host，不报 ASN/位置（需 agent 上报每跳 ASN 才能折叠）',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft),
                ),
              ),
            )
          else if (hops.isEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '暂无数据 · agent 每 30 分钟跑一次',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft),
                ),
              ),
            )
          else
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _hopHeader(),
                    const Divider(height: 12),
                    for (var i = 0; i < hops.length; i++) ...[
                      _hopRow(hops[i]),
                      if (i < hops.length - 1)
                        Divider(
                            height: 1,
                            color: BocchiTheme.inkSoft
                                .withValues(alpha: 0.1)),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'ASN / 位置 / Wrst：agent 未上报，填 --；ASN 列小字为跳点地址。入境分界：无位置数据，不标。',
            style:
                TextStyle(fontSize: 12, color: BocchiTheme.inkSoft),
          ),
          const SizedBox(height: 12),
          _nextTraceCard(),
          const SizedBox(height: 12),
          _outboundCard(),
          const SizedBox(height: 12),
          _changesCard(),
        ],
    );
  }

  /// NextTrace 回程对照（NQ 快照）：只作对照，不改 MyProbe 自测的
  /// 回程 pill——NQ 写广东电信 CN2GIA，但 MyProbe 自测是回程未识别。
  Widget _nextTraceCard() {
    final isSj = widget.node.id == tqSnapshotNodeId;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('回程路由对照（NextTrace · NQ）',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 4),
            Text(
                isSj
                    ? 'NodeQuality $nqSnapshotTime · 北京/上海/广东三网：电信与联通 CN2GIA、移动 CMIN2'
                    : '本节点暂无 NQ 快照',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft)),
            const SizedBox(height: 10),
            if (!isSj)
              Text('未测 · 只有圣何塞节点有 2026-11-24 的 NQ 报告',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft))
            else ...[
              for (final r in nqNextTrace) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(r.$1,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: BocchiTheme.ink)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$2,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F9E8E))),
                          const SizedBox(height: 2),
                          Text(r.$3,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: BocchiTheme.inkSoft)),
                          Text(r.$4,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: BocchiTheme.inkSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (r != nqNextTrace.last)
                  const Divider(height: 12),
              ],
              const SizedBox(height: 8),
              Text(
                  '对照口径：NQ 写广东电信 CN2GIA，但 MyProbe 自测 MTR 判回程未识别（Zayo 中转）——详情页回程 pill 以 MyProbe 自测为准，不改写。',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  /// 去程路由：没有全国探测路径，去程名只能由本机 tracepath 实测
  /// 录入（一次一卡）；没录入的写 未测，不编数。
  Widget _outboundCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('去程路由',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 4),
            Text('MTR ICMP · 本机实测录入（一次一卡，换卡重测重录）',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft)),
            const SizedBox(height: 10),
            for (final c in ['telecom', 'unicom', 'mobile']) ...[
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(ispNames[c]!,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.ink)),
                  ),
                  RoutePill('去', _outLabels[c],
                      onTap: () => _record(c)),
                  if (_outDates[c] != null) ...[
                    const SizedBox(width: 8),
                    Text(_outDates[c]!,
                        style: TextStyle(
                            fontSize: 12,
                            color: BocchiTheme.inkSoft)),
                  ],
                  const Spacer(),
                  Text('点 pill 录入',
                      style: TextStyle(
                          fontSize: 12,
                          color: BocchiTheme.inkSoft)),
                ],
              ),
              if (c != 'mobile') const Divider(height: 14),
            ],
            const SizedBox(height: 8),
            Text('无全国探测路径：MyProbe 没有国内测试点，去程跳点表做不出来；只有本机录入的标签。',
                style: TextStyle(
                    fontSize: 12, color: BocchiTheme.inkSoft)),
          ],
        ),
      ),
    );
  }

  /// 线路变化记录：本机存的回程标签快照（详情页每次进页记一次，
  /// 无变化不写）。第一条是基线，之后每条都是一次标签翻转。
  Widget _changesCard() {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('线路变化记录',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 8),
            if (_routeHist.isEmpty)
              Text(
                  '暂无变化记录 · 本机从 $today 起，每次进详情页记一次三网回程标签快照，有变化才追加（例如联通 4837 ↔ 未识别翻转会在这里留痕）',
                  style: TextStyle(
                      fontSize: 13, color: BocchiTheme.inkSoft))
            else ...[
              Text('记录始于 ${_routeHist.first.date} · 共 ${_routeHist.length} 条快照',
                  style: TextStyle(
                      fontSize: 12.5, color: BocchiTheme.inkSoft)),
              const SizedBox(height: 8),
              for (var i = 0; i < _routeHist.length; i++) ...[
                _histRow(_routeHist[i],
                    isFirst: i == 0),
                if (i < _routeHist.length - 1)
                  Divider(
                      height: 12,
                      color:
                          BocchiTheme.inkSoft.withValues(alpha: 0.1)),
              ],
              const SizedBox(height: 6),
              Text('只记标签变化，不记跳点明细；去程（tracepath 录入）不进这张表。',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _histRow(RouteSnapshot s, {bool isFirst = false}) {
    String lbl(String? v) => v ?? '未识别';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(s.date,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BocchiTheme.ink)),
        ),
        Expanded(
          child: Text(
            '电信 ${lbl(s.labels['telecom'])} · 联通 ${lbl(s.labels['unicom'])} · 移动 ${lbl(s.labels['mobile'])}${isFirst ? '（基线）' : ''}',
            style:
                TextStyle(fontSize: 13, color: BocchiTheme.ink),
          ),
        ),
      ],
    );
  }

  Widget _hopHeader() {
    const hs = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey);
    return Row(
      children: [
        SizedBox(width: 26, child: Text('跳', style: hs)),
        Expanded(child: Text('ASN', style: hs)),
        SizedBox(width: 44, child: Text('位置', style: hs)),
        SizedBox(
            width: 52,
            child: Text('丢包', style: hs, textAlign: TextAlign.right)),
        SizedBox(
            width: 62,
            child: Text('Avg', style: hs, textAlign: TextAlign.right)),
        SizedBox(
            width: 62,
            child: Text('Wrst', style: hs, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _hopRow(Map<String, dynamic> hop) {
    final avg = hop['avg'];
    final loss = hop['loss'];
    final host = '${hop['host'] ?? ''}';
    final noAnswer = host == '*' || host.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text('${hop['n'] ?? ''}',
                style: TextStyle(
                    fontSize: 12.5, color: BocchiTheme.inkSoft)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('—',
                    style: TextStyle(
                        fontSize: 12.5, color: BocchiTheme.ink)),
                if (!noAnswer)
                  Text(host,
                      style: TextStyle(
                          fontSize: 11, color: BocchiTheme.inkSoft),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('—',
                style: TextStyle(
                    fontSize: 12.5, color: BocchiTheme.inkSoft)),
          ),
          SizedBox(
            width: 52,
            child: Text(
              loss == null
                  ? '--'
                  : '${(loss as num).toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12.5, color: BocchiTheme.ink),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              avg == null
                  ? '--'
                  : '${(avg as num).toStringAsFixed(1)}ms',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12.5, color: BocchiTheme.ink),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text('--',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12.5, color: BocchiTheme.inkSoft)),
          ),
        ],
      ),
    );
  }
}
