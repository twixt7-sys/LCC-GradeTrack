// Renders app screens to PNGs for design review and the README.
//
//   flutter test test_screenshots --update-goldens
//
// Output: test_screenshots/out/*.png (not part of `flutter test` in CI).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lcc_gradetrack/ui.dart';

import '../test/support/harness.dart';

const _size = Size(390, 844);

Future<void> _pumpApp(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = _size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app.widget());
  await tester.pumpAndSettle();
  await _settleImages(tester);
}

/// Image decoding runs in real time; give it a moment, then repaint.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> _go(WidgetTester tester, String path) async {
  _router(tester).go(path);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settleImages(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    final t = theme.name;

    testWidgets('home $t', (tester) async {
      final app = await createTestApp(theme: theme);
      await _pumpApp(tester, app);
      await _shot(tester, '01_home_$t');
    });

    testWidgets('subjects $t', (tester) async {
      final app = await createTestApp(theme: theme);
      await _pumpApp(tester, app);
      await _go(tester, '/subjects');
      await _shot(tester, '02_subjects_$t');
    });

    testWidgets('subject detail $t', (tester) async {
      final app = await createTestApp(theme: theme);
      await _pumpApp(tester, app);
      final id = (await app.db.db.query(
        'subjects',
        where: 'code = ?',
        whereArgs: ['IT 126'],
      )).first['id'];
      unawaited(_router(tester).push('/subject/$id'));
      await tester.pumpAndSettle();
      await _shot(tester, '03_subject_scores_$t');
      await tester.tap(find.text('Breakdown'));
      await tester.pumpAndSettle();
      await _shot(tester, '04_subject_breakdown_$t');
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      await _shot(tester, '05_subject_breakdown_scrolled_$t');
    });

    testWidgets('scores $t', (tester) async {
      final app = await createTestApp(theme: theme);
      await _pumpApp(tester, app);
      await _go(tester, '/scores');
      await _shot(tester, '06_scores_$t');
    });

    testWidgets('progress $t', (tester) async {
      final app = await createTestApp(theme: theme);
      await _pumpApp(tester, app);
      await _go(tester, '/progress');
      await _shot(tester, '07_progress_$t');
    });
  }

  testWidgets('planner', (tester) async {
    final app = await createTestApp();
    await _pumpApp(tester, app);
    await _go(tester, '/planner');
    await _shot(tester, '08_planner_dark');
  });

  testWidgets('calculator', (tester) async {
    final app = await createTestApp();
    await _pumpApp(tester, app);
    await _go(tester, '/calculator');
    await _shot(tester, '09_calculator_dark');
    await tester.tap(find.text('Target score'));
    await tester.pumpAndSettle();
    await _shot(tester, '10_calculator_target_dark');
  });

  testWidgets('history', (tester) async {
    final app = await createTestApp();
    await _pumpApp(tester, app);
    await _go(tester, '/history');
    await _shot(tester, '11_history_dark');
  });

  testWidgets('fab menu and add score', (tester) async {
    final app = await createTestApp();
    await _pumpApp(tester, app);
    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pumpAndSettle();
    await _shot(tester, '12_fab_menu_dark');
    await tester.tap(find.text('Score'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('score-field')), '18');
    await tester.enterText(find.byKey(const Key('total-field')), '20');
    await tester.pumpAndSettle();
    await _shot(tester, '13_add_score_dark');
  });

  testWidgets('add subject sheet', (tester) async {
    final app = await createTestApp(theme: ThemeMode.light);
    await _pumpApp(tester, app);
    await _go(tester, '/subjects');
    await tester.tap(find.bySemanticsLabel('Add subject').last);
    await tester.pumpAndSettle();
    await _shot(tester, '14_add_subject_light');
  });

  testWidgets('drawer', (tester) async {
    final app = await createTestApp();
    await _pumpApp(tester, app);
    await tester.tap(find.bySemanticsLabel('Open menu'));
    await tester.pumpAndSettle();
    await _shot(tester, '15_drawer_dark');
  });

  testWidgets('settings', (tester) async {
    final app = await createTestApp();
    await _pumpApp(tester, app);
    unawaited(_router(tester).push('/settings'));
    await tester.pumpAndSettle();
    await _shot(tester, '16_settings_dark');
  });

  testWidgets('onboarding', (tester) async {
    final app = await createTestApp(onboarded: false, sample: false);
    await _pumpApp(tester, app);
    await _shot(tester, '17_onboarding_welcome_dark');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await _shot(tester, '18_onboarding_profile_dark');
  });

  testWidgets('empty home', (tester) async {
    final app = await createTestApp(sample: false, theme: ThemeMode.light);
    await _pumpApp(tester, app);
    await _shot(tester, '19_home_empty_light');
  });
}
