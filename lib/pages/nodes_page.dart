import 'dart:async';
import 'package:flutter/material.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/node_card.dart';
import 'node_detail_page.dart';
import 'compare_page.dart';
import 'node_admin.dart';

/// 节点 Tab：顶部 pills（全部/各节点）+ 横滑分页；
/// 全部页纵向磁吸翻卡，单机页复用详情内容
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
  final _hCtrl = PageController();
  final _pillScroll = ScrollController();
  int _page = 0; // 0=全部，1..n=第i个节点
  int? _lastViewed; // 上次打开过的节点下标，列表行左侧画主题色竖线
  final Map<int, GlobalKey> _pillKeys = {};

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
    _hCtrl.dispose();
    _pillScroll.dispose();
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
        // 节点增减后 clamp 页码
        if (_page > _nodes.length) {
          _page = _nodes.length;
          if (_hCtrl.hasClients) _hCtrl.jumpToPage(_page);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  void _goPage(int p) {
    setState(() {
      _page = p;
      if (p > 0) _lastViewed = p - 1;
    });
    if (_hCtrl.hasClients) {
      _hCtrl.animateToPage(p,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
    final k = _pillKeys[p];
    if (k?.currentContext != null) {
      Scrollable.ensureVisible(k!.currentContext!,
          duration: const Duration(milliseconds: 250),
          alignment: 0.5);
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
              icon: const Icon(Icons.compare_arrows),
              tooltip: '节点对比',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ComparePage()),
              ),
            ),
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
                            style:  TextStyle(
                                color: BocchiTheme.inkSoft)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: () => _fetch(),
                            child: const Text('重试')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _pills(),
                      Expanded(
                        child: PageView.builder(
                          controller: _hCtrl,
                          itemCount: 1 + _nodes.length,
                          onPageChanged: (p) => setState(() {
                                _page = p;
                                if (p > 0) _lastViewed = p - 1;
                              }),
                          itemBuilder: (_, p) => p == 0
                              ? _AllPager(
                                  nodes: _nodes,
                                  onTapNode: (i) =>
                                      _goPage(i + 1),
                                  onChanged: () =>
                                      _fetch(silent: true),
                                  lastViewed: _lastViewed,
                                )
                              : NodeDetailBody(
                                  key: ValueKey(
                                      'detail-${_nodes[p - 1].id}'),
                                  nodeId: _nodes[p - 1].id,
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _pills() {
    final labels = [
      '全部',
      for (final n in _nodes)
        (n.name.isEmpty ? n.id : n.name)
    ];
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        controller: _pillScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: labels.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == _page;
          _pillKeys[i] ??= GlobalKey();
          return GestureDetector(
            key: _pillKeys[i],
            onTap: () => _goPage(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              transform: Matrix4.diagonal3Values(
                  sel ? 1.0 : 0.96, sel ? 1.0 : 0.96, 1.0),
              transformAlignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: sel
                    ? BocchiTheme.pinkDeep
                    : BocchiTheme.current.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: sel && !BocchiTheme.performanceMode
                    ? [
                        BoxShadow(
                          color: BocchiTheme.pinkDeep
                              .withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
                border: sel
                    ? null
                    : Border.all(
                        color: BocchiTheme.pink
                            .withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? BocchiTheme.onAccent
                          : BocchiTheme.ink)),
            ),
          );
        },
      ),
    );
  }
}

/// 全部页：PickMyVPS 式紧凑行表——一张大卡里装所有节点行，行间只有
/// 一条极细分隔线；每行两行式（节点名＋在线状态在上，关键指标灰字在
/// 下），右边是三网延迟（大数字在上、线路胶囊在下），最低延迟用主题
/// 色标出；上次打开过的节点左侧有一条主题色竖线。
/// 点行进详情；管理员长按行打开节点管理（编辑/删除），入口仍在。
class _AllPager extends StatelessWidget {
  final List<ProbeNode> nodes;
  final void Function(int index) onTapNode;
  final VoidCallback onChanged;
  final int? lastViewed;
  const _AllPager(
      {required this.nodes,
      required this.onTapNode,
      required this.onChanged,
      this.lastViewed});

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return Center(
          child: Text('暂无节点',
              style: TextStyle(color: BocchiTheme.inkSoft)));
    }
    final admin = AppState.instance.client.admin;
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        GlassCard(
          child: Column(
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: BocchiTheme.inkSoft
                          .withValues(alpha: 0.14)),
                _NodeRow(
                  node: nodes[i],
                  highlighted: lastViewed == i,
                  onTap: () => onTapNode(i),
                  onLongPress: admin
                      ? () => NodeAdmin.sheet(
                          context, nodes[i], onChanged)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 列表行：左列节点名＋关键指标，右列三网延迟格，末尾小箭头
class _NodeRow extends StatelessWidget {
  final ProbeNode node;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _NodeRow(
      {required this.node,
      required this.highlighted,
      required this.onTap,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final n = node;
    // 只取三网那三格（同省若还有别的探测，不挤进这一行）
    final ps = probesForCurrentRegion(n.nodeProbes)
        .where((p) =>
            p.name.endsWith('移动') ||
            p.name.endsWith('电信') ||
            p.name.endsWith('联通'))
        .toList();
    double? minLat;
    for (final p in ps) {
      final l = p.latencyMs;
      if (l != null && (minLat == null || l < minLat)) minLat = l;
    }
    final cur = n.currency ?? '¥';
    final sub = [
      if (n.hostname.isNotEmpty) n.hostname,
      if ((n.price ?? 0) > 0)
        '${n.billCycle == 'yearly' ? '年付' : '月付'} $cur${n.price!.toStringAsFixed(n.price! % 1 == 0 ? 0 : 2)}',
      if (n.daysLeft != null)
        (n.daysLeft! < 0 ? '已过期' : '余期${n.daysLeft}天'),
      if (n.quotaGb > 0)
        '流量 ${(n.quotaUsedGb > 0 ? n.quotaUsedGb : n.monthRxGb + n.monthTxGb).toStringAsFixed(1)}/${n.quotaGb.toStringAsFixed(0)}GB',
      updatedAgoText(n),
    ].join(' · ');
    final content = Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          if (highlighted)
            Container(
              width: 3,
              height: 46,
              decoration: BoxDecoration(
                color: BocchiTheme.pinkDeep,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (highlighted) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OnlineDot(online: n.online),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${countryFlag(n.ipCountry) ?? ''}${countryFlag(n.ipCountry) == null ? '' : ' '}${n.name.isEmpty ? n.id : n.name}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BocchiTheme.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sub.isEmpty
                      ? AppState.instance.showIp(n.ip)
                      : sub,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: BocchiTheme.inkSoft),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          for (final p in ps)
            _LatencyCell(
                probe: p,
                isMin:
                    p.latencyMs != null && p.latencyMs == minLat),
          Icon(Icons.chevron_right,
              size: 18, color: BocchiTheme.inkSoft),
        ],
      ),
    );
    return Opacity(
      opacity: n.online ? 1 : 0.62,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }
}

/// 三网延迟格：大数字在上、线路胶囊在下；最低延迟用主题色标出
class _LatencyCell extends StatelessWidget {
  final NodeProbe probe;
  final bool isMin;
  const _LatencyCell({required this.probe, required this.isMin});

  @override
  Widget build(BuildContext context) {
    final lat = probe.latencyMs;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: 46,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(lat == null ? '--' : lat.toStringAsFixed(0),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isMin
                        ? BocchiTheme.pinkDeep
                        : BocchiTheme.ink)),
            const SizedBox(height: 3),
            LineCapsule(carrierOf(probe)),
          ],
        ),
      ),
    );
  }
}
