// 回程/去程线路判定（TcpQuality 同款前缀规则，见 workspace/tq-clean/
// runTcpQuality-core.sh 的 route_label_from_ip_trace；无 ASN 数据，
// 只看跳点里的公网 IPv4）。回程 MTR 与手机 tracepath 粘贴共用，
// 方向无关——只看跳点里出现过谁的骨干前缀。
// 电信：只剩 59.43.* 且无 163 跳 = CN2GIA；59.43 与 163 混走 = CN2GT；
// 只有 163 跳 = 163。联通：210.14/210.51/210.78/218.105 = 9929，
// 否则 219.158 = 4837，再否则 103.214./162.219.3x 等 = 10099
// （PickMyVPS 的 去 10099 就是它）。移动：223.120/223.119 = CMIN2，
// 否则 221.183/111.24/111.13 = CMNET。
// 注意：跳点里没有这些前缀就判不出（英国 9929 电信实测：跳点是 Zayo
// 中转 64.125.* + 几跳不回包，59.43/163 全程不出现），此时返回 null，
// 调用方写“回程未识别”，不瞎猜——中转 IP 不是骨干网，不能拿它当线路名。

/// MTR 跳点 → 线路名：先从 host 里提 IP，再按前缀判定。
String? routeLabelFromHops(
    String target, List<Map<String, dynamic>> hops) {
  final ips = <String>[];
  final ipRe = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
  for (final h in hops) {
    final m = ipRe.firstMatch('${h['host'] ?? ''}');
    if (m != null) ips.add(m.group(0)!);
  }
  return labelFromIps(target, ips);
}

/// 跳点 IP 列表 → 线路名；判不出返回 null。
String? labelFromIps(String target, List<String> ips) {
  bool has(List<String> pres) =>
      ips.any((ip) => pres.any((p) => ip.startsWith(p)));
  switch (target) {
    case 'telecom':
      final cn2 = has(['59.43.']);
      final v163 = has([
        '202.97.',
        '202.96.',
        '219.141.',
        '219.142.',
        '106.37.'
      ]);
      if (cn2 && !v163) return 'CN2GIA';
      if (cn2 && v163) return 'CN2GT';
      if (v163) return '163';
      return null;
    case 'unicom':
      if (has(['210.14.', '210.51.', '210.78.', '218.105.'])) {
        return '9929';
      }
      if (has(['219.158.'])) return '4837';
      if (has([
        '103.214.',
        '103.228.68.',
        '103.239.176.',
        '118.26.151.',
        '162.219.3',
        '162.219.85.',
        '162.245.124.',
        '202.77.23.',
        '203.160.66.',
        '203.160.75.'
      ])) {
        return '10099';
      }
      return null;
    case 'mobile':
      if (has(['223.120.', '223.119.'])) return 'CMIN2';
      if (has(['221.183.', '111.24.', '111.13.'])) return 'CMNET';
      return null;
  }
  return null;
}
