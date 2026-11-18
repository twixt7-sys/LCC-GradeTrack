import 'dart:async';

import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';
import '../services/grade_calculator.dart';
import '../services/gradebook.dart';
import '../services/reminder_service.dart';
import '../services/repository.dart';

/// Overridden in main() / tests.
final prefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError());
final repoProvider = Provider<GradeRepository>(
  (ref) => throw UnimplementedError(),
);

/// Set to false in widget tests to skip platform notification calls.
final remindersEnabledProvider = Provider<bool>((ref) => true);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(prefsProvider).themeMode;

  Future<void> set(ThemeMode m) async {
    state = m;
    await ref.read(prefsProvider).setThemeMode(m);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class RoundingNotifier extends Notifier<RoundingRule> {
  @override
  RoundingRule build() => ref.read(prefsProvider).rounding;

  Future<void> set(RoundingRule r) async {
    state = r;
    await ref.read(prefsProvider).setRounding(r);
  }
}

final roundingProvider = NotifierProvider<RoundingNotifier, RoundingRule>(
  RoundingNotifier.new,
);

/// The whole gradebook snapshot. Every write goes through [mutate], which
/// reloads the snapshot so all screens stay consistent.
class GradebookNotifier extends AsyncNotifier<Gradebook> {
  @override
  Future<Gradebook> build() {
    final rounding = ref.watch(roundingProvider);
    return ref.read(repoProvider).load(rounding: rounding);
  }

  Future<Gradebook> _reload() async {
    final gb = await ref
        .read(repoProvider)
        .load(rounding: ref.read(roundingProvider));
    state = AsyncData(gb);
    unawaited(_reschedule(gb));
    return gb;
  }

  Future<void> _reschedule(Gradebook gb) async {
    if (!ref.read(remindersEnabledProvider)) return;
    final p = ref.read(prefsProvider);
    try {
      await ReminderService.instance.reschedule(
        gb,
        enabled: p.remindersOn,
        daysBefore: p.reminderDaysBefore,
        time: p.reminderTime,
      );
    } on Object catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  /// Runs [op] against the repository, then reloads. Errors propagate to the caller.
  Future<T> mutate<T>(Future<T> Function(GradeRepository repo) op) async {
    final result = await op(ref.read(repoProvider));
    await _reload();
    return result;
  }

  Future<void> refresh() => _reload();

  Future<void> rescheduleReminders() async {
    final gb = state.value;
    if (gb != null) await _reschedule(gb);
  }
}

final gradebookProvider = AsyncNotifierProvider<GradebookNotifier, Gradebook>(
  GradebookNotifier.new,
);

/// Bottom nav group: 0 = Track, 1 = Analyze.
class NavGroupNotifier extends Notifier<int> {
  @override
  int build() => ref.read(prefsProvider).navGroup;

  void set(int g) {
    state = g;
    unawaited(ref.read(prefsProvider).setNavGroup(g));
  }
}

final navGroupProvider = NotifierProvider<NavGroupNotifier, int>(
  NavGroupNotifier.new,
);

/// App lock state. Starts locked when a PIN exists.
class LockNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void lock() => state = true;
  void unlock() => state = false;
}

final lockProvider = NotifierProvider<LockNotifier, bool>(LockNotifier.new);
