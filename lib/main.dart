import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/database_helper.dart';
import 'core/prefs/app_prefs.dart';
import 'core/providers/providers.dart';
import 'core/services/reminder_service.dart';
import 'core/services/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Bundled font licenses (OFL) for the licenses page.
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [
      ('Schibsted Grotesk', 'assets/fonts/SchibstedGrotesk-OFL.txt'),
      ('JetBrains Mono', 'assets/fonts/JetBrainsMono-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(file));
    }
  });

  final results = await Future.wait([AppPrefs.load(), DatabaseHelper.open()]);
  final prefs = results[0] as AppPrefs;
  final db = results[1] as DatabaseHelper;
  unawaited(
    ReminderService.instance.init().catchError(
      (Object e) => debugPrint('Reminders unavailable: $e'),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        repoProvider.overrideWithValue(GradeRepository(db)),
      ],
      child: const GradeTrackApp(),
    ),
  );
}
