import 'package:flutter/material.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import 'widgets.dart';
import '../pages/node_admin.dart';

/// 探测目标展示风格（预览对比用）
enum ProbesStyle {
  standard, // 当前版
  slim, // 纤细版：更紧凑
  sectioned, // 分区版：独立底色块
}

/// PickMyVPS 式线路小胶囊：主题色浅底 + 主题色描边 + 圆角（参考页是
/// 青色虚线边框，Flutter 没有虚线边框，用半透明实线描边近似；颜色走
/// 当前主题，不写死粉色）
class LineCapsule extends StatelessWidget {
  final String label;
  final Color? color;
  const LineCapsule(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? BocchiTheme.pinkDeep;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

/// 按省份分组探测结果（名字以 移动/电信/联通 结尾，前面是省份）；
/// 每组内按 移动/电信/联通 排序。列表行和详情页探测目标共用。
Map<String, List<NodeProbe>> groupProbesByRegion(
    List<NodeProbe> ps) {
  final map = <String, List<NodeProbe>>{};
  for (final p in ps) {
    var region = '其他';
    for (final c in ['移动', '电信', '联通']) {
      if (p.name.endsWith(c) && p.name.length > c.length) {
        region = p.name.substring(0, p.name.length - c.length);
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

/// 当前省份的那组探测（优先 AppState 存的省份，没有就默认浙江，
/// 再没有取首组）。列表行和详情页探测目标共用。
List<NodeProbe> probesForCurrentRegion(List<NodeProbe> ps) {
  final groups = groupProbesByRegion(ps);
  if (groups.isEmpty) return const [];
  final regions = groups.keys.toList();
  final saved = AppState.instance.probeRegion;
  final region = (saved != null && regions.contains(saved))
      ? saved
      : regions.contains('浙江')
          ? '浙江'
          : regions.first;
  return groups[region] ?? [];
}

/// 运营商简称（探测名以它结尾；不以三网结尾的返回原名）
String carrierOf(NodeProbe p) {
  for (final c in ['移动', '电信', '联通']) {
    if (p.name.endsWith(c)) return c;
  }
  return p.name;
}

/// 手机版统一节点卡：名字+图标+余期+💻 / pills / 指标2x2 / 三统计盒 / 探测目标
/// 全部页、单机页共用
class PhoneNodeCard extends StatelessWidget {
  final ProbeNode node;
  final VoidCallback? onChanged;
  final VoidCallback? onTap;
  final ProbesStyle probesStyle;
  /// 紧凑模式（仅详情页用）：内边距和间距收紧，卡别又高又空；
  /// 列表页默认 false，样子一字不动
  final bool compact;
  /// 三网 24h 采样（详情页传，养鸡场式 24 格分段条用；不传就不画）
  final Map<String, dynamic>? netq;
  const PhoneNodeCard(
      {super.key,
      required this.node,
      this.onChanged,
      this.onTap,
      this.probesStyle = ProbesStyle.standard,
      this.compact = false,
      this.netq});

  static String mb(int b) =>
      b <= 0 ? '--' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  static String gb(num b) => b <= 0
      ? '--'
      : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}G';
  static double usedBytes(double? pct, int total) =>
      pct == null ? 0 : (pct / 100 * total);

  /// 余值 = 价格 × 剩余天数 / 周期总天数（跟网页端同口径）
  static double? remainValue(ProbeNode n) {
    if ((n.price ?? 0) <= 0 || n.daysLeft == null) return null;
    var total = n.billCycle == 'yearly' ? 365 : 30;
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
    if (total <= 0) return null;
    final left = n.daysLeft!.clamp(0, 1 << 30);
    return n.price! * left / total;
  }

  @override
  Widget build(BuildContext context) {
    final n = node;
    final admin = AppState.instance.client.admin;
    final cur = n.currency ?? '¥';
    final rv = remainValue(n);
    final osIcon =
        n.os.toLowerCase().contains('linux') ? '🐧' : '🖥️';
    final card = GlassCard(
      margin: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                OnlineDot(online: n.online),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${countryFlag(n.ipCountry) ?? ''}${countryFlag(n.ipCountry) == null ? '' : ' '}${n.name.isEmpty ? n.id : n.name}',
                    style:  TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.ink),
                  ),
                ),
                Text(osIcon,
                    style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 6),
                const Text('🌐',
                    style: TextStyle(fontSize: 17)),
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
                        style: TextStyle(fontSize: 19)),
                    tooltip: 'SSH 终端',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => AppState.instance
                        .openTerminalFor(n),
                  ),
                if (admin)
                  IconButton(
                    icon:  Icon(Icons.more_vert,
                        color: BocchiTheme.inkSoft),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => NodeAdmin.sheet(
                        context, n, onChanged ?? () {}),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${n.hostname} · ${AppState.instance.showIp(n.ip)} · ${updatedAgoText(n)}',
              style:  TextStyle(
                  fontSize: 12,
                  color: BocchiTheme.inkSoft),
            ),
            SizedBox(height: compact ? 6 : 8),
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
            SizedBox(height: compact ? 8 : 12),
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
                            '${mb(usedBytes(n.mem, n.memTotal).toInt())} / ${mb(n.memTotal)}')),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
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
                            '${gb(usedBytes(n.disk, n.diskTotal))} / ${gb(n.diskTotal)}')),
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
                            ? '${(n.quotaUsedGb > 0 ? n.quotaUsedGb : n.monthRxGb + n.monthTxGb).toStringAsFixed(1)} GB / ${n.quotaGb.toStringAsFixed(0)} GB${pricePerTb(n) == null ? '' : ' · ${pricePerTb(n)}'}'
                            : '未设配额')),
              ],
            ),
            SizedBox(height: compact ? 6 : 10),
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
                        line1: n.quotaUsedGb > 0 &&
                                n.quotaUsedGb >
                                    n.monthRxGb + n.monthTxGb
                            ? '合计 ${n.quotaUsedGb.toStringAsFixed(1)} GB\n↑${n.monthTxGb.toStringAsFixed(1)} ↓${n.monthRxGb.toStringAsFixed(1)}'
                            : '↑${n.monthTxGb.toStringAsFixed(1)} GB\n↓${n.monthRxGb.toStringAsFixed(1)} GB',
                        line2: '本月流量')),
                const SizedBox(width: 8),
                Expanded(
                    // 余期只在卡头 PinkPill 报一处，这里只报余值，避免同屏重复
                    child: WebStatBox(
                        line1: n.daysLeft != null
                            ? (rv != null
                                ? '余值$cur${rv.toStringAsFixed(2)}'
                                : '余值 --')
                            : '${n.online ? '在线' : '离线'}\n${AppState.instance.showIp(n.ip)}',
                        line2: n.daysLeft != null
                            ? '余值'
                            : '状态 / IP')),
              ],
            ),
            _RegionProbes(node: n, style: probesStyle, netq: netq),
            _TagRow(node: n),
          ],
        ),
      ),
    );
    // 全玻璃统一：GlassCard 内部就是逐卡 BackdropFilter 真毛玻璃
    // （三款主题同一套机制，参数从 AppThemeDef 取）。
    final Widget inner = card;
    if (onTap == null) {
      return Opacity(
          opacity: n.online ? 1 : 0.62, child: inner);
    }
    return Opacity(
      opacity: n.online ? 1 : 0.62,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: inner,
      ),
    );
  }
}

