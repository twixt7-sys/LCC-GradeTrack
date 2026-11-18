import 'package:flutter_test/flutter_test.dart';
import 'package:lcc_gradetrack/core/services/pin_service.dart';
import 'package:lcc_gradetrack/ui.dart';

import '../support/harness.dart';

Future<TestApp> _pump(
  WidgetTester tester, {
  bool onboarded = true,
  bool sample = true,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final app = await createTestApp(onboarded: onboarded, sample: sample);
  await tester.pumpWidget(app.widget());
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('onboarding creates a profile and term, then opens Home', (
    tester,
  ) async {
    final app = await _pump(tester, onboarded: false, sample: false);
    expect(find.text('LCC GradeTrack'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('onboarding-next')),
    ); // Welcome → Profile
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('onboarding-next')),
    ); // empty name blocked
    await tester.pumpAndSettle();
    expect(find.text('Name is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-name')),
      'Maria Santos',
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('No subjects yet'), findsOneWidget);
    expect(find.text('MS'), findsOneWidget); // avatar initials
    expect(app.prefs.onboarded, isTrue);
    final terms = await app.db.db.query('terms');
    expect(terms, hasLength(1));
    expect(terms.first['is_current'], 1);
  });

  testWidgets('score above total shows an inline error and is not saved', (
    tester,
  ) async {
    final app = await _pump(tester);
    final before = (await app.db.db.query('scores')).length;
    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('score-field')), '21');
    await tester.enterText(find.byKey(const Key('total-field')), '20');
    await tester.pumpAndSettle();
    expect(find.text('Score cannot exceed total items.'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect((await app.db.db.query('scores')).length, before);

    await tester.enterText(find.byKey(const Key('score-field')), '18');
    await tester.pumpAndSettle();
    expect(find.text('90.00%'), findsOneWidget); // auto-computed
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect((await app.db.db.query('scores')).length, before + 1);
  });

  testWidgets('subject weights must total 100% before saving', (tester) async {
    final app = await _pump(tester);
    final before = (await app.db.db.query('subjects')).length;
    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subject'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('code-field')), 'IT 127');
    await tester.enterText(
      find.byKey(const Key('title-field')),
      'Systems Integration',
    );
    await tester.tap(
      find.byTooltip('Remove component').first,
    ); // drop Quizzes 20%
    await tester.pumpAndSettle();
    expect(find.text('80% — 20% left'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect((await app.db.db.query('subjects')).length, before);

    await tester.tap(find.text('Add component'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Component').last,
      'Project',
    );
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    final rows = await app.db.db.query(
      'subjects',
      where: 'code = ?',
      whereArgs: ['IT 127'],
    );
    expect(rows, hasLength(1));
    final comps = await app.db.db.query(
      'components',
      where: 'subject_id = ?',
      whereArgs: [rows.first['id']],
    );
    expect(comps.map((c) => c['name']), [
      'Assignments',
      'Activities',
      'Exams',
      'Project',
    ]);
  });

  testWidgets('group switch shows the Analyze tabs', (tester) async {
    await _pump(tester);
    expect(find.bySemanticsLabel('Subjects'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Show analysis tabs'));
    await tester.pumpAndSettle();
    expect(find.text('GWA per term'), findsOneWidget);
    expect(find.bySemanticsLabel('Calculator'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show tracking tabs'));
    await tester.pumpAndSettle();
    expect(find.text('Search code, title, instructor'), findsOneWidget);
  });

  testWidgets('PIN lock blocks the app until the right PIN is entered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final app = await createTestApp();
    final salt = PinService.newSalt();
    await app.db.db.update('profile', {
      'pin_hash': PinService.hash('2468', salt),
      'pin_salt': salt,
    });
    await tester.pumpWidget(app.widget());
    await tester.pumpAndSettle();

    expect(find.text('Enter your PIN'), findsOneWidget);
    for (final d in '1111'.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Wrong PIN'), findsOneWidget);

    for (final d in '2468'.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
    }
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsNothing);
    expect(find.text('General Weighted Average'), findsOneWidget);
  });

  testWidgets('recording the upcoming midterm updates the subject grade', (
    tester,
  ) async {
    await _pump(tester);
    // Next up card → record score screen.
    await tester.tap(find.text('IT 126 Midterm Exam'));
    await tester.pumpAndSettle();
    expect(find.text('Record score'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('score-field')), '60');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    // Exams avg (84 + 100) / 2 = 92 → 17 + 14.1 + 22.5 + 36.8 = 90.40 → 1.75 (91% needed for 1.50).
    await tester.tap(
      find.textContaining('Mobile Development', findRichText: true).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('90.40%'), findsOneWidget);
    expect(find.text('Equivalent 1.75'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
  });
}
