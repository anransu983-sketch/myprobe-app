import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';

/// 拨测 30 条历史小柱状图
class MiniBars extends StatelessWidget {
  final List<ProbeBar> bars;
  final double height;
  const MiniBars({super.key, required this.bars, this.height = 34});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _BarsPainter(bars)),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<ProbeBar> bars;
  _BarsPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) {
      final p = Paint()..color = Colors.grey.shade300;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, size.height / 2 - 1, size.width, 2),
              const Radius.circular(1)),
          p);
      return;
    }
    double maxLat = 1;
    for (final b in bars) {
      if (b.latency != null && b.latency! > maxLat) maxLat = b.latency!;
    }
    final n = bars.length;
    final gap = 2.0;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final h = b.ok && b.latency != null
          ? (4 + (size.height - 4) * (b.latency! / maxLat)).clamp(4.0, size.height)
          : 4.0;
      final x = i * (w + gap);
      final paint = Paint()
        ..color = b.ok ? BocchiTheme.okGreen : BocchiTheme.warnRed;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, w < 1 ? 1 : w, h),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.bars.length != bars.length;
}

/// 百分比横条（CPU/内存/硬盘用）
class MetricBar extends StatelessWidget {
  final String label;
  final double? pct;
  final String? right;
  const MetricBar(
      {super.key, required this.label, required this.pct, this.right});

  Color get _c {
    final v = pct ?? 0;
    if (v >= 90) return BocchiTheme.warnRed;
    if (v >= 70) return Colors.orange;
    return BocchiTheme.pinkDeep;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 44,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: BocchiTheme.inkSoft))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ((pct ?? 0) / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: BocchiTheme.pinkLight,
                valueColor: AlwaysStoppedAnimation(_c),
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              right ?? (pct == null ? '--' : '${pct!.toStringAsFixed(1)}%'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: BocchiTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// 在线状态圆点
class OnlineDot extends StatelessWidget {
  final bool online;
  const OnlineDot({super.key, required this.online});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? BocchiTheme.okGreen : Colors.grey,
        boxShadow: online
            ? [
                BoxShadow(
                    color: BocchiTheme.okGreen.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1)
              ]
            : null,
      ),
    );
  }
}

/// 网页版风格：全粉小柱（延迟条），失败为浅灰粉
class PinkBars extends StatelessWidget {
  final List<double?> latencies; // null/<=0 视为失败
  final List<bool>? oks;
  final double height;
  const PinkBars(
      {super.key, required this.latencies, this.oks, this.height = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
          painter: _PinkBarsPainter(latencies, oks)),
    );
  }
}

class _PinkBarsPainter extends CustomPainter {
  final List<double?> latencies;
  final List<bool>? oks;
  _PinkBarsPainter(this.latencies, this.oks);

  @override
  void paint(Canvas canvas, Size size) {
    if (latencies.isEmpty) {
      final p = Paint()..color = BocchiTheme.pinkLight;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, size.height / 2 - 1, size.width, 2),
              const Radius.circular(1)),
          p);
      return;
    }
    double maxLat = 1;
    for (var i = 0; i < latencies.length; i++) {
      final ok = oks == null || i >= oks!.length || oks![i];
      final l = latencies[i];
      if (ok && l != null && l > maxLat) maxLat = l;
    }
    final n = latencies.length;
    final gap = 2.0;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final ok = oks == null || i >= oks!.length || oks![i];
      final l = latencies[i];
      final good = ok && l != null && l > 0;
      final h = good
          ? (4 + (size.height - 4) * (l / maxLat))
              .clamp(4.0, size.height)
          : 4.0;
      final x = i * (w + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, w < 1 ? 1 : w, h),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color =
              good ? BocchiTheme.pinkDeep : BocchiTheme.pinkLight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PinkBarsPainter old) => true;
}

/// 网页版风格渐变标题栏（粉→深粉）
class GradientAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double fontSize;
  const GradientAppBar(
      {super.key,
      required this.title,
      this.actions,
      this.leading,
      this.fontSize = 20});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: fontSize)),
      centerTitle: true,
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF06292), BocchiTheme.pinkDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

/// 网页版风格指标格：图标+标签 … 右对齐粗体值 / 粉条 / 小字说明
class WebMetric extends StatelessWidget {
  final String icon;
  final String label;
  final double? pct;
  final String value;
  final String caption;
  const WebMetric(
      {super.key,
      required this.icon,
      required this.label,
      required this.pct,
      required this.value,
      required this.caption});

  @override
  Widget build(BuildContext context) {
    final v = (pct ?? 0).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: BocchiTheme.inkSoft)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BocchiTheme.ink)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: v / 100,
            minHeight: 7,
            backgroundColor: BocchiTheme.pinkLight,
            valueColor: const AlwaysStoppedAnimation(
                BocchiTheme.pinkDeep),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(caption,
                style: const TextStyle(
                    fontSize: 11,
                    color: BocchiTheme.inkSoft)),
          ),
      ],
    );
  }
}

/// 网页版风格小统计盒（两行粉字 + 灰小字标题）
class WebStatBox extends StatelessWidget {
  final String line1;
  final String line2;
  const WebStatBox(
      {super.key, required this.line1, required this.line2});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: BocchiTheme.pinkLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(line1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BocchiTheme.pinkDeep,
                  height: 1.4)),
          const SizedBox(height: 2),
          Text(line2,
              style: const TextStyle(
                  fontSize: 10,
                  color: BocchiTheme.inkSoft)),
        ],
      ),
    );
  }
}

/// 粉色小胶囊
class PinkPill extends StatelessWidget {
  final String text;
  final bool dim;
  const PinkPill({super.key, required this.text, this.dim = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dim
            ? BocchiTheme.pinkLight.withValues(alpha: 0.6)
            : BocchiTheme.pinkLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BocchiTheme.pinkDeep)),
    );
  }
}
