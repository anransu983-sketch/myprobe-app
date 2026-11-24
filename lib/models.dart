/// 数据模型：与 MyProbe server.py 的 JSON 对齐

class ProbeNode {
  final String id;
  final String name;
  final String hostname;
  final String os;
  final String ip;
  final bool online;
  final double? cpu; // %
  final double? mem; // %
  final double? swap;
  final double? disk; // %
  final int? rx; // bytes/s
  final int? tx; // bytes/s
  final double? load1;
  final int? uptime; // s
  final int cpuCores;
  final int memTotal;
  final int diskTotal;
  final int? daysLeft;
  final String? expireDate;
  final String? buyDate;
  final double? price;
  final String? currency;
  final String? billCycle;
  final double monthRxGb;
  final double monthTxGb;
  final double quotaGb;
  final double quotaPct;
  final double quotaUsedGb;
  final int? quotaForecastDays; // v6.7：预计多少天后超额（null=不会超额）
  final String? quotaForecastDate;
  final double? remainValue; // v6.7：剩余价值
  // v6.7：IP 质量（服务端每小时查 ip-api.com）
  final String? ipCountry;
  final String? ipIsp;
  final String? ipAsn;
  final bool ipProxy;
  final bool ipHosting;
  final bool ipMobile;
  final int lastSeen;
  final bool hasIpv6; // v6.8：节点是否有全局 IPv6 出口（agent 上报）
  final String? sshHost;
  final int? sshPort;
  final String? sshUser;
  final bool sshReady;
  final List<NodeProbe> nodeProbes;
  // v1.17.9：服务端已返回 arch（x86_64 等）与 ip_quality_ts；
  // cpu_model 服务端库里有、node_latest 未返回，接口补上后自动亮起。
  final String? arch;
  final String? cpuModel;
  final int? ipQualityTs;

  ProbeNode({
    required this.id,
    required this.name,
    required this.hostname,
    required this.os,
    required this.ip,
    required this.online,
    this.cpu,
    this.mem,
    this.swap,
    this.disk,
    this.rx,
    this.tx,
    this.load1,
    this.uptime,
    this.cpuCores = 0,
    this.memTotal = 0,
    this.diskTotal = 0,
    this.daysLeft,
    this.expireDate,
    this.buyDate,
    this.price,
    this.currency,
    this.billCycle,
    this.monthRxGb = 0,
    this.monthTxGb = 0,
    this.quotaGb = 0,
    this.quotaPct = 0,
    this.quotaUsedGb = 0,
    this.quotaForecastDays,
    this.quotaForecastDate,
    this.remainValue,
    this.ipCountry,
    this.ipIsp,
    this.ipAsn,
    this.ipProxy = false,
    this.ipHosting = false,
    this.ipMobile = false,
    this.lastSeen = 0,
    this.hasIpv6 = false,
    this.sshHost,
    this.sshPort,
    this.sshUser,
    this.sshReady = false,
    this.nodeProbes = const [],
    this.arch,
    this.cpuModel,
    this.ipQualityTs,
  });

