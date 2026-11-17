import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/grade_calculator.dart';

/// Small settings in SharedPreferences (proposal slide 25). Records live in SQLite.
class AppPrefs {
  AppPrefs(this._p);
  final SharedPreferencesWithCache _p;

  static const _theme = 'theme_mode';
  static const _onboarded = 'onboarding_done';
  static const _rounding = 'rounding_rule';
  static const _avgMethod = 'default_avg_method';
  static const _template = 'default_components';
  static const _remindOn = 'reminders_on';
  static const _remindDays = 'reminders_days_before';
  static const _remindHour = 'reminders_hour';
  static const _remindMinute = 'reminders_minute';
  static const _lockDelay = 'lock_delay_seconds';
  static const _navGroup = 'nav_group';

  static Future<AppPrefs> load() async => AppPrefs(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    ),
  );

  ThemeMode get themeMode => switch (_p.getString(_theme)) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
  Future<void> setThemeMode(ThemeMode m) => _p.setString(_theme, m.name);

  bool get onboarded => _p.getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) => _p.setBool(_onboarded, v);

  RoundingRule get rounding => RoundingRule.fromCode(_p.getString(_rounding));
  Future<void> setRounding(RoundingRule r) => _p.setString(_rounding, r.code);

  AvgMethod get defaultAvgMethod =>
      AvgMethod.fromCode(_p.getString(_avgMethod));
  Future<void> setDefaultAvgMethod(AvgMethod m) =>
      _p.setString(_avgMethod, m.code);

  List<GradeComponent> get componentTemplate {
    final raw = _p.getString(_template);
    if (raw == null) return defaultComponentTemplate;
    try {
      final list = (jsonDecode(raw) as List<Object?>)
          .cast<Map<String, Object?>>();
      final out = [
        for (final (i, m) in list.indexed) GradeComponent.fromTemplate(m, i),
      ];
      return out.isEmpty ? defaultComponentTemplate : out;
    } on Object {
      return defaultComponentTemplate;
    }
  }

  Future<void> setComponentTemplate(List<GradeComponent> list) => _p.setString(
    _template,
    jsonEncode([for (final c in list) c.toTemplate()]),
  );

  bool get remindersOn => _p.getBool(_remindOn) ?? false;
  Future<void> setRemindersOn(bool v) => _p.setBool(_remindOn, v);

  int get reminderDaysBefore => _p.getInt(_remindDays) ?? 1;
  Future<void> setReminderDaysBefore(int v) => _p.setInt(_remindDays, v);

  TimeOfDay get reminderTime => TimeOfDay(
    hour: _p.getInt(_remindHour) ?? 19,
    minute: _p.getInt(_remindMinute) ?? 0,
  );
  Future<void> setReminderTime(TimeOfDay t) async {
    await _p.setInt(_remindHour, t.hour);
    await _p.setInt(_remindMinute, t.minute);
  }

  /// Seconds in background before the PIN lock shows again.
  int get lockDelay => _p.getInt(_lockDelay) ?? 60;
  Future<void> setLockDelay(int v) => _p.setInt(_lockDelay, v);

  int get navGroup => _p.getInt(_navGroup) ?? 0;
  Future<void> setNavGroup(int v) => _p.setInt(_navGroup, v);

  Future<void> clear() => _p.clear();
}
