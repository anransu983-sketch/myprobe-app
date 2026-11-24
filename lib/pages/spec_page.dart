// 套餐与规格子页（PickMyVPS 式网格）：价格 / 流量单价 / 流量 / 端口
// 带宽 / CPU / 内存 / 硬盘 / 三网回去 pill / 到期 / 余值 / 商家官网。
// 只有已有的数据才列：同系列 SKU 无核实数据，不列；端口带宽
// agent 未测，写 未测；CPU 型号取服务端 node_latest 的 cpu_model，
// 未返回时写（型号未上报），频率绝不冒充型号；去 pill 可点，录入
// 手机 tracepath 实测（与详情页线路卡同一份本机存储）。
import 'package:flutter/material.dart';
import 'package:myprobe_app/merchant.dart';
import 'package:myprobe_app/models.dart';
import 'package:myprobe_app/outbound_routes.dart';
import 'package:myprobe_app/probe_stats.dart';
import 'package:myprobe_app/route_labels.dart';
import 'package:myprobe_app/theme.dart';
import 'package:myprobe_app/tq_snapshot.dart';
import 'package:myprobe_app/widgets/node_card.dart';
import 'package:myprobe_app/widgets/route_pill.dart';
import 'package:myprobe_app/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class SpecBody extends StatefulWidget {
  final ProbeNode node;
  final Map<String, dynamic> mtr;
  const SpecBody({super.key, required this.node, required this.mtr});
  @override
  State<SpecBody> createState() => _SpecPageState();
}

class _SpecPageState extends State<SpecBody> {
  Map<String, String> _outLabels = {};
  Map<String, String> _outDates = {};

  @override
  void initState() {
    super.initState();
    _reloadOut();
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

  List<Map<String, dynamic>> _hops(String carrier) {
    final m = widget.mtr[carrier];
    if (m is! Map<String, dynamic>) return const [];
    return ((m['hops'] as List?) ?? []).cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final price = (n.price ?? 0) > 0
        ? '${n.currency ?? '¥'}${n.price!.toStringAsFixed(n.price! % 1 == 0 ? 0 : 2)} ${n.billCycle == 'yearly' ? '年付' : '月付'}'
        : '未填';
    final perTb = pricePerTb(n) ?? '未测';
    final quota = n.quotaGb > 0
        ? '${n.quotaGb.toStringAsFixed(n.quotaGb % 1 == 0 ? 0 : 1)}GB · 双向'
        : '未填';
    // CPU：型号取服务端 node_latest 的 cpu_model；未返回时不写核数
    // 顶替——圣何塞写「AMD EPYC（型号未上报）· 2449.998MHz」，频率
    // 不是型号，括号里写清楚；其他节点只写核数 +（型号未上报）。
    final cores = n.cpuCores > 0 ? '${n.cpuCores}核 · ' : '';
    final cpu = n.cpuModel != null && n.cpuModel!.isNotEmpty
        ? '$cores${n.cpuModel}'
        : n.id == tqSnapshotNodeId
            ? '${cores}AMD EPYC（型号未上报）· $nqCpuFreqMhz'
            : n.cpuCores > 0
                ? '${n.cpuCores}核（型号未上报）'
                : '未测';
    final mem =
        n.memTotal > 0 ? PhoneNodeCard.mb(n.memTotal) : '未测';
    final disk =
        n.diskTotal > 0 ? PhoneNodeCard.gb(n.diskTotal) : '未测';
    final expire = (n.expireDate ?? '').isNotEmpty
        ? '${n.expireDate}${n.daysLeft == null ? '' : '（余 ${n.daysLeft} 天）'}'
        : '未填';
    final remain = n.remainValue != null
        ? '${n.currency ?? '¥'}${n.remainValue!.toStringAsFixed(2)}'
        : '未填';
    return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _gridRow([
                    _cell('价格', price, big: true),
                    _cell('流量单价', perTb, big: true),
                  ]),
                  _gridRow([
                    _cell('流量', quota, big: true),
                    _cell('端口带宽', '未测', big: true),
                  ]),
                  _gridRow([_cell('CPU', cpu, big: true)], full: true),
                  _gridRow([
                    _cell('内存', mem, big: true),
                    _cell('硬盘', disk, big: true),
                  ]),
                  _gridRow([
                    _routeCell('电信', 'telecom'),
                    _routeCell('联通', 'unicom'),
                  ]),
                  _gridRow([
                    _routeCell('移动', 'mobile'),
                    _cell('教育', '未测', big: true),
                  ]),
                  _gridRow([
                    _cell('到期', expire),
                    _cell('余值', remain),
                  ]),
                  _gridRow([_merchantCell()], full: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '同系列 SKU：无数据，未列出（未收录商家产品页，不编）。端口带宽：agent 未测。',
            style:
                TextStyle(fontSize: 12, color: BocchiTheme.inkSoft),
          ),
        ],
    );
  }

  /// 商家官网行：只有核实过官网域名的商家给链接；只核实了商家名
  /// 没核实域名的写「官网未核实」；节点未关联商家的写未登记。
  Widget _merchantCell() {
    final m = merchantOf(widget.node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('商家官网',
            style:
                TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft)),
        const SizedBox(height: 4),
        if (m == null)
          Text('未登记',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BocchiTheme.ink))
        else if (m.site == null)
          Text('${m.name}（官网未核实）',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BocchiTheme.ink))
        else
          InkWell(
            onTap: () async {
              final uri = Uri.parse(m.site!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Text('${m.name} · ${m.site}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.pinkDeep,
                    decoration: TextDecoration.underline)),
          ),
      ],
    );
  }

  Widget _cell(String label, String value, {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: big ? 18 : 14,
                fontWeight: FontWeight.w700,
                color: BocchiTheme.ink)),
      ],
    );
  }

  Widget _routeCell(String name, String carrier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style:
                TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft)),
        const SizedBox(height: 6),
        Row(
          children: [
            RoutePill(
                '回', routeLabelFromHops(carrier, _hops(carrier))),
            const SizedBox(width: 6),
            RoutePill('去', _outLabels[carrier],
                onTap: () => _record(carrier)),
          ],
        ),
      ],
    );
  }

  Widget _gridRow(List<Widget> cells, {bool full = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: full
          ? cells.first
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cells[0]),
                if (cells.length > 1)
                  Expanded(child: cells[1]),
              ],
            ),
    );
  }
}
