// 圣何塞节点（Vps-mvjxvzf1，38.59.249.99）的第三方快照数据。
// 来源 1：TcpQuality 报告 https://tcpquality.ibsgss.uk/r/rh6TJH05FM，
// 2026-11-24 15:47:53 CST，AS41378 Kirino，IP 38.59.*.*。
// 来源 2：融合怪（ecs）报告 https://paste.spiritlhl.net/#/show/Px640，
// 2026-11-24（与 TQ 同日）。
// 来源 3：NodeQuality 报告 https://nodequality.com/r/p8bYjrtcBUOleix9kw2e3SWfo6jZEJ2p，
// 2026-11-24 16:00–16:10 CST，AS41378 Kirino，IP 38.59.*.*，原生 IP。
// 只对圣何塞节点显示；其他节点这些表一律写 未测。数值是快照，不是
// 实时数据；MyProbe 自测（MTR/拨测）与快照不一致时，以 MyProbe 自测
// 为准——例如广东电信：TQ 与 NQ 均写 CN2GIA，MyProbe MTR 判回程未识别
// （跳点是 Zayo 中转 64.125.*，59.43/163 前缀全程不出现），
// MyProbe 自己的回程 pill 仍写 未识别，TQ/NQ 表只作对照。
// 11 月 19 日那份 93/93 100% 丢包的旧报告已作废，不再当现状。

/// 快照所属节点；其他节点不显示快照表。
const String tqSnapshotNodeId = 'Vps-mvjxvzf1';
const String tqSnapshotTime = '2026-11-24 15:47:53';
const String tqSnapshotUrl = 'https://tcpquality.ibsgss.uk/r/rh6TJH05FM';
const String ecsSnapshotUrl = 'https://paste.spiritlhl.net/#/show/Px640';

/// 31 省（大陆，不含港澳台），TQ 回程表口径。
const List<String> tqProvinces = [
  '广东',
  '浙江',
  '上海',
  '北京',
  '天津',
  '河北',
  '山西',
  '内蒙古',
  '辽宁',
  '吉林',
  '黑龙江',
  '江苏',
  '安徽',
  '福建',
  '江西',
  '山东',
  '河南',
  '湖北',
  '湖南',
  '广西',
  '海南',
  '重庆',
  '四川',
  '贵州',
  '云南',
  '西藏',
  '陕西',
  '甘肃',
  '青海',
  '宁夏',
  '新疆',
];

/// TQ IPv4 回程标签：电信全省 CN2GIA（仅贵州 163），联通全省
/// CN2GIA，移动全省 CMIN2。93/93 全部 0% 丢包。
String tqReturnLabel(String province, String carrier) {
  if (carrier == 'telecom') {
    return province == '贵州' ? '163' : 'CN2GIA';
  }
  if (carrier == 'unicom') return 'CN2GIA';
  return 'CMIN2';
}

/// TQ IPv4 回程延迟（ms）：只填报告摘录里给出的数，其余为 null。
/// 广东 166/165/179；浙江 135/146/143；上海 130/137/141；
/// 北京 150/160/164；西藏移动 230、青海移动 200、新疆移动 198。
const Map<String, Map<String, double>> tqReturnLatency = {
  '广东': {'telecom': 166, 'unicom': 165, 'mobile': 179},
  '浙江': {'telecom': 135, 'unicom': 146, 'mobile': 143},
  '上海': {'telecom': 130, 'unicom': 137, 'mobile': 141},
  '北京': {'telecom': 150, 'unicom': 160, 'mobile': 164},
  '西藏': {'mobile': 230},
  '青海': {'mobile': 200},
  '新疆': {'mobile': 198},
};

/// TQ 教育网回程：29 项零丢包，云南 4%，天津 28%（>20%）。
/// 延迟：广东 CTGGIA 173ms，浙江 144ms，上海 136ms。
/// 标签除广东 CTGGIA 外按表头口径为 CERNET。
const Map<String, double> tqEduLatency = {
  '广东': 173,
  '浙江': 144,
  '上海': 136,
};
const Map<String, double> tqEduLoss = {
  '云南': 4,
  '天津': 28,
};

/// TQ 国际互联（ms；两个数的为两次测量）。
const List<(String, double, double?)> tqIntl = [
  ('洛杉矶', 11, 12),
  ('达拉斯', 42, null),
  ('芝加哥', 48, null),
  ('香港', 162, 164),
  ('日本', 106, 110),
  ('新加坡', 170, 180),
  ('法兰克福', 143, 147),
  ('伦敦', 136, 131),
  ('悉尼', 146, 150),
];

