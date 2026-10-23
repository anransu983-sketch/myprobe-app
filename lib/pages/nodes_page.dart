import 'dart:async';
import 'package:flutter/material.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/node_card.dart';
import 'node_detail_page.dart';

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
    setState(() => _page = p);
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
                          onPageChanged: (p) =>
                              setState(() => _page = p),
                          itemBuilder: (_, p) => p == 0
                              ? _AllPager(
                                  nodes: _nodes,
                                  onTapNode: (i) =>
                                      _goPage(i + 1),
                                  onChanged: () =>
                                      _fetch(silent: true),
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

/// 全部页：纵向磁吸翻卡。
/// v1.16 Folia 风焦点缩放（学海报墙/Carousel 的中心聚焦）：翻页过程中
/// 非中心卡缩小到 0.96、透明度降到 0.72，中心卡满格——滑的时候一眼
/// 知道焦点落在哪张。只动 transform/opacity（合成层，便宜），
/// 性能模式下关闭、回到原来的硬翻。
class _AllPager extends StatefulWidget {
  final List<ProbeNode> nodes;
  final void Function(int index) onTapNode;
  final VoidCallback onChanged;
  const _AllPager(
      {required this.nodes,
      required this.onTapNode,
      required this.onChanged});
  @override
  State<_AllPager> createState() => _AllPagerState();
}

class _AllPagerState extends State<_AllPager> {
  final _vCtrl = PageController();
  double _pagePos = 0;

  @override
  void initState() {
    super.initState();
    _vCtrl.addListener(() {
      if (_vCtrl.hasClients && _vCtrl.page != null) {
        setState(() => _pagePos = _vCtrl.page!);
      }
    });
  }

  @override
  void dispose() {
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.nodes;
    if (nodes.isEmpty) {
      return Center(
          child: Text('暂无节点',
              style: TextStyle(color: BocchiTheme.inkSoft)));
    }
    final perf = BocchiTheme.performanceMode;
    return PageView.builder(
      controller: _vCtrl,
      scrollDirection: Axis.vertical,
      pageSnapping: true,
      itemCount: nodes.length,
      itemBuilder: (_, i) {
        final dist = perf ? 0.0 : (_pagePos - i).abs().clamp(0.0, 1.0);
        final card = SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: PhoneNodeCard(
            node: nodes[i],
            onChanged: widget.onChanged,
            onTap: () => widget.onTapNode(i),
          ),
        );
        if (perf) return card;
        return Opacity(
          opacity: 1 - dist * 0.28,
          child: Transform.scale(scale: 1 - dist * 0.04, child: card),
        );
      },
    );
  }
}
