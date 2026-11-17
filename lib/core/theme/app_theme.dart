import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

const uiFont = 'Schibsted';
const monoFont = 'JetBrainsMono';

const _tabular = [FontFeature.tabularFigures()];

/// Mono style for every number and code (GWA, %, units, scores, dates).
TextStyle mono(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color? color,
  double? letterSpacing,
  double? height,
}) => TextStyle(
  fontFamily: monoFont,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing ?? (size >= 28 ? -size * 0.04 : 0),
  height: height,
  fontFeatures: _tabular,
);

TextTheme _textTheme(GtColors c) {
  TextStyle s(
    double size,
    FontWeight w, {
    Color? color,
    double? ls,
    double? h,
  }) => TextStyle(
    fontFamily: uiFont,
    fontSize: size,
    fontWeight: w,
    color: color ?? c.text,
    letterSpacing: ls,
    height: h,
    fontFeatures: _tabular,
  );
  return TextTheme(
    displaySmall: s(30, FontWeight.w800, ls: -0.6, h: 1.1),
    headlineSmall: s(24, FontWeight.w800, ls: -0.4, h: 1.15),
    titleLarge: s(20, FontWeight.w700, ls: -0.2, h: 1.2),
    titleMedium: s(16, FontWeight.w600, h: 1.25),
    titleSmall: s(14, FontWeight.w600, h: 1.25),
    bodyLarge: s(16, FontWeight.w400, h: 1.4),
    bodyMedium: s(14, FontWeight.w400, h: 1.4),
    bodySmall: s(12.5, FontWeight.w400, color: c.muted, h: 1.35),
    labelLarge: s(14, FontWeight.w600),
    labelMedium: s(12, FontWeight.w600),
    // Section labels: uppercase, tracked.
    labelSmall: s(10.5, FontWeight.w700, color: c.muted, ls: 1.1),
  );
}

ThemeData buildTheme(GtColors c) {
  final scheme = ColorScheme(
    brightness: c.isDark ? Brightness.dark : Brightness.light,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.primaryText,
    onSecondary: c.onPrimary,
    error: c.red,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.bg,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.raised,
    outline: c.hairline,
    outlineVariant: c.hairline,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.primaryText,
    inverseSurface: c.inverse,
    onInverseSurface: c.onInverse,
    surfaceTint: Colors.transparent,
  );
  final tt = _textTheme(c);
  final fieldRadius = BorderRadius.circular(Gt.radiusSm + 2);
  OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: color, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [c],
    fontFamily: uiFont,
    textTheme: tt,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: c.text, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: tt.titleLarge,
      systemOverlayStyle: c.isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: tt.bodyMedium!.copyWith(color: c.muted),
      floatingLabelStyle: tt.labelMedium!.copyWith(color: c.primaryText),
      hintStyle: tt.bodyMedium!.copyWith(color: c.faint),
      errorStyle: tt.bodySmall!.copyWith(
        color: c.red,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: tt.bodySmall,
      enabledBorder: border(c.hairline),
      border: border(c.hairline),
      focusedBorder: border(c.primaryText, 1.6),
      errorBorder: border(c.red),
      focusedErrorBorder: border(c.red, 1.6),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primaryText,
      selectionColor: c.primary.withValues(alpha: 0.3),
      selectionHandleColor: c.primaryText,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size.fromHeight(52),
        textStyle: tt.labelLarge!.copyWith(fontSize: 15),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: c.hairline),
        textStyle: tt.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primaryText,
        textStyle: tt.labelLarge,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      modalBackgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gt.radius + 4),
        side: BorderSide(color: c.hairline),
      ),
      titleTextStyle: tt.titleMedium,
      contentTextStyle: tt.bodyMedium!.copyWith(color: c.muted),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      width: 300,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gt.radius),
        side: BorderSide(color: c.hairline),
      ),
      textStyle: tt.bodyMedium,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.raised,
      ),
      trackOutlineColor: WidgetStateProperty.all(c.hairline),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.surface,
      headerForegroundColor: c.text,
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.surface),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverse,
      contentTextStyle: tt.bodyMedium!.copyWith(
        color: c.onInverse,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: c.onInverse,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gt.radiusSm + 2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primaryText),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
