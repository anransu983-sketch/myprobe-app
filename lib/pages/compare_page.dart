import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';

/// 节点对比页（v1.17.4，借鉴 PickMyVPS 对比）：选 2–4 台并排比。
/// 规格对照表 + 三网延迟趋势。ICMP 用 netq 采样；TCP 用 TCP 类型
/// 拨测任务的各节点最新结果（任务本身没有时不造数据，只给空态）。
/// TCP 表可按区域（省份组内三网）或按运营商（运营商组内各省份）分组。
class ComparePage extends StatefulWidget {
  const ComparePage({super.key});
  @override
  State<ComparePage> createState() => _ComparePageState();
}

const _ispKeys = ['telecom', 'unicom', 'mobile'];
const _ispLabels = {'telecom': '电信', 'unicom': '联通', 'mobile': '移动'};
const _lineColors = [
  Color(0xFFE91E63),
  Color(0xFF7B61FF),
  Color(0xFF43A047),
  Color(0xFFFF9800),
];

class _ComparePageState extends State<ComparePage> {
  List<ProbeNode> _nodes = [];
  List<ProbeTask> _tasks = [];
  final Set<String> _sel = {};
  String _range = '24h'; // 24h / 7d / 30d
  String _carrier = 'telecom';
  String _mode = 'icmp'; // icmp / tcp
  bool _has30d = false;
  bool _loading = true;
  bool _netqLoading = false;
  final Map<String, Map<String, dynamic>> _netq = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final c = AppState.instance.client;
      final nodes = await c.getNodes();
      List<ProbeTask> tasks = [];
      try {
        tasks = await c.getProbes();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _tasks = tasks;
        _loading = false;
        _sel
          ..clear()
          ..addAll(nodes.take(4).map((n) => n.id));
      });
      _probe30d();
      _fetchNetq();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErr(context, e);
    }
  }

  /// 30d 档只在服务端攒够数据时出现：取首台节点的 30d 采样跨度，
  /// ≥ 7 天才给 30d 选项（netq 从 v6.7 才开始攒，刚上线时不够）。
  Future<void> _probe30d() async {
    if (_nodes.isEmpty) return;
    try {
      final d = await AppState.instance.client
          .getNetq(_nodes.first.id, range: '30d');
      final ts = ((d['telecom'] as Map<String, dynamic>?)?['ts']
              as List?) ??
          [];
      if (ts.length >= 2) {
        final spanMs =
            (ts.last as num).toInt() - (ts.first as num).toInt();
        if (mounted && spanMs >= 7 * 86400 * 1000) {
          setState(() => _has30d = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchNetq() async {
    if (_sel.isEmpty) return;
    setState(() => _netqLoading = true);
    final c = AppState.instance.client;
    final out = <String, Map<String, dynamic>>{};
    for (final id in _sel) {
      try {
        out[id] = await c.getNetq(id, range: _range);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _netq
        ..clear()
        ..addAll(out);
      _netqLoading = false;
    });
  }

  List<ProbeNode> get _selNodes =>
      _nodes.where((n) => _sel.contains(n.id)).toList();

  List<ProbeTask> get _tcpTasks =>
      _tasks.where((t) => t.type == 'tcp').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '⚖️ 节点对比',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nodes.length < 2
              ? Center(
                  child: Text('至少需要 2 台节点才能对比',
                      style: TextStyle(color: BocchiTheme.inkSoft)))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _nodePicker(),
                      _specTable(),
                      _toggleCard(),
                      if (_mode == 'icmp') _icmpCard() else _tcpCard(),
                    ],
                  ),
                ),
    );
  }

  /// 节点多选：2–4 台
  Widget _nodePicker() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('对比节点（2–4 台）',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in _nodes)
                  FilterChip(
                    label: Text(n.name.isEmpty ? n.id : n.name),
                    selected: _sel.contains(n.id),
                    selectedColor: BocchiTheme.pinkDeep,
                    labelStyle: TextStyle(
                        color: _sel.contains(n.id)
                            ? Colors.white
                            : BocchiTheme.ink),
                    onSelected: (on) {
                      if (!on && _sel.length <= 2) {
                        showErr(context, '至少选 2 台对比');
                        return;
                      }
                      if (on && _sel.length >= 4) {
                        showErr(context, '最多选 4 台对比');
                        return;
                      }
                      setState(() {
                        if (on) {
                          _sel.add(n.id);
                        } else {
                          _sel.remove(n.id);
                        }
                      });
                      _fetchNetq();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 规格对照表：行是字段、列是节点
  Widget _specTable() {
    final ns = _selNodes;
    String v(int i, String Function(ProbeNode) f) =>
        i < ns.length ? f(ns[i]) : '--';
    final rows = <(String, String Function(ProbeNode))>[
      ('状态', (n) => n.online ? '在线' : '离线'),
      ('CPU', (n) =>
          '${n.cpuCores > 0 ? '${n.cpuCores}核' : '--'}${n.cpu == null ? '' : ' · ${n.cpu!.toStringAsFixed(1)}%'}'),
      ('内存',
          (n) => '${_mb(_used(n.mem, n.memTotal))} / ${_mb(n.memTotal)}'),
      ('硬盘',
          (n) => '${_gb(_used(n.disk, n.diskTotal))} / ${_gb(n.diskTotal)}'),
      ('流量配额', (n) => n.quotaGb > 0 ? '${n.quotaGb.toStringAsFixed(0)} GB' : '未设配额'),
      ('本月已用',
          (n) => '${(n.quotaUsedGb > 0 ? n.quotaUsedGb : n.monthRxGb + n.monthTxGb).toStringAsFixed(1)} GB'),
      ('流量单价', (n) => pricePerTb(n) ?? '--'),
      ('价格',
          (n) => (n.price ?? 0) > 0
              ? '${n.currency ?? '¥'}${n.price!.toStringAsFixed(n.price! % 1 == 0 ? 0 : 2)} / ${n.billCycle == 'yearly' ? '年' : '月'}'
              : '--'),
      ('到期', (n) => n.expireDate ?? '--'),
      ('余期', (n) {
        final d = n.daysLeft;
        if (d == null) return '--';
        return d < 0 ? '已过期' : '$d 天';
      }),
      ('余值', (n) {
        final rv = n.remainValue;
        if (rv == null) return '--';
        return '${n.currency ?? '¥'}${rv.toStringAsFixed(2)}';
      }),
      ('在线时长', (n) => fmtUptime(n.uptime)),
    ];
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 规格对照',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 8),
            Table(
              columnWidths: {
                0: const FlexColumnWidth(1.0),
                for (var i = 0; i < ns.length; i++)
                  i + 1: const FlexColumnWidth(1.15),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                    color: BocchiTheme.inkSoft.withValues(alpha: 0.14)),
              ),
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    for (final n in ns)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${countryFlag(n.ipCountry) ?? ''}${countryFlag(n.ipCountry) == null ? '' : ' '}${n.name.isEmpty ? n.id : n.name}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: BocchiTheme.pinkDeep),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                for (final r in rows)
                  TableRow(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Text(r.$1,
                            style: TextStyle(
                                fontSize: 12,
                                color: BocchiTheme.inkSoft)),
                      ),
                      for (var i = 0; i < ns.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 2),
                          child: Text(v(i, r.$2),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: BocchiTheme.ink),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 切换区：时段 / 运营商 / ICMP-TCP
  Widget _toggleCard() {
    Widget chips(List<String> opts, String cur, List<String> labels,
        void Function(String) onTap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < opts.length; i++)
            ChoiceChip(
              label: Text(labels[i],
                  style: const TextStyle(fontSize: 12)),
              selected: cur == opts[i],
              selectedColor: BocchiTheme.pinkDeep,
              labelStyle: TextStyle(
                  color: cur == opts[i]
                      ? Colors.white
                      : BocchiTheme.ink),
              onSelected: (_) => onTap(opts[i]),
            ),
        ],
      );
    }

    final rangeOpts = ['24h', '7d', if (_has30d) '30d'];
    final rangeLabels = [
      '24小时',
      '7天',
      if (_has30d) '30天',
    ];
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('时段',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 6),
            chips(rangeOpts, _range, rangeLabels, (r) {
              if (r == _range) return;
              setState(() => _range = r);
              _fetchNetq();
            }),
            const SizedBox(height: 12),
            Text('运营商',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 6),
            chips(_ispKeys, _carrier,
                _ispKeys.map((k) => _ispLabels[k]!).toList(),
                (c) => setState(() => _carrier = c)),
            const SizedBox(height: 12),
            Text('测量方式',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 6),
            chips(['icmp', 'tcp'], _mode, ['ICMP Ping', 'TCP Ping'],
                (m) => setState(() => _mode = m)),
          ],
        ),
      ),
    );
  }

  /// ICMP 档：各节点同运营商延迟趋势同图对照（netq 采样）
  Widget _icmpCard() {
    final ns = _selNodes;
    final series = <_CmpSeries>[];
    final latests = <String>[];
    for (var i = 0; i < ns.length; i++) {
      final n = ns[i];
      final d = _netq[n.id]?[_carrier] as Map<String, dynamic>?;
      final lats = ((d?['lat'] as List?) ?? [])
          .map((e) => e == null ? null : (e as num).toDouble())
          .toList();
      series.add(_CmpSeries(n.name.isEmpty ? n.id : n.name, lats,
          _lineColors[i % _lineColors.length]));
      final lt = d?['latest'] as Map<String, dynamic>?;
      latests.add(
          '${n.name.isEmpty ? n.id : n.name} ${lt?['lat'] == null ? '--' : '${(lt!['lat'] as num).toStringAsFixed(1)}ms'}');
    }
    var xLen = 0;
    var hasData = false;
    for (final s in series) {
      if ((s.values.length) > xLen) xLen = s.values.length;
      if (s.values.any((e) => e != null)) hasData = true;
    }
    final gridColor = BocchiTheme.inkSoft.withValues(alpha: 0.28);
    final gridColorFaint =
        BocchiTheme.inkSoft.withValues(alpha: 0.16);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '📶 ${_ispLabels[_carrier]}延迟趋势（${_range == '24h' ? '24小时' : _range == '7d' ? '7天' : '30天'}）',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 12,
                          height: 4,
                          decoration: BoxDecoration(
                              color: s.color,
                              borderRadius:
                                  BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      Text(s.name,
                          style: TextStyle(
                              fontSize: 11,
                              color: BocchiTheme.inkSoft)),
                    ],
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
                            child: Text('暂无数据 · agent 每 5 分钟采集一次',
                                style: TextStyle(
                                    color: BocchiTheme.inkSoft)))
                        : LineChart(
                            LineChartData(
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
                                          color:
                                              BocchiTheme.inkSoft),
                                    ),
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                getDrawingHorizontalLine: (_) =>
                                    FlLine(
                                        color: gridColor,
                                        strokeWidth: 1),
                                getDrawingVerticalLine: (_) =>
                                    FlLine(
                                        color: gridColorFaint,
                                        strokeWidth: 1),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                    color: gridColorFaint, width: 1),
                              ),
                              lineBarsData: [
                                for (final s in series)
                                  LineChartBarData(
                                    spots: [
                                      for (var i = 0;
                                          i < s.values.length &&
                                              i < xLen;
                                          i++)
                                        if (s.values[i] != null)
                                          FlSpot(i.toDouble(),
                                              s.values[i]!),
                                    ],
                                    isCurved: true,
                                    color: s.color,
                                    barWidth: 2,
                                    dotData:
                                        const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: s.color
                                          .withValues(alpha: 0.10),
                                    ),
                                  ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 8),
            Text('最新：${latests.join(' · ')}',
                style:
                    TextStyle(fontSize: 11.5, color: BocchiTheme.inkSoft)),
          ],
        ),
      ),
    );
  }

  /// TCP 档分组方式：region=按区域（省份组内三网），carrier=按运营商
  /// （运营商组内各省份）。任务名按「省份+运营商」解析，解析不出的
  /// 进「其他」组，不丢数据。
  String _tcpGroup = 'region';

  /// TCP 档：TCP 类型拨测任务 × 各节点最新延迟（nodeProbes 按 taskId 对齐）。
  /// 没有 TCP 任务只给空态，不造数据；失败不计延迟，失败格只显示 --。
  Widget _tcpCard() {
    final ns = _selNodes;
    final tcp = _tcpTasks;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔌 TCP 拨测对比',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: BocchiTheme.ink)),
            const SizedBox(height: 8),
            if (tcp.isEmpty)
              Text('暂无 TCP 拨测任务，去拨测页添加 TCP 任务（类型选 TCP）',
                  style: TextStyle(
                      fontSize: 12.5, color: BocchiTheme.inkSoft))
            else ...[
              Row(
                children: [
                  Text('分组',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: BocchiTheme.inkSoft)),
                  const SizedBox(width: 8),
                  for (final g in ['region', 'carrier'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g == 'region' ? '按区域' : '按运营商',
                            style: const TextStyle(fontSize: 12)),
                        selected: _tcpGroup == g,
                        selectedColor: BocchiTheme.pinkDeep,
                        labelStyle: TextStyle(
                            color: _tcpGroup == g
                                ? Colors.white
                                : BocchiTheme.ink),
                        onSelected: (_) =>
                            setState(() => _tcpGroup = g),
                      ),
                    ),
                ],
              ),
              for (final grp in _tcpGroups(tcp)) ...[
                Padding(
                  padding:
                      const EdgeInsets.only(top: 10, bottom: 2),
                  child: Text(grp.$1,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: BocchiTheme.pinkDeep)),
                ),
                _tcpTable(ns, grp.$2),
              ],
              const SizedBox(height: 8),
              Text(
                  '说明：连接被拒 / 超时均不计延迟，失败只显示 --；TCP 任务请填可建连的目标（如网站 443 端口），运营商 DNS 的 443 端口通常不通，测不到数据是正常的。',
                  style: TextStyle(
                      fontSize: 11.5, color: BocchiTheme.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  /// 一组 TCP 任务的对照表：首列任务名，其余列是各节点最新延迟
  Widget _tcpTable(List<ProbeNode> ns, List<ProbeTask> tasks) {
    return Table(
      columnWidths: {
        0: const FlexColumnWidth(1.4),
        for (var i = 0; i < ns.length; i++)
          i + 1: const FlexColumnWidth(1),
      },
      border: TableBorder(
        horizontalInside: BorderSide(
            color: BocchiTheme.inkSoft.withValues(alpha: 0.14)),
      ),
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (final n in ns)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  n.name.isEmpty ? n.id : n.name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: BocchiTheme.pinkDeep),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        for (final t in tasks)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(t.name,
                    style: TextStyle(
                        fontSize: 12, color: BocchiTheme.inkSoft),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              for (final n in ns)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 2),
                  child: Text(_tcpCell(n, t.id),
                      style: TextStyle(
                          fontSize: 12, color: BocchiTheme.ink)),
                ),
            ],
          ),
      ],
    );
  }

  /// 任务名解析：结尾是 移动/电信/联通 →（省份，运营商），否则
  /// （其他，原名）。与 node_card 的 groupProbesByRegion 同口径。
  (String, String) _splitTcpName(String name) {
    for (final c in ['移动', '电信', '联通']) {
      if (name.endsWith(c) && name.length > c.length) {
        return (name.substring(0, name.length - c.length), c);
      }
    }
    return ('其他', name);
  }

  /// TCP 任务分组：按区域时组内按 移动/电信/联通 排；按运营商时
  /// 组内保持任务原顺序。省份组按首次出现顺序，运营商组按三网顺序。
  List<(String, List<ProbeTask>)> _tcpGroups(
      List<ProbeTask> tcp) {
    const carrierOrder = ['移动', '电信', '联通'];
    if (_tcpGroup == 'carrier') {
      final map = <String, List<ProbeTask>>{};
      for (final t in tcp) {
        final c = _splitTcpName(t.name).$2;
        final key = carrierOrder.contains(c) ? c : '其他';
        map.putIfAbsent(key, () => []).add(t);
      }
      final keys = [
        ...carrierOrder.where((c) => map.containsKey(c)),
        if (map.containsKey('其他')) '其他',
      ];
      return [for (final k in keys) (k, map[k]!)];
    }
    final map = <String, List<ProbeTask>>{};
    for (final t in tcp) {
      final r = _splitTcpName(t.name).$1;
      map.putIfAbsent(r, () => []).add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        var ai =
            carrierOrder.indexWhere((c) => a.name.endsWith(c));
        var bi =
            carrierOrder.indexWhere((c) => b.name.endsWith(c));
        if (ai < 0) ai = 99;
        if (bi < 0) bi = 99;
        return ai.compareTo(bi);
      });
    }
    return map.entries.map((e) => (e.key, e.value)).toList();
  }

  String _tcpCell(ProbeNode n, int taskId) {
    NodeProbe? p;
    for (final e in n.nodeProbes) {
      if (e.taskId == taskId) {
        p = e;
        break;
      }
    }
    final lat = p?.latencyMs;
    if (lat == null) return '--';
    return '${lat.toStringAsFixed(1)}ms';
  }

  static String _mb(num b) =>
      b <= 0 ? '--' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  static String _gb(num b) => b <= 0
      ? '--'
      : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}G';
  static double _used(double? pct, int total) =>
      pct == null ? 0 : (pct / 100 * total);
}

class _CmpSeries {
  final String name;
  final List<double?> values;
  final Color color;
  _CmpSeries(this.name, this.values, this.color);
}