  static double? _d(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
  static int? _i(dynamic v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

  factory ProbeNode.fromJson(Map<String, dynamic> j) => ProbeNode(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        hostname: '${j['hostname'] ?? ''}',
        os: '${j['os'] ?? ''}',
        ip: '${j['ip'] ?? ''}',
        online: j['online'] == true,
        cpu: _d(j['cpu']),
        mem: _d(j['mem']),
        swap: _d(j['swap']),
        disk: _d(j['disk']),
        rx: _i(j['rx']),
        tx: _i(j['tx']),
        load1: _d(j['load1']),
        uptime: _i(j['uptime']),
        cpuCores: _i(j['cpu_cores']) ?? 0,
        memTotal: _i(j['mem_total']) ?? 0,
        diskTotal: _i(j['disk_total']) ?? 0,
        daysLeft: _i(j['days_left']),
        expireDate: j['expire_date']?.toString(),
        buyDate: j['buy_date']?.toString(),
        price: _d(j['price']),
        currency: j['currency']?.toString(),
        billCycle: j['bill_cycle']?.toString(),
        monthRxGb: _d(j['month_rx_gb']) ?? 0,
        monthTxGb: _d(j['month_tx_gb']) ?? 0,
        quotaGb: _d(j['quota_gb']) ?? 0,
        quotaPct: _d(j['quota_pct']) ?? 0,
        quotaUsedGb: _d(j['quota_used_gb']) ?? 0,
        quotaForecastDays: _i(j['quota_forecast_days']),
        quotaForecastDate: j['quota_forecast_date']?.toString(),
        remainValue: _d(j['remain_value']),
        ipCountry: j['ip_country']?.toString(),
        ipIsp: j['ip_isp']?.toString(),
        ipAsn: j['ip_asn']?.toString(),
        ipProxy: j['ip_proxy'] == true,
        ipHosting: j['ip_hosting'] == true,
        ipMobile: j['ip_mobile'] == true,
        ipQualityTs: _i(j['ip_quality_ts']),
        arch: j['arch']?.toString(),
        cpuModel: j['cpu_model']?.toString(),
        lastSeen: _i(j['last_seen']) ?? 0,
        hasIpv6: j['has_ipv6'] == true,
        sshHost: j['ssh_host']?.toString(),
        sshPort: _i(j['ssh_port']),
        sshUser: j['ssh_user']?.toString(),
        sshReady: j['ssh_ready'] == true,
        nodeProbes: ((j['probes'] as List?) ?? [])
            .map((e) =>
                NodeProbe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProbeBar {
  final int ts;
  final double? latency;
  final double? loss;
  final bool ok;
  ProbeBar(
      {required this.ts, this.latency, this.loss, required this.ok});
  factory ProbeBar.fromJson(Map<String, dynamic> j) => ProbeBar(
        ts: (j['ts'] is num) ? (j['ts'] as num).toInt() : 0,
        latency: j['latency'] == null
            ? null
            : (j['latency'] as num).toDouble(),
        loss:
            j['loss'] == null ? null : (j['loss'] as num).toDouble(),
        ok: j['ok'] == true,
      );
}

/// 单节点视角的拨测结果（/api/nodes 里 probes 字段）
class NodeProbe {
  final int taskId;
  final String name;
  final double? latencyMs;
  final double? lossPct;
  final int? ts;
  final List<bool> bars; // 是否可达历史，最老在前
  final List<double?> histLat;
  NodeProbe({
    required this.taskId,
    required this.name,
    this.latencyMs,
    this.lossPct,
    this.ts,
    this.bars = const [],
    this.histLat = const [],
  });
  factory NodeProbe.fromJson(Map<String, dynamic> j) => NodeProbe(
        taskId: (j['task_id'] as num?)?.toInt() ?? 0,
        name: '${j['name'] ?? ''}',
        latencyMs: j['latency_ms'] == null
            ? null
            : (j['latency_ms'] as num).toDouble(),
        lossPct: j['loss_pct'] == null
            ? null
            : (j['loss_pct'] as num).toDouble(),
        ts: (j['ts'] as num?)?.toInt(),
        bars: ((j['bars'] as List?) ?? [])
            .map((e) => e == 1 || e == true)
            .toList(),
        histLat: ((j['hist_lat'] as List?) ?? [])
            .map((e) =>
                e == null ? null : (e as num).toDouble())
            .toList(),
      );
}

class ProbeTask {
  final int id;
  final String name;
  final String type;
  final String host;
  final int? port;
  final String? path;
  final int interval;
  final bool enabled;
  final double? latency;
  final double? loss;
  final bool? ok;
  final int? lastTs;
  final List<ProbeBar> bars;

  ProbeTask({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    this.port,
    this.path,
    required this.interval,
    required this.enabled,
    this.latency,
    this.loss,
    this.ok,
    this.lastTs,
    this.bars = const [],
  });

  factory ProbeTask.fromJson(Map<String, dynamic> j) => ProbeTask(
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        type: '${j['type'] ?? ''}',
        host: '${j['host'] ?? ''}',
        port: j['port'] == null ? null : (j['port'] as num).toInt(),
        path: j['path']?.toString(),
        interval: (j['interval'] as num?)?.toInt() ?? 60,
        enabled: (j['enabled'] == 1 || j['enabled'] == true),
        latency: j['latency'] == null
            ? null
            : (j['latency'] as num).toDouble(),
        loss: j['loss'] == null ? null : (j['loss'] as num).toDouble(),
        ok: j['ok'] == null ? null : j['ok'] == true,
        lastTs: j['last_ts'] == null ? null : (j['last_ts'] as num).toInt(),
        bars: ((j['bars'] as List?) ?? [])
            .map((e) => ProbeBar.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get target {
    var t = host;
    if (type == 'tcp' && port != null) t += ':$port';
    if (type == 'http' && path != null && path!.isNotEmpty) t += path!;
    return t;
  }
}

class HistoryData {
  final List<int> ts; // ms
  final List<double?> cpu;
  final List<double?> mem;
  final List<double?> rx; // bytes/s
  final List<double?> tx;
  HistoryData(
      {required this.ts,
      required this.cpu,
      required this.mem,
      required this.rx,
      required this.tx});
  factory HistoryData.fromJson(Map<String, dynamic> j) {
    List<double?> dl(dynamic v) => ((v as List?) ?? [])
        .map((e) => e == null ? null : (e as num).toDouble())
        .toList();
    return HistoryData(
      ts: ((j['ts'] as List?) ?? []).map((e) => (e as num).toInt()).toList(),
      cpu: dl(j['cpu']),
      mem: dl(j['mem']),
      rx: dl(j['rx']),
      tx: dl(j['tx']),
    );
  }
}

String fmtSpeed(int? bps) {
  if (bps == null) return '--';
  if (bps < 1024) return '$bps B/s';
  if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
  return '${(bps / 1024 / 1024).toStringAsFixed(2)} MB/s';
}

String fmtUptime(int? s) {
  if (s == null) return '--';
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
  if (d > 0) return '$d 天 $h 小时';
  if (h > 0) return '$h 小时 $m 分';
  return '$m 分钟';
}

/// 流量单价：月均价 ÷ 月配额（年付先折到每月）。价格或配额缺失时返回 null，
/// 调用方不显示这一行（不显示 0，不造假）。
String? pricePerTb(ProbeNode n) {
  final price = n.price;
  final quota = n.quotaGb;
  if (price == null || price <= 0 || quota <= 0) return null;
  final monthly = n.billCycle == 'yearly' ? price / 12 : price;
  final perTb = monthly / (quota / 1024);
  final cur = n.currency ?? '¥';
  return '$cur${perTb.toStringAsFixed(2)}/TB';
}

/// 上次上报距今：优先节点 last_seen（秒），缺失时用本次拉取时间兜底
/// （即「刚刚更新」）。
String updatedAgoText(ProbeNode n) {
  if (n.lastSeen <= 0) return '刚刚更新';
  final diff =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 - n.lastSeen;
  if (diff < 5) return '刚刚更新';
  if (diff < 60) return '$diff 秒前更新';
  if (diff < 3600) return '${diff ~/ 60} 分钟前更新';
  return '${diff ~/ 3600} 小时前更新';
}

/// ip-api.com 的国家名 → 旗标 emoji；没映射到的不显示（不瞎猜）。
String? countryFlag(String? country) {
  const m = {
    'United States': '🇺🇸',
    'Hong Kong': '🇭🇰',
    'United Kingdom': '🇬🇧',
    'Singapore': '🇸🇬',
    'Germany': '🇩🇪',
    'Japan': '🇯🇵',
    'China': '🇨🇳',
    'South Korea': '🇰🇷',
    'Taiwan': '🇹🇼',
    'Canada': '🇨🇦',
    'Australia': '🇦🇺',
    'Netherlands': '🇳🇱',
    'France': '🇫🇷',
    'Russia': '🇷🇺',
    'India': '🇮🇳',
    'Brazil': '🇧🇷',
    'Turkey': '🇹🇷',
    'Vietnam': '🇻🇳',
    'Thailand': '🇹🇭',
    'Malaysia': '🇲🇾',
    'Indonesia': '🇮🇩',
    'Philippines': '🇵🇭',
    'Italy': '🇮🇹',
    'Spain': '🇪🇸',
    'Sweden': '🇸🇪',
    'Norway': '🇳🇴',
    'Finland': '🇫🇮',
    'Ireland': '🇮🇪',
    'Switzerland': '🇨🇭',
    'Austria': '🇦🇹',
    'Poland': '🇵🇱',
    'Ukraine': '🇺🇦',
    'South Africa': '🇿🇦',
    'Mexico': '🇲🇽',
    'New Zealand': '🇳🇿',
  };
  if (country == null) return null;
  return m[country.trim()];
}

/// 延迟分段色（养鸡场式 24 格条用）：<100 绿、100–200 黄、>200 红、无数据灰
int latencyCellColor(double? lat) {
  if (lat == null) return 0xFFB0B0B0; // 灰
  if (lat < 100) return 0xFF43A047; // 绿
  if (lat < 200) return 0xFFFFB300; // 黄
  return 0xFFE53935; // 红
}
