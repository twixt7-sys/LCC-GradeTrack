import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/providers.dart';
import 'features/calculator/calculator_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/planner/planner_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/reminders/reminders_screen.dart';
import 'features/scores/scores_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/components_template_screen.dart';
import 'features/settings/data_screen.dart';
import 'features/settings/scale_editor_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/subjects/subject_detail_screen.dart';
import 'features/subjects/subjects_screen.dart';
import 'shared/widgets/app_shell.dart';
import 'shared/widgets/app_tabs.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.read(prefsProvider);

  Widget tabScreen(AppTab t) => switch (t) {
    AppTab.home => const HomeScreen(),
    AppTab.subjects => const SubjectsScreen(),
    AppTab.scores => const ScoresScreen(),
    AppTab.planner => const PlannerScreen(),
    AppTab.progress => const ProgressScreen(),
    AppTab.calculator => const CalculatorScreen(),
    AppTab.history => const HistoryScreen(),
  };

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final onboarding = state.matchedLocation == '/onboarding';
      if (!prefs.onboarded && !onboarding) return '/onboarding';
      if (prefs.onboarded && onboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final t in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: t.path,
                  pageBuilder: (_, _) => NoTransitionPage(child: tabScreen(t)),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/subject/:id',
        builder: (_, s) =>
            SubjectDetailScreen(subjectId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/term/:id',
        builder: (_, s) =>
            TermDetailScreen(termId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/scale',
        builder: (_, _) => const ScaleEditorScreen(),
      ),
      GoRoute(
        path: '/settings/components',
        builder: (_, _) => const ComponentsTemplateScreen(),
      ),
      GoRoute(path: '/settings/data', builder: (_, _) => const DataScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    ],
  );
});
