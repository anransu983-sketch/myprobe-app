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
  final int lastSeen;
  final String? sshHost;
  final int? sshPort;
  final String? sshUser;
  final bool sshReady;
  final List<NodeProbe> nodeProbes;

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
    this.lastSeen = 0,
    this.sshHost,
    this.sshPort,
    this.sshUser,
    this.sshReady = false,
    this.nodeProbes = const [],
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
        lastSeen: _i(j['last_seen']) ?? 0,
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
