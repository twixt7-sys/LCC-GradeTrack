import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shell tabs. Index = StatefulShellRoute branch index.
/// Group 0 (Track): Subjects, Scores, Planner. Group 1 (Analyze): Progress, Calculator, History.
enum AppTab {
  home('/', 'Home', PhosphorIconsRegular.house, PhosphorIconsFill.house, -1),
  subjects(
    '/subjects',
    'Subjects',
    PhosphorIconsRegular.books,
    PhosphorIconsFill.books,
    0,
  ),
  scores(
    '/scores',
    'Scores',
    PhosphorIconsRegular.listChecks,
    PhosphorIconsFill.listChecks,
    0,
  ),
  planner(
    '/planner',
    'Planner',
    PhosphorIconsRegular.calendarDots,
    PhosphorIconsFill.calendarDots,
    0,
  ),
  progress(
    '/progress',
    'Progress',
    PhosphorIconsRegular.chartLine,
    PhosphorIconsFill.chartLine,
    1,
  ),
  calculator(
    '/calculator',
    'Calculator',
    PhosphorIconsRegular.calculator,
    PhosphorIconsFill.calculator,
    1,
  ),
  history(
    '/history',
    'History',
    PhosphorIconsRegular.clockCounterClockwise,
    PhosphorIconsFill.clockCounterClockwise,
    1,
  );

  const AppTab(this.path, this.label, this.icon, this.activeIcon, this.group);

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// -1 = pinned (Home).
  final int group;

  static List<AppTab> ofGroup(int g) =>
      values.where((t) => t.group == g).toList();
}
