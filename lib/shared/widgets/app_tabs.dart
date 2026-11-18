import 'package:flutter/widgets.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

/// Shell tabs. Index = StatefulShellRoute branch index.
/// Group 0 (Track): Subjects, Scores, Planner. Group 1 (Analyze): Progress, Calculator, History.
enum AppTab {
  home('/', 'Home', Ph.house, PhFill.house, -1),
  subjects('/subjects', 'Subjects', Ph.books, PhFill.books, 0),
  scores('/scores', 'Scores', Ph.listChecks, PhFill.listChecks, 0),
  planner('/planner', 'Planner', Ph.calendarDots, PhFill.calendarDots, 0),
  progress('/progress', 'Progress', Ph.chartLine, PhFill.chartLine, 1),
  calculator('/calculator', 'Calculator', Ph.calculator, PhFill.calculator, 1),
  history(
    '/history',
    'History',
    Ph.clockCounterClockwise,
    PhFill.clockCounterClockwise,
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
