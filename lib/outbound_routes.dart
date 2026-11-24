// 去程线路录入（本机存）：App 无 root 跑不了 traceroute，去程名只能由
// 用户在 Termux 里跑 ~/go-route.sh 后把跳点粘进来，按同一套前缀规则
// （route_labels.dart）识别后存本机 SharedPreferences；一次只测当前
// 这张卡（移动/电信切卡重测重录），联通/教育没卡就一直是 未测，不编数。
// 详情页线路卡与套餐与规格子页共用。
import 'package:flutter/material.dart';
import 'package:myprobe_app/route_labels.dart';
import 'package:myprobe_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 读本机已存的去程线路：(labels, dates)，没录入的运营商不进 map。
Future<({Map<String, String> labels, Map<String, String> dates})>
    loadOutRoutes(String nodeId) async {
  final p = await SharedPreferences.getInstance();
  final labels = <String, String>{};
  final dates = <String, String>{};
  for (final t in ['telecom', 'unicom', 'mobile']) {
    final raw = p.getString('mp_out_route_${nodeId}_$t');
    if (raw == null || raw.isEmpty) continue;
    final parts = raw.split('|');
    labels[t] = parts.first;
    if (parts.length > 1) dates[t] = parts[1];
  }
  return (labels: labels, dates: dates);
}

class OutRouteChange {
  /// true = 清除了已存
  final bool cleared;
  final String? label;
  final String? date;
  const OutRouteChange(
      {this.cleared = false, this.label, this.date});
}

/// 弹出录入对话框并把结果写进本机：返回 null = 取消/没保存；
/// cleared = 清除了已存；否则 label+date 为新存的值。
/// 识别不出骨干前缀时弹提示、不保存。
Future<OutRouteChange?> recordOutboundRoute(
  BuildContext context, {
  required String nodeId,
  required String carrier,
  required String carrierName,
  required String nodeIp,
  required String? savedLabel,
  required String? savedDate,
}) async {
  final ctrl = TextEditingController();
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('去程线路 · $carrierName'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '手机 Termux 里先关代理，再跑 bash ~/go-route.sh $nodeIp，把跳点输出整段粘进来，按跳点前缀识别线路名。一次只测当前这张卡，换卡重测重录。',
              style: TextStyle(fontSize: 13, color: BocchiTheme.ink),
            ),
            if (savedLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                  '已存：$carrierName 去 $savedLabel${savedDate == null ? '' : '（$savedDate）'}',
                  style: TextStyle(
                      fontSize: 12.5, color: BocchiTheme.inkSoft)),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '粘贴 tracepath 跳点…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (savedLabel != null)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('__clear__'),
            child: const Text('清除已存'),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: const Text('识别并保存'),
        ),
      ],
    ),
  );
  if (choice == null) return null;
  final p = await SharedPreferences.getInstance();
  final key = 'mp_out_route_${nodeId}_$carrier';
  if (choice == '__clear__') {
    await p.remove(key);
    return const OutRouteChange(cleared: true);
  }
  final ipRe = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
  final ips =
      ipRe.allMatches(choice).map((m) => m.group(0)!).toList();
  final label = labelFromIps(carrier, ips);
  if (label == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('跳点里没有可识别的骨干前缀，未保存')),
      );
    }
    return null;
  }
  final now = DateTime.now();
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  await p.setString(key, '$label|$date');
  return OutRouteChange(label: label, date: date);
}
