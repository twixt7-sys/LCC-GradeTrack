// On-device end-to-end flow. Run on an emulator or phone:
//   flutter test integration_test
// Uses the real app database, so run it on a test device.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lcc_gradetrack/core/db/database_helper.dart';
import 'package:lcc_gradetrack/main.dart' as app;
import 'package:lcc_gradetrack/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start from a clean install state.
    await SharedPreferencesAsync().clear();
    await deleteDatabase(
      await getDatabasesPath().then((d) => '$d/${DatabaseHelper.fileName}'),
    );
  });

  testWidgets('onboard, add a subject, record a score, see the GWA', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();

    // Onboarding: welcome → profile → term → scale → security → start empty.
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding-name')),
      'Juan Dela Cruz',
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('No subjects yet'), findsOneWidget);

    // Add IT 126 with the default 20/15/25/40 components.
    await tester.tap(find.text('Add subject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code-field')), 'IT 126');
    await tester.enterText(
      find.byKey(const Key('title-field')),
      'Mobile Development',
    );
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    // Record 18/20 on a quiz → 90% (only graded component) → 1.75 → GWA 1.75.
    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('score-field')), '18');
    await tester.enterText(find.byKey(const Key('total-field')), '20');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('1.75'), findsWidgets);
    expect(find.text('General Weighted Average'), findsOneWidget);
  });
}
