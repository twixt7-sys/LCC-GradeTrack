import '../models/models.dart';
import 'grade_calculator.dart';

enum TargetStatus {
  /// The target holds even with 0% on remaining work.
  secured,

  /// Reachable with at least [TargetResult.neededPercent] on remaining work.
  needs,

  /// Not reachable even with 100% on remaining work.
  unreachable,

  /// No remaining work: the grade is complete.
  complete,
}

class TargetResult {
  const TargetResult(
    this.status, {
    this.neededPercent,
    required this.targetMinPercent,
  });
  final TargetStatus status;
  final double? neededPercent;
  final double targetMinPercent;
}

/// Finds the minimum percent needed on all remaining work to reach a target
/// equivalent. Solves by bisection on the projected subject percent.
class TargetSolver {
  const TargetSolver(this.calculator);
  final GradeCalculator calculator;

  TargetResult solve({
    required Subject subject,
    required List<GradeComponent> components,
    required List<Score> scores,
    required GradeScale scale,
    required double targetEquivalent,
  }) {
    final targetMin =
        scale.minPercentFor(targetEquivalent) ?? scale.passingPercent;
    final componentIds = components.map((c) => c.id).toSet();
    final relevant = scores
        .where((s) => componentIds.contains(s.componentId))
        .toList();

    final hasRemaining =
        relevant.any((s) => s.isUpcoming) ||
        components.any(
          (c) => !relevant.any((s) => s.componentId == c.id && !s.isUpcoming),
        );
    if (!hasRemaining) {
      return TargetResult(TargetStatus.complete, targetMinPercent: targetMin);
    }

    bool reaches(double x) {
      final p = calculator.projectedPercent(
        subject: subject,
        components: components,
        scores: relevant,
        assumed: x,
      );
      return calculator.rounding.apply(p) >= targetMin - 1e-9;
    }

    if (reaches(0))
      return TargetResult(TargetStatus.secured, targetMinPercent: targetMin);
    if (!reaches(100))
      return TargetResult(
        TargetStatus.unreachable,
        targetMinPercent: targetMin,
      );

    var lo = 0.0;
    var hi = 100.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (reaches(mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    // Round up to 2 dp so the shown value is always sufficient.
    final needed = (hi * 100).ceilToDouble() / 100;
    return TargetResult(
      TargetStatus.needs,
      neededPercent: needed,
      targetMinPercent: targetMin,
    );
  }
}