/// 节点自定义标签行（养鸡场式 pill，卡底）：标签存本机（见
/// AppState.nodeTags），没标签时不占地方
class _TagRow extends StatelessWidget {
  final ProbeNode node;
  const _TagRow({required this.node});
  @override
  Widget build(BuildContext context) {
    final tags = AppState.instance.nodeTags(node.id);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final t in tags)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: BocchiTheme.inkSoft
                          .withValues(alpha: 0.45)),
                ),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 12,
                        color: BocchiTheme.inkSoft)),
              ),
          ],
        ),
      ],
    );
  }
}

/// 手机版探测目标：地区 chips + 运营商行（名字/延迟/丢包 + 细粉条），无网页表头
class _RegionProbes extends StatefulWidget {
  final ProbeNode node;
  final ProbesStyle style;
  /// 三网 24h 采样（详情页传）：每格下面画养鸡场式 24 格分段条
  final Map<String, dynamic>? netq;
  const _RegionProbes(
      {required this.node,
      this.style = ProbesStyle.standard,
      this.netq});
  @override
  State<_RegionProbes> createState() =>
      _RegionProbesState();
}

class _RegionProbesState extends State<_RegionProbes> {
  String? _region;

  @override
  Widget build(BuildContext context) {
    final groups = groupProbesByRegion(widget.node.nodeProbes);
    if (groups.isEmpty) return const SizedBox.shrink();
    final regions = groups.keys.toList();
    if (_region == null || !regions.contains(_region)) {
      // 优先上次选的省份（AppState 持久化），从未选过才默认浙江
      final saved = AppState.instance.probeRegion;
      _region = (saved != null && regions.contains(saved))
          ? saved
          : regions.contains('浙江')
              ? '浙江'
              : regions.first;
    }
    final ps = groups[_region] ?? [];
    double? minLat;
    for (final p in ps) {
      final l = p.latencyMs;
      if (l != null && (minLat == null || l < minLat)) minLat = l;
    }
    final slim = widget.style == ProbesStyle.slim;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('📡 探测目标',
                style: TextStyle(
                    fontSize: slim ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: BocchiTheme.ink)),
            const Spacer(),
            _RegionButton(
              region: _region!,
              onTap: () => _pickRegion(context, regions),
            ),
          ],
        ),
        SizedBox(height: slim ? 6 : 10),
        // PickMyVPS 式两行格：延迟大数字在上、线路胶囊在下，三网横排；
        // 最低延迟的数字用主题色标出；丢包小灰字跟在胶囊后；每格下面
        // 各留一条纤细历史小条。
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in ps)
              Expanded(child: _probeCell(p, minLat)),
          ],
        ),
      ],
    );
    if (widget.style == ProbesStyle.sectioned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 28),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BocchiTheme.pinkLight
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: content,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: slim ? 20 : 28),
        content,
      ],
    );
  }

  /// 探测目标单格：延迟大数字在上、线路胶囊在下
  Widget _probeCell(NodeProbe p, double? minLat) {
    final lat = p.latencyMs;
    final isMin = lat != null && lat == minLat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: lat == null ? '--' : lat.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isMin
                          ? BocchiTheme.pinkDeep
                          : BocchiTheme.ink),
                ),
                TextSpan(
                    text: ' ms',
                    style: TextStyle(
                        fontSize: 11,
                        color: BocchiTheme.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              LineCapsule(carrierOf(p)),
              if (p.lossPct != null) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '丢包 ${p.lossPct!.toStringAsFixed(1)}%',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        color: BocchiTheme.inkSoft),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // key 含节点 id + 当前省份 + 任务 id：切省份/切节点时新建
          // State 重播渐进动画；同节点同省份的数据刷新同 key 不重播。
          PinkBars(
              key: ValueKey(
                  'pink-${widget.node.id}-$_region-${p.taskId}'),
              latencies: p.histLat,
              oks: p.bars,
              height: 5),
          // 养鸡场式 24 格分段条：netq 24h 采样按本地小时聚合，
          // 每格一小时，绿/黄/红按延迟，没数据的格子灰色
          if (widget.netq != null) ...[
            const SizedBox(height: 5),
            _HourStrip(hours: _hourlyLat(p)),
          ],
        ],
      ),
    );
  }

  /// 该运营商 24h 采样按小时聚合（本地时区），返回 24 格平均延迟
  /// （null = 该小时无采样）。netq 的 ts 是毫秒。
  List<double?> _hourlyLat(NodeProbe p) {
    final out = List<double?>.filled(24, null);
    final key = p.name.endsWith('电信')
        ? 'telecom'
        : p.name.endsWith('联通')
            ? 'unicom'
            : p.name.endsWith('移动')
                ? 'mobile'
                : null;
    if (key == null) return out;
    final d = widget.netq![key] as Map<String, dynamic>?;
    if (d == null) return out;
    final ts = ((d['ts'] as List?) ?? [])
        .map((e) => (e as num?)?.toInt() ?? 0)
        .toList();
    final lats = ((d['lat'] as List?) ?? [])
        .map((e) => e == null ? null : (e as num).toDouble())
        .toList();
    final sums = List<double>.filled(24, 0);
    final cnts = List<int>.filled(24, 0);
    for (var i = 0; i < ts.length && i < lats.length; i++) {
      final v = lats[i];
      if (v == null) continue;
      final h = DateTime.fromMillisecondsSinceEpoch(ts[i]).hour;
      sums[h] += v;
      cnts[h]++;
    }
    for (var h = 0; h < 24; h++) {
      if (cnts[h] > 0) out[h] = sums[h] / cnts[h];
    }
    return out;
  }

  /// 省份选择：底部弹窗网格
  Future<void> _pickRegion(
      BuildContext context, List<String> regions) async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      // 透明底：让 GlassSheet 的 BackdropFilter 采样到弹窗背后的页面/壁纸
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GlassSheet(
        child: SafeArea(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: BocchiTheme.pink
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                   Text('选择省份',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: BocchiTheme.ink)),
                  const Spacer(),
                  IconButton(
                    icon:  Icon(Icons.close,
                        color: BocchiTheme.inkSoft),
                    onPressed: () =>
                        Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: regions.length,
                  itemBuilder: (_, i) {
                    final r = regions[i];
                    final on = r == _region;
                    return GestureDetector(
                      onTap: () =>
                          Navigator.of(ctx).pop(r),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on
                              ? BocchiTheme.pinkDeep
                              : BocchiTheme.pinkLight
                                  .withValues(alpha: 0.4),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(r,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: on
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: on
                                    ? BocchiTheme.onAccent
                                    : BocchiTheme.ink)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
    if (sel != null && sel != _region && mounted) {
      setState(() => _region = sel);
      // 记住选择：重启/重进页面后恢复，不再跳回默认浙江
      await AppState.instance.setProbeRegion(sel);
    }
  }
}

/// 养鸡场式 24 格分段条：24 小时每小时一格，颜色按该小时平均延迟
/// （绿 <100ms、黄 100–200ms、红 >200ms、无数据灰），见 models.latencyCellColor
class _HourStrip extends StatelessWidget {
  final List<double?> hours;
  const _HourStrip({required this.hours});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (var i = 0; i < 24; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 23 ? 0 : 1.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(latencyCellColor(
                        i < hours.length ? hours[i] : null)),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 省份折叠按钮：只显示当前省，点开选省
class _RegionButton extends StatelessWidget {
  final String region;
  final VoidCallback onTap;
  const _RegionButton(
      {required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: BocchiTheme.pinkLight
              .withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: BocchiTheme.pinkDeep, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(region,
                style:  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: BocchiTheme.pinkDeep)),
            const SizedBox(width: 4),
             Icon(Icons.arrow_drop_down,
                size: 20, color: BocchiTheme.pinkDeep),
          ],
        ),
      ),
    );
  }
}
