/// Form validators. Messages are short and direct (proposal slides 15, 25).
class Validators {
  const Validators._();

  static double? parseNum(String? v) {
    final t = v?.trim().replaceAll(',', '') ?? '';
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required.' : null;

  static String? total(String? v) {
    final t = parseNum(v);
    if (v == null || v.trim().isEmpty) return 'Enter the total items.';
    if (t == null) return 'Enter a number.';
    if (t <= 0) return 'Total must be greater than 0.';
    if (t > 10000) return 'Total is too large.';
    return null;
  }

  /// Validates a score against its total. Empty is allowed when [allowEmpty].
  static String? score(
    String? v,
    String? totalText, {
    bool allowEmpty = false,
  }) {
    if (v == null || v.trim().isEmpty) {
      return allowEmpty ? null : 'Enter the score.';
    }
    final s = parseNum(v);
    if (s == null) return 'Enter a number.';
    if (s < 0) return 'Score cannot be negative.';
    final t = parseNum(totalText);
    if (t != null && t > 0 && s > t) return 'Score cannot exceed total items.';
    return null;
  }

  static String? units(String? v) {
    final u = parseNum(v);
    if (v == null || v.trim().isEmpty) return 'Enter the units.';
    if (u == null) return 'Enter a number.';
    if (u <= 0) return 'Units must be greater than 0.';
    if (u > 10) return 'Units must be 10 or less.';
    return null;
  }

  static String? weight(String? v) {
    final w = parseNum(v);
    if (v == null || v.trim().isEmpty) return 'Enter a weight.';
    if (w == null) return 'Enter a number.';
    if (w <= 0) return 'Weight must be greater than 0.';
    if (w > 100) return 'Weight cannot exceed 100%.';
    return null;
  }

  static bool weightsComplete(Iterable<double> weights) =>
      (weights.fold<double>(0, (a, b) => a + b) - 100).abs() < 0.01;

  /// "100%", "85% — 15% left", "110% — 10% over".
  static String weightsStatus(Iterable<double> weights) {
    final sum = weights.fold<double>(0, (a, b) => a + b);
    String f(double x) =>
        x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
    if ((sum - 100).abs() < 0.01) return '100%';
    if (sum < 100) return '${f(sum)}% — ${f(100 - sum)}% left';
    return '${f(sum)}% — ${f(sum - 100)}% over';
  }

  static String? finalGrade(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final g = parseNum(v);
    if (g == null) return 'Enter a number.';
    if (g < 1 || g > 5) return 'Grade must be between 1.00 and 5.00.';
    return null;
  }

  static String? pin(String? v) {
    if (v == null || !RegExp(r'^\d{4}$').hasMatch(v)) return 'Use 4 digits.';
    return null;
  }
}
