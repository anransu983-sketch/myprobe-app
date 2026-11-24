// 拨测数据的小统计（中位/均值/抖动），详情页、持续监测页共用。
// 所有函数只算已有数据：空列表返回 null，调用方写 未测/--，不编数。
import 'dart:math' as math;

import 'package:myprobe_app/models.dart';

/// 三网运营商键 → 中文名（与 node_detail_page 的 _ispNames 同口径）。
const Map<String, String> ispNames = {
  'telecom': '电信',
  'unicom': '联通',
  'mobile': '移动',
};

/// 中位数；空返回 null。
double? medianOf(Iterable<double?> values) {
  final vs = values.whereType<double>().toList()..sort();
  if (vs.isEmpty) return null;
  final n = vs.length;
  if (n.isOdd) return vs[n ~/ 2];
  return (vs[n ~/ 2 - 1] + vs[n ~/ 2]) / 2;
}

/// 均值；空返回 null。
double? meanOf(Iterable<double?> values) {
  final vs = values.whereType<double>().toList();
  if (vs.isEmpty) return null;
  return vs.reduce((a, b) => a + b) / vs.length;
}

/// 抖动 = 总体标准差（与 PickMyVPS 的 Jitter 同口径：同一批采样的离散度）；
/// 空或只有 1 个点返回 null。
double? stddevOf(Iterable<double?> values) {
  final vs = values.whereType<double>().toList();
  if (vs.length < 2) return null;
  final m = vs.reduce((a, b) => a + b) / vs.length;
  var sum = 0.0;
  for (final v in vs) {
    sum += (v - m) * (v - m);
  }
  return math.sqrt(sum / vs.length);
}

/// 某地区某运营商的拨测行（探针名以运营商结尾，如“广东移动”）。
NodeProbe? probeForRegionCarrier(
    List<NodeProbe> probes, String region, String carrierName) {
  for (final p in probes) {
    if (p.name == '$region$carrierName' ||
        (p.name.startsWith(region) && p.name.endsWith(carrierName))) {
      return p;
    }
  }
  return null;
}

/// 某地区三网中位延迟（运营商键 → 中位 ms；没数据的运营商不进 map）。
/// 中位取 histLat（近 22 次采样），histLat 为空时退回最新 latencyMs。
Map<String, double> medianLatencyByRegion(
    List<NodeProbe> probes, String region) {
  final out = <String, double>{};
  for (final entry in ispNames.entries) {
    final p = probeForRegionCarrier(probes, region, entry.value);
    if (p == null) continue;
    final med = medianOf(p.histLat.isNotEmpty ? p.histLat : [p.latencyMs]);
    if (med != null) out[entry.key] = med;
  }
  return out;
}
