// 线路变化记录（v1.17.10，本机存）：每次进详情页拉到 MTR 后，把当次
// 三网回程线路名（telecom/unicom/mobile，可为 null=未识别）与上次
// 存的快照比一次；有变化就追加一条 {date, telecom, unicom, mobile}，
// 无变化不写。记录始于第一次进页的日期，之后翻转都留痕——例如联通
// 4837 ↔ 未识别来回变，在这里能看到是哪天变的。
// 只记标签变化，不记跳点明细；去程（tracepath 录入）不进这张表。
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RouteSnapshot {
  final String date; // yyyy-MM-dd
  final Map<String, String?> labels; // telecom/unicom/mobile → 线路名或 null
  const RouteSnapshot({required this.date, required this.labels});

  Map<String, dynamic> toJson() => {
        'date': date,
        'telecom': labels['telecom'],
        'unicom': labels['unicom'],
        'mobile': labels['mobile'],
      };

  factory RouteSnapshot.fromJson(Map<String, dynamic> j) => RouteSnapshot(
        date: '${j['date'] ?? ''}',
        labels: {
          'telecom': j['telecom'] as String?,
          'unicom': j['unicom'] as String?,
          'mobile': j['mobile'] as String?,
        },
      );
}

String _key(String nodeId) => 'mp_route_hist_$nodeId';

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// 读本机线路变化记录（最老在前）。
Future<List<RouteSnapshot>> loadRouteHistory(String nodeId) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(_key(nodeId));
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(RouteSnapshot.fromJson).toList();
  } catch (_) {
    return const [];
  }
}

bool _sameLabels(Map<String, String?> a, Map<String, String?> b) {
  for (final k in ['telecom', 'unicom', 'mobile']) {
    if (a[k] != b[k]) return false;
  }
  return true;
}

/// 记录一次回程标签快照：与上一条比，无变化不写；有变化追加一条。
/// 返回追加后的完整记录（调用方直接拿去显示，不用再读一次）。
Future<List<RouteSnapshot>> recordRouteSnapshot(
    String nodeId, Map<String, String?> labels) async {
  final hist = await loadRouteHistory(nodeId);
  if (hist.isNotEmpty && _sameLabels(hist.last.labels, labels)) {
    return hist;
  }
  final next = [...hist, RouteSnapshot(date: _today(), labels: labels)];
  // 只留最近 60 条，防无限增长
  final trimmed = next.length > 60 ? next.sublist(next.length - 60) : next;
  final p = await SharedPreferences.getInstance();
  await p.setString(
      _key(nodeId), jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  return trimmed;
}
