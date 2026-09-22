import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Card with a heading, used to group one idea per block.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.card,
        border: Border.all(color: AppColors.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ?trailing,
              ],
            ),
            Gap.h12,
          ],
          child,
        ],
      ),
    );
  }
}

/// A labelled number. Values use tabular figures so columns line up.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Gap.h4,
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            fontFeatures: tabularFigures,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Small rounded chip.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.color = AppColors.textSecondary,
    this.background,
    this.icon,
    this.dense = false,
  });

  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.13),
        borderRadius: Radii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular gauge for the discipline score.
///
/// Deliberately the biggest number on the home screen. Profit gets a small row
/// underneath it — that ordering is the whole design argument of the app.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.grade,
    this.size = 116,
  });

  /// 0–100.
  final double score;
  final String grade;
  final double size;

  Color get _color {
    if (score >= 75) return AppColors.discipline;
    if (score >= 50) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: _RingPainter(
                progress: (score / 100).clamp(0.0, 1.0),
                color: _color,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1,
                  fontFeatures: tabularFigures,
                  color: _color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                grade,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.elevated
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Equity curve as a filled sparkline.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 56,
    this.color,
  });

  final List<double> values;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }
    final rising = values.last >= values.first;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color ?? (rising ? AppColors.profit : AppColors.loss),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      min = math.min(min, v);
      max = math.max(max, v);
    }
    // A flat curve would divide by zero; give it a nominal span so it renders
    // as a straight line through the middle.
    final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;

    final step = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height - (values[i] - min) / span * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

/// Formats a signed money amount, always with its sign.
String money(double value, {int decimals = 2}) {
  final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
  return '$sign\$${value.abs().toStringAsFixed(decimals)}';
}

/// Formats an R-multiple, e.g. `+2.3R`.
String rMultiple(double value) {
  final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
  return '$sign${value.abs().toStringAsFixed(2)}R';
}

/// Relative time in Bengali, e.g. "৩ ঘণ্টা আগে".
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'এইমাত্র';
  if (diff.inMinutes < 60) return '${diff.inMinutes} মিনিট আগে';
  if (diff.inHours < 24) return '${diff.inHours} ঘণ্টা আগে';
  if (diff.inDays < 30) return '${diff.inDays} দিন আগে';
  return '${(diff.inDays / 30).floor()} মাস আগে';
}
