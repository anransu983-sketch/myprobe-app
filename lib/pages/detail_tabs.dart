// 详情页标签页 bodies：测速 / 国际 / BGP / IP 质量 / 性能。
// 与概览页共用同一份已取数据（node、unlock），缺失项写 未测，不编数。
// 第三方快照（TQ 单线程测速、国际互联、融合怪跑分、NQ 硬件/IP/网络）
// 只对圣何塞节点显示，并标明来源与时间；其他节点一律 未测。
import 'package:flutter/material.dart';
import 'package:myprobe_app/models.dart';
import 'package:myprobe_app/probe_stats.dart';
import 'package:myprobe_app/theme.dart';
import 'package:myprobe_app/tq_snapshot.dart';
import 'package:myprobe_app/widgets/node_card.dart';
import 'package:myprobe_app/widgets/widgets.dart';

String _fmtTs(int? ts) {
  if (ts == null) return '未测';
  final ms = ts > 1000000000000 ? ts : ts * 1000;
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

Widget _secTitle(String t) => Text(t,
    style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: BocchiTheme.ink));

Widget _muted(String t) => Text(t,
    style: TextStyle(fontSize: 12.5, color: BocchiTheme.inkSoft));

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(k,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: BocchiTheme.ink)),
        ),
        Expanded(
          child: Text(v,
              style: TextStyle(fontSize: 13.5, color: BocchiTheme.ink)),
        ),
      ],
    ),
  );
}

Widget _unmeasured(String what) => Text('未测 · $what',
    style: TextStyle(fontSize: 13, color: BocchiTheme.inkSoft));

/// 分段选择器（Geekbench/Sysbench/内存/磁盘、24h/7d/30d 等共用）。
Widget _segTabs(List<(String, String)> options, String current,
    void Function(String) onPick) {
  return Container(
    decoration: BoxDecoration(
      color: BocchiTheme.inkSoft.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        for (final o in options)
          Expanded(
            child: InkWell(
              onTap: () => onPick(o.$1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: current == o.$1
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(o.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: current == o.$1
                            ? BocchiTheme.ink
                            : BocchiTheme.inkSoft)),
              ),
            ),
          ),
      ],
    ),
  );
}

// ---------------- 测速 ----------------

/// 测速标签页：单线程测速卡（无多线程）。MyProbe agent 无测速能力；
/// 表里是 TQ 2026-11-24 快照（圣何塞），其他节点 未测。
class SpeedBody extends StatelessWidget {
  final ProbeNode node;
  const SpeedBody({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final isSj = node.id == tqSnapshotNodeId;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('单线程测速'),
                const SizedBox(height: 4),
                _muted(isSj
                    ? 'TcpQuality 快照 $tqSnapshotTime · 无多线程'
                    : '本节点暂无测速快照'),
                const SizedBox(height: 10),
                if (!isSj)
                  _unmeasured('agent 无测速能力，本节点也无 TQ 快照')
                else ...[
                  Row(
                    children: [
                      const Expanded(
                          flex: 2, child: SizedBox(width: 0)),
                      for (final h in ['回程', '去程', '回程延迟', '去程延迟'])
                        Expanded(
                          child: Text(h,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: BocchiTheme.inkSoft)),
                        ),
                      const SizedBox(
                          width: 44,
                          child: Text('重传',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey))),
                    ],
                  ),
                  const Divider(height: 12),
                  for (final r in tqSpeedRows) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(r.target,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: BocchiTheme.ink)),
                        ),
                        for (final v in [r.down, r.up])
                          Expanded(
                            child: Text(
                                v == null
                                    ? '—'
                                    : '${v.toStringAsFixed(1)} Mbps',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: BocchiTheme.ink)),
                          ),
                        for (final v in [r.rttDown, r.rttUp])
                          Expanded(
                            child: Text(
                                v == null
                                    ? '—'
                                    : '${v.toStringAsFixed(0)}ms',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: BocchiTheme.ink)),
                          ),
                        SizedBox(
                          width: 44,
                          child: Text(
                              r.retrans == null
                                  ? '—'
                                  : '${r.retrans!.toStringAsFixed(2)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: BocchiTheme.ink)),
                        ),
                      ],
                    ),
                    if (r != tqSpeedRows.last)
                      const Divider(height: 12),
                  ],
                  const SizedBox(height: 10),
                  _muted(
                      '北京/上海联通、移动行：TQ 摘录未给出，不编。TQ 单线程测速每方向只给一个速度值，无每秒速度/最大列。'),
                  _kv('国际 Apple IPv4',
                      '下载 1100.6 Mbps，上传 1211.4 Mbps，38/23ms'),
                  _kv('TCP 参数', 'bbr，fq'),
                  _kv('NAT', '无（NQ 2026-11-24）'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('Speedtest（融合怪）'),
                const SizedBox(height: 8),
                if (!isSj)
                  _unmeasured('只有圣何塞节点有 2026-11-24 融合怪报告')
                else
                  _kv('上行 / 下行',
                      '$ecsSpeedtestUp Mbps / $ecsSpeedtestDown Mbps'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('国内测速（NQ）'),
                const SizedBox(height: 8),
                if (!isSj)
                  _unmeasured('只有圣何塞节点有 2026-11-24 NQ 报告')
                else ...[
                  _muted(
                      '以下 6 个节点发送与接收全部 ERROR（非速度数）：'),
                  const SizedBox(height: 6),
                  for (final t in nqDomesticSpeedNodes)
                    _kv(t, '发送 ERROR / 接收 ERROR'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _muted('测速数据为第三方快照，非 MyProbe 实测；MyProbe agent 无测速能力。'),
      ],
    );
  }
}

