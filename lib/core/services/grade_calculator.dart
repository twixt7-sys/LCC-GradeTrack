import 'package:collection/collection.dart';

import '../models/models.dart';

/// How the subject percent is rounded before it is converted with the scale.
enum RoundingRule {
  none('none', 'No rounding'),
  twoDecimals('2dp', '2 decimal places'),
  whole('whole', 'Nearest whole number');

  const RoundingRule(this.code, this.label);
  final String code;
  final String label;
  static RoundingRule fromCode(String? c) => RoundingRule.values.firstWhere(
    (r) => r.code == c,
    orElse: () => twoDecimals,
  );

  double apply(double v) => switch (this) {
    none => v,
    twoDecimals => (v * 100).roundToDouble() / 100,
    whole => v.roundToDouble(),
  };
}

/// Standing bands on the 1.00–5.00 scale. Always shown with a text label.
enum Standing {
  strong('Strong'),
  onTrack('On track'),
  atRisk('At risk'),
  failing('Failing'),
  none('No grade');

  const Standing(this.label);
  final String label;

  static Standing of(double? equivalent) {
    if (equivalent == null) return none;
    if (equivalent <= 1.75 + 1e-9) return strong;
    if (equivalent <= 2.50 + 1e-9) return onTrack;
    if (equivalent <= 3.00 + 1e-9) return atRisk;
    return failing;
  }
}

class ComponentResult {
  const ComponentResult({
    required this.component,
    required this.average,
    required this.gradedCount,
    required this.upcomingCount,
  });

  final GradeComponent component;

  /// Component average in percent, null when nothing is graded.
  final double? average;
  final int gradedCount;
  final int upcomingCount;

  /// Weighted points contributed to the subject grade (avg × weight / 100).
  double? get points =>
      average == null ? null : average! * component.weight / 100;
}

class SubjectResult {
  const SubjectResult({
    required this.subject,
    required this.components,
    required this.percent,
    required this.equivalent,
    required this.gradedWeight,
    required this.totalWeight,
    required this.isFinal,
  });

  final Subject subject;
  final List<ComponentResult> components;

  /// Current subject percent, normalized over graded weight. Null if nothing graded.
  final double? percent;

  /// 1.00–5.00 equivalent; null when no grade or a final mark (INC/DRP/W) is set.
  final double? equivalent;

  /// Sum of weights of components with at least one graded item.
  final double gradedWeight;
  final double totalWeight;

  /// True when [equivalent] comes from the registrar's final grade.
  final bool isFinal;

  FinalMark? get mark => subject.finalMark;
  Standing get standing =>
      mark != null ? Standing.none : Standing.of(equivalent);
  bool get inProgress =>
      !isFinal && mark == null && gradedWeight < totalWeight - 1e-9;

  /// Share of the grade that is already graded, 0–100.
  double get gradedShare =>
      totalWeight <= 0 ? 0 : gradedWeight / totalWeight * 100;

  /// Subject counts in GWA only with a numeric grade and no mark.
  bool get countsInGwa =>
      subject.countsInGwa && mark == null && equivalent != null;
}

/// Computes component averages, subject percent and equivalents.
class GradeCalculator {
  const GradeCalculator({this.rounding = RoundingRule.twoDecimals});

  final RoundingRule rounding;

  static double? componentAverage(Iterable<Score> scores, AvgMethod method) {
    final graded = scores.where((s) => !s.isUpcoming && s.total > 0).toList();
    if (graded.isEmpty) return null;
    return switch (method) {
      AvgMethod.meanPercent => graded.map((s) => s.percent!).average,
      AvgMethod.totalPoints =>
        graded.map((s) => s.score!).sum / graded.map((s) => s.total).sum * 100,
    };
  }

  /// Looks up the equivalent for [percent] in [scale] after rounding.
  double equivalentFor(double percent, GradeScale scale) {
    final p = rounding.apply(percent);
    for (final r in scale.sorted().rows) {
      if (p >= r.minPercent - 1e-9) return r.equivalent;
    }
    return scale.failingEquivalent;
  }

  SubjectResult compute({
    required Subject subject,
    required List<GradeComponent> components,
    required List<Score> scores,
    required GradeScale scale,
  }) {
    final byComponent = groupBy(scores, (Score s) => s.componentId);
    final results = <ComponentResult>[];
    var weighted = 0.0;
    var gradedWeight = 0.0;
    var totalWeight = 0.0;
    for (final c in components.sortedBy<num>((c) => c.sortOrder)) {
      final list = byComponent[c.id] ?? const <Score>[];
      final avg = componentAverage(list, subject.avgMethod);
      results.add(
        ComponentResult(
          component: c,
          average: avg,
          gradedCount: list.where((s) => !s.isUpcoming).length,
          upcomingCount: list.where((s) => s.isUpcoming).length,
        ),
      );
      totalWeight += c.weight;
      if (avg != null) {
        weighted += avg * c.weight;
        gradedWeight += c.weight;
      }
    }
    final percent = gradedWeight > 0 ? weighted / gradedWeight : null;

    double? equivalent;
    var isFinal = false;
    if (subject.finalMark != null) {
      equivalent = null;
    } else if (subject.finalGrade != null) {
      equivalent = subject.finalGrade;
      isFinal = true;
    } else if (percent != null) {
      equivalent = equivalentFor(percent, scale);
    }

    return SubjectResult(
      subject: subject,
      components: results,
      percent: percent,
      equivalent: equivalent,
      gradedWeight: gradedWeight,
      totalWeight: totalWeight,
      isFinal: isFinal,
    );
  }

  /// Projected subject percent if every ungraded item (upcoming items and
  /// components with no scores) is scored at [assumed] percent.
  double projectedPercent({
    required Subject subject,
    required List<GradeComponent> components,
    required List<Score> scores,
    required double assumed,
  }) {
    final byComponent = groupBy(scores, (Score s) => s.componentId);
    var weighted = 0.0;
    var total = 0.0;
    for (final c in components) {
      final list = byComponent[c.id] ?? const <Score>[];
      final graded = list.where((s) => !s.isUpcoming).toList();
      final upcoming = list.where((s) => s.isUpcoming).toList();
      double avg;
      if (graded.isEmpty && upcoming.isEmpty) {
        avg = assumed;
      } else if (subject.avgMethod == AvgMethod.meanPercent) {
        final pcts = [
          ...graded.map((s) => s.percent!),
          ...upcoming.map((_) => assumed),
        ];
        avg = pcts.average;
      } else {
        final got =
            graded.map((s) => s.score!).sum +
            upcoming.map((s) => s.total * assumed / 100).sum;
        final of = [...graded, ...upcoming].map((s) => s.total).sum;
        avg = got / of * 100;
      }
      weighted += avg * c.weight;
      total += c.weight;
    }
    return total <= 0 ? 0 : weighted / total;
  }
}
