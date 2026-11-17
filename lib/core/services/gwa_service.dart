import 'grade_calculator.dart';

class GwaSummary {
  const GwaSummary({
    required this.gwa,
    required this.units,
    required this.subjects,
  });

  /// Units-weighted average on the 1.00–5.00 scale; null when nothing counts.
  final double? gwa;

  /// Units of subjects that count toward the GWA.
  final double units;
  final int subjects;

  static const empty = GwaSummary(gwa: null, units: 0, subjects: 0);
}

/// GWA = Σ(units × equivalent) ÷ Σ units (proposal slide 14).
class GwaService {
  const GwaService._();

  static GwaSummary compute(Iterable<SubjectResult> results) {
    var weighted = 0.0;
    var units = 0.0;
    var n = 0;
    for (final r in results) {
      if (!r.countsInGwa) continue;
      weighted += r.subject.units * r.equivalent!;
      units += r.subject.units;
      n++;
    }
    if (units <= 0) return GwaSummary.empty;
    return GwaSummary(gwa: weighted / units, units: units, subjects: n);
  }

  /// Units earned: subjects with a passing equivalent (≤ [passingEquivalent]).
  static double unitsEarned(
    Iterable<SubjectResult> results, {
    double passingEquivalent = 3.0,
  }) {
    var u = 0.0;
    for (final r in results) {
      final e = r.equivalent;
      if (r.mark == null && e != null && e <= passingEquivalent + 1e-9)
        u += r.subject.units;
    }
    return u;
  }
}
