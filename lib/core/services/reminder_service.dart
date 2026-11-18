import 'package:flutter/foundation.dart';
import 'package:lcc_gradetrack/ui.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../theme/format.dart';
import 'gradebook.dart';

/// Schedules local reminders for upcoming assessments. Inexact alarms only,
/// so no exact-alarm permission is needed. Everything stays on the device.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'assessments',
    'Assessment reminders',
    channelDescription: 'Reminders for upcoming quizzes, activities and exams.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_launcher_monochrome',
  );

  Future<void> init() async {
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_monochrome'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Returns true when notifications are allowed.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  /// Cancels all reminders and schedules one per upcoming assessment.
  Future<void> reschedule(
    Gradebook gb, {
    required bool enabled,
    required int daysBefore,
    required TimeOfDay time,
  }) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    var count = 0;
    for (final u in gb.upcoming()) {
      final d = u.score.date.subtract(Duration(days: daysBefore));
      final at = tz.TZDateTime(
        tz.local,
        d.year,
        d.month,
        d.day,
        time.hour,
        time.minute,
      );
      if (at.isBefore(now)) continue;
      final when = daysBefore == 0
          ? 'today'
          : daysBefore == 1
          ? 'tomorrow'
          : fmtWmd(u.score.date);
      await _plugin.zonedSchedule(
        id: u.score.id!,
        scheduledDate: at,
        title: '${u.subject.code} · ${u.score.title}',
        body:
            'Due $when · ${fmtNum(u.component.weight)}% of grade (${u.component.name})',
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      if (++count >= 60) break; // stay well under Android's alarm limit
    }
  }
}
