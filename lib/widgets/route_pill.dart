// PickMyVPS 式线路 pill：回=青底白字（已识别才填色），去=灰框；
// 没测出的写 未识别/未测，绝不编一个名顶替。去 pill 可点，录入手机
// tracepath 实测跳点。
import 'package:flutter/material.dart';
import 'package:myprobe_app/theme.dart';

class RoutePill extends StatelessWidget {
  final String dir;
  final String? label;
  final VoidCallback? onTap;
  const RoutePill(this.dir, this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final known = label != null;
    final filled = dir == '回' && known;
    final text =
        '$dir ${known ? label : (dir == '回' ? '未识别' : '未测')}';
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF1F9E8E) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: filled
              ? const Color(0xFF1F9E8E)
              : BocchiTheme.inkSoft.withValues(alpha: 0.4),
        ),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : BocchiTheme.inkSoft)),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: pill,
    );
  }
}