// ---------------- 国际 ----------------

/// 国际标签页：4 张子卡。国际延迟有 AWS 东京实测（MyProbe 拨测）+
/// TQ 国际互联快照（圣何塞）；其余三张 未测。
class IntlBody extends StatelessWidget {
  final ProbeNode node;
  const IntlBody({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    NodeProbe? tokyo;
    for (final p in node.nodeProbes) {
      if (p.name == 'AWS东京') {
        tokyo = p;
        break;
      }
    }
    final isSj = node.id == tqSnapshotNodeId;
    final last10 = tokyo == null
        ? <double>[]
        : tokyo.histLat
            .whereType<double>()
            .toList()
            .reversed
            .take(10)
            .toList()
            .reversed
            .toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('国际延迟'),
                const SizedBox(height: 8),
                if (tokyo == null)
                  _unmeasured('AWS 东京拨测任务未建出（需服务端 v6.9）')
                else ...[
                  _kv('AWS 东京最新',
                      '${tokyo.latencyMs?.toStringAsFixed(0) ?? '--'} ms'),
                  _kv(
                      '中位',
                      '${medianOf(tokyo.histLat.isNotEmpty ? tokyo.histLat : [tokyo.latencyMs])?.toStringAsFixed(0) ?? '--'} ms（近 22 次采样）'),
                  _kv('目标',
                      'ec2.ap-northeast-1.amazonaws.com:443 · TCP'),
                  if (last10.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('最近 10 次握手',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final v in last10)
                          Expanded(
                            child: Container(
                              height: 22,
                              margin:
                                  const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: v < 100
                                    ? BocchiTheme.okGreen
                                    : v < 200
                                        ? const Color(0xFFE8A33D)
                                        : const Color(0xFFE5484D),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Center(
                                child: Text(
                                    v.toStringAsFixed(0),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
                if (isSj) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text('国际互联（TQ 快照 2026-11-24）',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final c in tqIntl)
                    _kv(c.$1,
                        c.$3 == null ? '${c.$2.toStringAsFixed(0)}ms' : '${c.$2.toStringAsFixed(0)}/${c.$3!.toStringAsFixed(0)}ms'),
                  _muted('常用网站全部可达、0% 重传。'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('常见 IDC 延迟'),
                const SizedBox(height: 8),
                _unmeasured('需对 14 家 IDC 的多城 TCP 握手探测，MyProbe 无此任务'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('运营商延迟'),
                const SizedBox(height: 8),
                _unmeasured('需运营商多城延迟探测，MyProbe 无此任务'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('国际测速'),
                const SizedBox(height: 8),
                if (!isSj)
                  _unmeasured('MyProbe 无国际测速数据')
                else ...[
                  _muted('NodeQuality $nqSnapshotTime · 下行/上行 Mbps'),
                  const SizedBox(height: 8),
                  for (final r in nqIntlSpeed)
                    _kv(
                        '${r.$1}（${r.$2.toStringAsFixed(0)}ms）',
                        r.$3 == null
                            ? '发送/接收 ERROR'
                            : '↓${r.$3!.toStringAsFixed(0)} / ↑${r.$4!.toStringAsFixed(0)} Mbps'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- BGP ----------------

/// BGP 标签页：只有 AS/ISP/国家是 MyProbe 数据；传播图、上游变动、
/// 观测详情、直连对等、RPKI 均需 RIPE RIS/RouteViews，未接入，写 未测。
class BgpBody extends StatelessWidget {
  final ProbeNode node;
  const BgpBody({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final asn = node.ipAsn == null
        ? null
        : RegExp(r'AS\d+').firstMatch(node.ipAsn!)?.group(0);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('全球 BGP 路径快照'),
                const SizedBox(height: 8),
                _kv('源 AS', asn ?? '未测'),
                if (node.ipAsn != null) _kv('完整 AS', node.ipAsn!),
                if (node.ipIsp != null) _kv('组织', node.ipIsp!),
                if (node.ipCountry != null)
                  _kv('国家/地区', node.ipCountry!),
                _kv('IP', node.ip),
                const SizedBox(height: 8),
                _unmeasured(
                    '传播图：需 RIPE RIS/RouteViews 的 AS 路径数据，未接入；接入后才能画传播图、中转/Tier 1 列表'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('上游变动'),
                const SizedBox(height: 8),
                _unmeasured('无变动记录 · 未接 BGP 观测源（需 RIPE RIS/RouteViews 接入后才有变动历史）'),
                const SizedBox(height: 12),
                _secTitle('观测详情'),
                const SizedBox(height: 8),
                _unmeasured('采集器 / 对等观测点 / 直连对等：未接观测源（需 RIPE RIS/RouteViews）'),
                const SizedBox(height: 12),
                _secTitle('RPKI'),
                const SizedBox(height: 8),
                _unmeasured('未校验 · 需 RPKI 数据源，未接入'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _muted('公开 BGP 观测点在采集时刻的路径快照需 RIPE RIS/RouteViews 接入，MyProbe 目前只有 ip-api 的 AS 归属。'),
      ],
    );
  }
}

// ---------------- IP 质量 ----------------

/// IP 质量标签页：最新报告时间/风险/原生/ASN/组织是 MyProbe 数据；
/// 媒体解锁是 MyProbe 解锁检测结果；风险评分、邮件能力、定位库对照、
/// IP 段来历：圣何塞节点用 NQ 2026-11-24 快照填，其他节点写 未测。
/// 本地服务、平台认定、变化记录均无数据，写 未测。
class IpBody extends StatelessWidget {
  final ProbeNode node;
  final List<Map<String, dynamic>> unlock;
  final Map<String, String> unlockNames;
  const IpBody(
      {super.key,
      required this.node,
      required this.unlock,
      required this.unlockNames});

  @override
  Widget build(BuildContext context) {
    final n = node;
    final hasIp =
        n.ipCountry != null || n.ipIsp != null || n.ipAsn != null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('最新报告'),
                const SizedBox(height: 8),
                _kv('报告时间', _fmtTs(n.ipQualityTs)),
                _kv('风险', n.ipProxy ? '高风险' : '低风险'),
                _kv('数据源', 'ip-api（1 家）'),
                if (n.id == tqSnapshotNodeId)
                  _kv('NodeQuality 报告', '$nqSnapshotTime · 低风险'),
                if (hasIp) ...[
                  _kv('类型', n.ipProxy ? '代理 IP' : '原生 IP'),
                  _kv('IP 版本', n.hasIpv6 ? 'IPv4 + IPv6' : 'IPv4'),
                  if (n.ipCountry != null)
                    _kv('注册地 / 实际位置', n.ipCountry!),
                  if (n.ipAsn != null) _kv('ASN', n.ipAsn!),
                  if (n.ipIsp != null) _kv('组织', n.ipIsp!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('风险评分'),
                const SizedBox(height: 8),
                if (n.id == tqSnapshotNodeId) ...[
                  for (final s in nqRiskScores) _kv(s.$1, s.$2),
                  _kv('DBIP', '未测（NQ 摘录未给）'),
                  const SizedBox(height: 6),
                  _muted('五库均判机房，均为低风险（NQ $nqSnapshotTime）。'),
                ] else
                  _unmeasured('IP2LOCATION / SCAMALYTICS / ipapi / AbuseIPDB / DBIP：未接评分源'),
                const SizedBox(height: 12),
                _secTitle('风险因子'),
                const SizedBox(height: 8),
                _kv('代理', n.ipProxy ? '标记' : '未标记'),
                _kv('服务器', n.ipHosting ? '标记' : '未标记'),
                _kv('Tor', '未测'),
                _kv('VPN', '未测'),
                _kv('滥用', '未测'),
                _kv('机器人', '未测'),
                const SizedBox(height: 6),
                _muted('后四项需多源风险因子数据，MyProbe 只有 ip-api 的代理/机房标记。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('媒体解锁'),
                const SizedBox(height: 8),
                if (unlock.isEmpty)
                  _unmeasured('解锁检测暂无结果')
                else
                  for (final u in unlock)
                    _kv(
                        unlockNames['${u['service']}'] ??
                            '${u['service']}',
                        u['ok'] == true ? '解锁' : '阻断'),
                if (n.id == tqSnapshotNodeId) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text('NodeQuality 解锁（2026-11-24）',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final u in nqUnlock)
                    _kv(u.$1,
                        u.$3.isEmpty ? u.$2 : '${u.$2}（${u.$3}）'),
                  _muted('NQ 与本站检测的测试集不同，各自为准，不合并。'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('本地服务'),
                const SizedBox(height: 8),
                _unmeasured('需本地服务解锁检测（ViuTV / myTV SUPER / Viu 等），MyProbe 不测'),
                const SizedBox(height: 12),
                _secTitle('平台认定地区'),
                const SizedBox(height: 8),
                _unmeasured('需平台认定地区检测（OneTrust / iQIYI / Bing 等），MyProbe 不测'),
                const SizedBox(height: 12),
                _secTitle('邮件能力'),
                const SizedBox(height: 8),
                if (n.id == tqSnapshotNodeId) ...[
                  _kv('TCP 25 出站', '可用'),
                  _kv('DNSBL',
                      '总数 $nqDnsblTotal · 正常 $nqDnsblOk · 已标记 $nqDnsblMarked · 黑名单 $nqDnsblListed'),
                  _kv('收件可达', nqMailReachable.join(' / ')),
                  _kv('收件不可达', nqMailBlocked.join(' / ')),
                  _muted('NodeQuality $nqSnapshotTime。'),
                ] else
                  _unmeasured('TCP 25 / DNSBL / 各邮箱收件：未测'),
                const SizedBox(height: 12),
                _secTitle('IP 类型属性'),
                const SizedBox(height: 8),
                _kv('使用类型', n.ipHosting ? '机房' : '未测'),
                if (n.id == tqSnapshotNodeId)
                  _muted('NQ 五库均判机房。'),
                _kv('公司类型', '未测（NQ 未给公司类型）'),
                const SizedBox(height: 12),
                _secTitle('定位库对照'),
                const SizedBox(height: 8),
                if (n.id == tqSnapshotNodeId) ...[
                  _kv('BGP 注册',
                      '$nqBgpRegistry · $nqBgpOrg · 地区 $nqBgpRegion'),
                  _kv('BGP 注册地址', nqBgpAddress),
                  _kv('BGP 注册时间', nqBgpRegistered),
                  _kv('MaxMind 等', nqMaxmindNote),
                  _muted('两个来源不一致，都记下来，不只取一个。'),
                ] else
                  _unmeasured('多家定位库对照：未接'),
                const SizedBox(height: 12),
                _secTitle('IP 段来历'),
                const SizedBox(height: 8),
                if (n.id == tqSnapshotNodeId) ...[
                  _kv('登记持有人', '$nqBgpOrg · 香港'),
                  _kv('宣告方', 'AS41378 Kirino'),
                  _kv('注册时间', nqBgpRegistered),
                  _kv('关系', '未测（NQ 未给出与登记持有人的关系：租用/自有）'),
                  _kv('首次宣告', '未测（NQ 未给出）'),
                ] else
                  _unmeasured('登记持有人 / 宣告方 / 首次宣告：未接数据'),
                const SizedBox(height: 12),
                _secTitle('变化记录'),
                const SizedBox(height: 8),
                _unmeasured('暂无变化记录 · 只有 2026-11-24 一次 NQ 快照，无历史可比'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- 性能 ----------------

/// 性能标签页：基准测试（Geekbench 5 / Sysbench / 内存 / 磁盘四档）
/// + 30 天趋势 + CPU steal + iowait。
/// 跑分数据：圣何塞节点用 NQ 2026-11-24 快照（GB5 单核 965/多核
/// 943、Sysbench 单线程 3207.56、内存 Sysbench 读/写、fio RND4K/
/// SEQ1M、HQ 评分 23583）填进对应档；融合怪同日快照（内存读/写、
/// fio 4k 合计、单核 3287 分基准项目未注明）并列标注来源，不合并。
/// CPU 型号：NQ 只给频率，精确型号仍需服务端接口。CPU steal/
/// iowait：agent 未采集，写 未测。其他节点一律 未测。
class PerfBody extends StatefulWidget {
  final ProbeNode node;
  const PerfBody({super.key, required this.node});
  @override
  State<PerfBody> createState() => _PerfBodyState();
}

class _PerfBodyState extends State<PerfBody> {
  String _bench = 'gb5'; // gb5 | sysbench | mem | disk
  String _stealRange = '7d'; // 24h | 7d | 30d
  String _iowaitRange = '7d';
  String _diskBlock = '4k'; // 4k | 64k | 512k | 1m

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final isSj = n.id == tqSnapshotNodeId;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('基准测试'),
                const SizedBox(height: 4),
                _muted('最近 30 天趋势'),
                const SizedBox(height: 10),
                _kv(
                    'CPU 型号',
                    (n.cpuModel != null && n.cpuModel!.isNotEmpty)
                        ? n.cpuModel!
                        : (isSj
                            ? 'AMD EPYC（型号未上报）· $nqCpuFreqMhz（NQ；频率不是型号）'
                            : '未测')),
                _kv('架构', n.arch ?? '未测'),
                _kv('核心数', n.cpuCores > 0 ? '${n.cpuCores}核' : '未测'),
                _kv('内存',
                    n.memTotal > 0 ? PhoneNodeCard.mb(n.memTotal) : '未测'),
                _kv('硬盘',
                    n.diskTotal > 0 ? PhoneNodeCard.gb(n.diskTotal) : '未测'),
                if (isSj) ...[
                  _kv('虚拟化 / 系统', nqVirtOs),
                  _kv('内存已用', '353MB（36% · NQ）'),
                  _kv('硬盘已用', '2.7G（18% · NQ）'),
                ],
                if (n.cpuModel == null || n.cpuModel!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _muted('CPU 型号：服务端 v6.11 起在 node_latest 里返回 cpu_model（需升级服务端）；未升级前显示（型号未上报）。'),
                  ),
                const SizedBox(height: 12),
                _segTabs([
                  ('gb5', 'Geekbench 5'),
                  ('sysbench', 'Sysbench'),
                  ('mem', '内存'),
                  ('disk', '磁盘'),
                ], _bench, (v) => setState(() => _bench = v)),
                const SizedBox(height: 12),
                if (_bench == 'gb5') ...[
                  if (!isSj) ...[
                    _kv('单核', '未测'),
                    _kv('多核', '未测'),
                    const SizedBox(height: 6),
                    _muted('无 Geekbench 数据。'),
                  ] else ...[
                    _kv('单核', '$nqGb5Single（NQ 2026-11-24）'),
                    _kv('多核', '$nqGb5Multi（NQ 2026-11-24）'),
                  ],
                ] else if (_bench == 'sysbench') ...[
                  if (!isSj) ...[
                    _kv('单核', '未测'),
                    _kv('多核', '未测'),
                    const SizedBox(height: 6),
                    _muted('无 Sysbench 数据。'),
                  ] else ...[
                    _kv('单核', '$nqSysbenchSingle/s（NQ 2026-11-24）'),
                    _kv('多核', '未测（NQ 只给单线程）'),
                  ],
                ] else if (_bench == 'mem') ...[
                  if (!isSj) ...[
                    _kv('读', '未测'),
                    _kv('写', '未测'),
                  ] else ...[
                    _kv('读', '$nqMemRead MB/s（Sysbench · NQ）'),
                    _kv('写', '$nqMemWrite MB/s（Sysbench · NQ）'),
                    _kv('延迟', '$nqMemLatencyNs ns（NQ）'),
                    const SizedBox(height: 6),
                    _kv('读', '$ecsMemRead MB/s（融合怪 2026-11-24）'),
                    _kv('写', '$ecsMemWrite MB/s（融合怪 2026-11-24）'),
                    _muted('两个工具的内存读/写数不同，各自标注来源，不合并。'),
                  ],
                ] else ...[
                  _segTabs([
                    ('4k', '4k'),
                    ('64k', '64k'),
                    ('512k', '512k'),
                    ('1m', '1m'),
                  ], _diskBlock,
                      (v) => setState(() => _diskBlock = v)),
                  const SizedBox(height: 10),
                  if (_diskBlock == '4k' && isSj) ...[
                    _kv('读',
                        '$nqFioRnd4kRead MB/s / ${nqFioRnd4kReadIops}k IOPS（fio RND4K/Q1 · NQ）'),
                    _kv('写',
                        '$nqFioRnd4kWrite MB/s / ${nqFioRnd4kWriteIops}k IOPS（fio RND4K/Q1 · NQ）'),
                    _kv('读写合计', '$ecsFio4kTotal MB/s（融合怪 2026-11-24）'),
                  ] else if (_diskBlock == '1m' && isSj) ...[
                    _kv('读', '$nqFioSeq1mRead MB/s（fio SEQ1M/Q8 · NQ）'),
                    _kv('写', '$nqFioSeq1mWrite MB/s（fio SEQ1M/Q8 · NQ）'),
                  ] else if ((_diskBlock == '64k' ||
                          _diskBlock == '512k') &&
                      isSj) ...[
                    _kv('读', '未测'),
                    _kv('写', '未测'),
                    const SizedBox(height: 6),
                    _muted('NQ 报告只给了 4k Q1 与 1M Q8，未给 64k/512k。'),
                  ] else ...[
                    _kv('读', '未测'),
                    _kv('写', '未测'),
                    _kv('读写', '未测'),
                  ],
                ],
                const SizedBox(height: 10),
                if (isSj) ...[
                  _kv('融合怪单核',
                      '$ecsSingleCore 分（2026-11-24；基准项目未注明，不归入以上四档）'),
                  _kv('硬件评分（NQ）',
                      '$nqHqScore 分（CPU 13430 + 内存 8680 + 硬盘 1473），$nqHqRank'),
                ],
                const SizedBox(height: 6),
                _secTitle('30 天趋势'),
                const SizedBox(height: 6),
                _unmeasured(
                    '无历史跑分数据 · 跑分是 2026-11-24 的一次快照，需多次跑分才能画趋势，不画假线'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('CPU steal'),
                const SizedBox(height: 4),
                _muted('虚拟机要用 CPU 时被宿主机占去的时间比例'),
                const SizedBox(height: 10),
                _segTabs([
                  ('24h', '24h'),
                  ('7d', '7d'),
                  ('30d', '30d'),
                ], _stealRange,
                    (v) => setState(() => _stealRange = v)),
                const SizedBox(height: 10),
                if (n.cpuSteal != null) ...[
                  _kv('最新',
                      '${n.cpuSteal!.toStringAsFixed(1)}%（agent 已上报）'),
                  _kv('均值 / P95 / 峰值', '未测'),
                  const SizedBox(height: 6),
                  _muted('均值/P95/峰值需 history 接口返回 steal 序列，未接；最新值来自服务端 v6.11 + agent 6.9 上报。'),
                ] else ...[
                  _kv('均值', '未测'),
                  _kv('P95', '未测'),
                  _kv('峰值', '未测'),
                  const SizedBox(height: 6),
                  _muted('agent 未上报 steal（需服务端 v6.11 + agent 6.9：metrics 表加 cpu_steal 列）。'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('iowait'),
                const SizedBox(height: 10),
                _segTabs([
                  ('24h', '24h'),
                  ('7d', '7d'),
                  ('30d', '30d'),
                ], _iowaitRange,
                    (v) => setState(() => _iowaitRange = v)),
                const SizedBox(height: 10),
                if (n.cpuIowait != null) ...[
                  _kv('最新',
                      '${n.cpuIowait!.toStringAsFixed(1)}%（agent 已上报）'),
                  _kv('均值 / P95 / 峰值', '未测'),
                  const SizedBox(height: 6),
                  _muted('均值/P95/峰值需 history 接口返回 iowait 序列，未接；最新值来自服务端 v6.11 + agent 6.9 上报。'),
                ] else ...[
                  _kv('均值', '未测'),
                  _kv('P95', '未测'),
                  _kv('峰值', '未测'),
                  const SizedBox(height: 6),
                  _muted('agent 未上报 iowait（需服务端 v6.11 + agent 6.9：metrics 表加 cpu_iowait 列）。'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