/// TQ 单线程测速（回程重传%；回程速度 Mbps；去程速度 Mbps；
/// 回程延迟 ms；去程延迟 ms）。只填摘录里给出的数。
/// 广东电信 0.00%/563.4/146.2/210/173；广东联通 0.00%/495.9/50.9/
/// 190/190；广东移动 0.05%/438.6/96.1/212/208；北京电信 620.1/
/// 67.6；上海电信 666.6/7.0（仅速度）。
/// 国际 Apple IPv4：下载 1100.6Mbps，上传 1211.4Mbps，38/23ms。
/// TCP 参数：bbr，fq。
const List<({String target, double? retrans, double? down, double? up, double? rttDown, double? rttUp})>
    tqSpeedRows = [
  (
    target: '广东电信',
    retrans: 0.0,
    down: 563.4,
    up: 146.2,
    rttDown: 210,
    rttUp: 173,
  ),
  (
    target: '广东联通',
    retrans: 0.0,
    down: 495.9,
    up: 50.9,
    rttDown: 190,
    rttUp: 190,
  ),
  (
    target: '广东移动',
    retrans: 0.05,
    down: 438.6,
    up: 96.1,
    rttDown: 212,
    rttUp: 208,
  ),
  (
    target: '北京电信',
    retrans: null,
    down: 620.1,
    up: 67.6,
    rttDown: null,
    rttUp: null,
  ),
  (
    target: '上海电信',
    retrans: null,
    down: 666.6,
    up: 7.0,
    rttDown: null,
    rttUp: null,
  ),
];

/// 融合怪报告（2026-11-24）：单核 3287 分（基准项目未在摘录中注明，
/// 不归入 Geekbench/Sysbench 任一档）；内存读 38965 MB/s、写
/// 23071 MB/s；fio 4k 读写合计 90.15 MB/s（读/写分项未摘录）；
/// Speedtest 上行 185.51 Mbps、下行 258.83 Mbps。
const double ecsSingleCore = 3287;
const double ecsMemRead = 38965;
const double ecsMemWrite = 23071;
const double ecsFio4kTotal = 90.15;
const double ecsSpeedtestUp = 185.51;
const double ecsSpeedtestDown = 258.83;

// ---------------- NodeQuality 报告（来源 3）----------------
// https://nodequality.com/r/p8bYjrtcBUOleix9kw2e3SWfo6jZEJ2p
// 2026-11-24 16:00–16:10 CST，AS41378 Kirino，38.59.*.*，原生 IP。
const String nqSnapshotTime = '2026-11-24 16:00–16:10';
const String nqSnapshotUrl =
    'https://nodequality.com/r/p8bYjrtcBUOleix9kw2e3SWfo6jZEJ2p';

/// 硬件：KVM，Debian 12，内核 6.1.0-44-cloud-amd64，1 核 AMD EPYC，
/// NQ 只给出频率 2449.998MHz，未给精确型号——型号仍以服务端接口为准。
const String nqCpuLine = '1核 AMD EPYC · 2449.998MHz';
const String nqVirtOs = 'KVM · Debian 12 · 内核 6.1.0-44-cloud-amd64';
const double nqGb5Single = 965;
const double nqGb5Multi = 943;
const double nqSysbenchSingle = 3207.56; // 单线程，NQ 未给多线程分
const double nqMemRead = 42299.6; // Sysbench MB/s
const double nqMemWrite = 24193.3;
const double nqMemLatencyNs = 165;
const double nqMemTotalMb = 973; // 已用 353MB，36%
const double nqDiskTotalGb = 15; // 已用 2.7G，18%
const double nqFioRnd4kRead = 27.2; // MB/s，7.0k IOPS
const double nqFioRnd4kReadIops = 7.0;
const double nqFioRnd4kWrite = 43.2; // MB/s，11k IOPS
const double nqFioRnd4kWriteIops = 11;
const double nqFioSeq1mRead = 1034; // MB/s
const double nqFioSeq1mWrite = 1029;
const double nqHqScore = 23583; // CPU 13430 + 内存 8680 + 硬盘 1473
const String nqHqRank = '排名总 3.2%';

