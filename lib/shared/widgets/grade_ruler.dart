import 'package:lcc_gradetrack/ui.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Horizontal 1.00 → 3.00 ruler (plus a separate 5.00 fail stop) with a
/// marker at [value]. Replaces the usual progress ring on the GWA hero.
class GradeRuler extends StatelessWidget {
  const GradeRuler({
    super.key,
    required this.value,
    required this.scale,
    this.height = 46,
  });

  final double? value;
  final GradeScale scale;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return Semantics(
      label: value == null
          ? 'No GWA yet'
          : 'GWA ${value!.toStringAsFixed(2)} on a 1.00 to 5.00 scale',
      child: TweenAnimationBuilder<double?>(
        tween: Tween(begin: value, end: value),
        duration: Gt.med,
        builder: (context, v, _) => CustomPaint(
          size: Size.fromHeight(height),
          painter: _RulerPainter(
            value: value,
            steps: [for (final r in scale.sorted().rows) r.equivalent]..sort(),
            fail: scale.failingEquivalent,
            line: c.hairline,
            tick: c.muted,
            label: c.muted,
            marker: c.text,
            fill: c.primary,
            failColor: c.red,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.value,
    required this.steps,
    required this.fail,
    required this.line,
    required this.tick,
    required this.label,
    required this.marker,
    required this.fill,
    required this.failColor,
  });

  final double? value;
  final List<double> steps;
  final double fail;
  final Color line, tick, label, marker, fill, failColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;
    const failGap = 0.14; // share of width reserved for the 5.00 stop
    final mainW = size.width * (1 - failGap);
    final lo = steps.first;
    final hi = steps.last;
    double xOf(double g) {
      if (g > hi + 1e-9) return size.width - 1;
      return hi == lo ? 0 : (g - lo) / (hi - lo) * (mainW - 1);
    }

    const baseY = 18.0;
    final p = Paint()
      ..color = line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, baseY), Offset(mainW - 1, baseY), p);
    // Dashed gap to the fail stop.
    final dash = Paint()
      ..color = line
      ..strokeWidth = 2;
    for (var x = mainW + 6; x < size.width - 8; x += 6) {
      canvas.drawLine(Offset(x, baseY), Offset(x + 2, baseY), dash);
    }

    // Filled segment from 1.00 to the value (better grades are on the left).
    if (value != null && value! <= hi + 1e-9) {
      canvas.drawLine(
        const Offset(0, baseY),
        Offset(xOf(value!), baseY),
        Paint()
          ..color = fill
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    final tp = Paint()
      ..color = tick
      ..strokeWidth = 1.2;
    void labelAt(String text, double x, {Color? color, bool bold = false}) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: mono(
            10,
            weight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? label,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - t.width / 2).clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(dx, baseY + 10));
    }

    for (final s in steps) {
      final major = (s - s.roundToDouble()).abs() < 1e-9;
      final x = xOf(s);
      canvas.drawLine(
        Offset(x, baseY - (major ? 7 : 4)),
        Offset(x, baseY + (major ? 7 : 4)),
        tp,
      );
      if (major) labelAt(s.toStringAsFixed(2), x);
    }
    final fx = size.width - 1;
    canvas.drawLine(
      Offset(fx, baseY - 7),
      Offset(fx, baseY + 7),
      Paint()
        ..color = failColor
        ..strokeWidth = 1.6,
    );
    labelAt(fail.toStringAsFixed(2), fx, color: failColor, bold: true);

    // Marker: downward triangle above the line.
    if (value != null) {
      final x = xOf(value!).clamp(5.0, size.width - 5);
      final path = Path()
        ..moveTo(x - 5, baseY - 14)
        ..lineTo(x + 5, baseY - 14)
        ..lineTo(x, baseY - 6)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = value! > hi + 1e-9 ? failColor : marker,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.value != value ||
      old.marker != marker ||
      old.line != line ||
      old.steps.length != steps.length;
}
