import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lcc_gradetrack/app.dart';
import 'package:lcc_gradetrack/core/db/database_helper.dart';
import 'package:lcc_gradetrack/core/db/seed_sample.dart';
import 'package:lcc_gradetrack/core/prefs/app_prefs.dart';
import 'package:lcc_gradetrack/core/providers/providers.dart';
import 'package:lcc_gradetrack/core/services/repository.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Loads every font in FontManifest.json so text renders with real glyphs.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final loader = FontLoader(entry['family']! as String);
    for (final f
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(f['asset']! as String));
    }
    await loader.load();
  }
}

class TestApp {
  TestApp(this.db, this.prefs);
  final DatabaseHelper db;
  final AppPrefs prefs;

  Widget widget() => ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      repoProvider.overrideWithValue(GradeRepository(db)),
      remindersEnabledProvider.overrideWithValue(false),
    ],
    child: const GradeTrackApp(),
  );
}

/// In-memory database and preferences. Synchronous sqlite (no isolate) so
/// queries complete inside fake-async widget tests.
Future<TestApp> createTestApp({
  bool onboarded = true,
  bool sample = true,
  ThemeMode theme = ThemeMode.dark,
  DateTime? now,
}) async {
  sqfliteFfiInit();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final prefs = await AppPrefs.load();
  await prefs.setOnboarded(onboarded);
  await prefs.setThemeMode(theme);
  final db = await DatabaseHelper.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
  // sqflite reuses an open database per path; close it so each test starts clean.
  addTearDown(db.close);
  if (sample) await SampleData.seed(db.db, now: now);
  return TestApp(db, prefs);
}
