import 'package:lcc_gradetrack/ui.dart';

import '../services/grade_calculator.dart';

/// Design tokens. Flat colors from the LCC logo; no gradients, blur or glow.
@immutable
class GtColors extends ThemeExtension<GtColors> {
  const GtColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.hairline,
    required this.text,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.primaryText,
    required this.primarySoft,
    required this.onPrimary,
    required this.laurel,
    required this.amber,
    required this.red,
    required this.inverse,
    required this.onInverse,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color raised;
  final Color hairline;
  final Color text;
  final Color muted;
  final Color faint;

  /// LCC Blue (fills).
  final Color primary;

  /// LCC Blue tuned for text on [bg].
  final Color primaryText;

  /// Low-contrast blue fill for selected/info blocks.
  final Color primarySoft;
  final Color onPrimary;

  /// Laurel green: strong standing.
  final Color laurel;

  /// Flame amber: at risk, upcoming.
  final Color amber;

  /// Flame red: failing, delete.
  final Color red;

  /// Inverted chrome (nav group switch).
  final Color inverse;
  final Color onInverse;
  final bool isDark;

  static const dark = GtColors(
    bg: Color(0xFF0B0D10),
    surface: Color(0xFF14171C),
    raised: Color(0xFF1C2027),
    hairline: Color(0xFF262B33),
    text: Color(0xFFE9ECF1),
    muted: Color(0xFF8A93A0),
    faint: Color(0xFF59616D),
    primary: Color(0xFF2B3BE0),
    primaryText: Color(0xFF8C98FF),
    primarySoft: Color(0xFF1A1F45),
    onPrimary: Color(0xFFFFFFFF),
    laurel: Color(0xFF3DBE5A),
    amber: Color(0xFFF0A818),
    red: Color(0xFFF0594A),
    inverse: Color(0xFFE9ECF1),
    onInverse: Color(0xFF0B0D10),
    isDark: true,
  );

  static const light = GtColors(
    bg: Color(0xFFF6F5F1),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEFEDE7),
    hairline: Color(0xFFE3E1DA),
    text: Color(0xFF14171C),
    muted: Color(0xFF5E6672),
    faint: Color(0xFF9AA0A8),
    primary: Color(0xFF2B3BE0),
    primaryText: Color(0xFF2433C4),
    primarySoft: Color(0xFFE6E8FC),
    onPrimary: Color(0xFFFFFFFF),
    laurel: Color(0xFF1F8A35),
    amber: Color(0xFFA86A00),
    red: Color(0xFFC8331F),
    inverse: Color(0xFF14171C),
    onInverse: Color(0xFFF6F5F1),
    isDark: false,
  );

  Color standing(Standing s) => switch (s) {
    Standing.strong => laurel,
    Standing.onTrack => primaryText,
    Standing.atRisk => amber,
    Standing.failing => red,
    Standing.none => muted,
  };

  @override
  GtColors copyWith() => this;

  @override
  GtColors lerp(ThemeExtension<GtColors>? other, double t) {
    if (other is! GtColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return GtColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      hairline: l(hairline, other.hairline),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      primary: l(primary, other.primary),
      primaryText: l(primaryText, other.primaryText),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimary: l(onPrimary, other.onPrimary),
      laurel: l(laurel, other.laurel),
      amber: l(amber, other.amber),
      red: l(red, other.red),
      inverse: l(inverse, other.inverse),
      onInverse: l(onInverse, other.onInverse),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Subject tile colors. Each passes 4.5:1 with white text.
const subjectPalette = <Color>[
  Color(0xFF2B3BE0), // LCC blue
  Color(0xFF0B7375), // teal
  Color(0xFF237A30), // laurel
  Color(0xFF94600A), // ochre
  Color(0xFFB4441E), // rust
  Color(0xFF8E3368), // plum
  Color(0xFF46596A), // slate
  Color(0xFF66691A), // olive
];

Color subjectColor(int idx) => subjectPalette[idx % subjectPalette.length];

abstract final class Gt {
  static const radius = 14.0;
  static const radiusSm = 10.0;
  static const pad = 16.0;
  static const topBar = 64.0;
  static const navBar = 88.0;
  static const fast = Duration(milliseconds: 160);
  static const med = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
}

extension GtContext on BuildContext {
  GtColors get gt => Theme.of(this).extension<GtColors>()!;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}