/// IP 质量：五库均判机房，均为低风险。DBIP 未在 NQ 摘录中出现。
const List<(String, String)> nqRiskScores = [
  ('IP2LOCATION', '3'),
  ('SCAMALYTICS', '0'),
  ('ipapi', '0.02%'),
  ('AbuseIPDB', '0'),
];

/// NQ 解锁（服务 / 结果 / 地区定性）。与 MyProbe 本站解锁检测的
/// 测试集不同，各自为准，不合并。
const List<(String, String, String)> nqUnlock = [
  ('TikTok', '解锁', 'US 原生'),
  ('Disney+', '解锁', 'HK 原生'),
  ('Netflix', '解锁', 'HK DNS'),
  ('YouTube', '解锁', 'US 原生'),
  ('Amazon Prime Video', '解锁', 'US 原生'),
  ('Reddit', '阻断', ''),
  ('ChatGPT', '解锁', 'US 原生'),
];

/// 邮件能力：TCP 25 出站可用；DNSBL 423 有效、418 正常、3 已标记、
/// 2 黑名单；收件可达与不可达邮箱。
const int nqDnsblTotal = 423;
const int nqDnsblOk = 418;
const int nqDnsblMarked = 3;
const int nqDnsblListed = 2;
const List<String> nqMailReachable = [
  'Gmail',
  'Outlook',
  'Yahoo',
  'Apple',
  'QQ',
  'MailRU',
];
const List<String> nqMailBlocked = [
  'AOL',
  'GMX',
  'MailCOM',
  '163',
  'Sohu',
  'Sina',
];

/// 定位库对照：BGP 注册与 MaxMind 不一致，两边都记，不只取一个。
const String nqBgpRegistry = 'ARIN';
const String nqBgpOrg = 'HK CEDOC LIMITED';
const String nqBgpRegion = 'HK';
const String nqBgpAddress =
    'Room 2008, 20/F, Landmark North, 39 Lung Sum Ave';
const String nqBgpRegistered = '2024-07-25';
const String nqMaxmindNote = '美国注册/使用（与 BGP 的 HK 注册不一致）';

/// 网络：无 NAT；TCP 参数 bbr/fq（与 TQ 一致）。
/// 三网 TCP 大包延迟全国普遍 128–185ms，最低上海电信 128ms、浙江
/// 电信 129ms；偏高：山西电信 291ms、山西联通 348ms、西藏移动 212ms。
const String nqTcpLargeNote =
    '三网 TCP 大包延迟全国普遍 128–185ms，最低上海电信 128ms、浙江电信 129ms；偏高：山西电信 291ms、山西联通 348ms、西藏移动 212ms。';

/// 国内测速 6 节点发送与接收全部 ERROR（非速度数）。
const List<String> nqDomesticSpeedNodes = [
  '杭州电信',
  '宁波电信',
  '上海联通',
  '香港联通',
  '苏州移动',
  '深圳移动',
];

/// NQ 国际互连（城市 / 延迟 ms / 下行 Mbps / 上行 Mbps；速度为 null
/// 表示该方向 ERROR）。纽约延迟 66ms 但发送/接收 ERROR；圣保罗
/// 172ms，速度 ERROR。
const List<(String, double, double?, double?)> nqIntlSpeed = [
  ('洛杉矶', 11, 1254, 1107),
  ('东京', 104, 1180, 853),
  ('香港', 161, 789, 739),
  ('伦敦', 131, 1005, 843),
  ('法兰克福', 151, 138, 107),
  ('纽约', 66, null, null),
  ('圣保罗', 172, null, null),
];

/// NQ 回程路由（NextTrace）：北京/上海/广东三网，电信与联通
/// CN2GIA、移动 CMIN2。只作对照——广东电信这里写 CN2GIA，但
/// MyProbe 自测是回程未识别，详情页仍以自测为准。
const List<(String, String, String, String)> nqNextTrace = [
  ('广东电信', 'CN2GIA', 'AS4809 → AS4134 → AS58466', '约 160–174ms'),
  ('广东联通', 'CN2GIA', 'AS4809 → AS4134 → AS17816 → AS136958',
      '约 161–166ms'),
  ('广东移动', 'CMIN2', 'AS58807 → AS9808 → AS56040', '约 138–175ms'),
  ('上海电信', 'CN2GIA', 'AS4809 → AS4812', '约 123–126ms'),
  ('上海移动', 'CMIN2', 'AS58807 → AS9808 → AS24400 → AS9808',
      '约 138–141ms'),
];
