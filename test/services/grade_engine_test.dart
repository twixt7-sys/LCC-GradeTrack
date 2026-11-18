import 'package:flutter_test/flutter_test.dart';
import 'package:lcc_gradetrack/core/models/models.dart';
import 'package:lcc_gradetrack/core/services/grade_calculator.dart';
import 'package:lcc_gradetrack/core/services/gwa_service.dart';
import 'package:lcc_gradetrack/core/services/target_solver.dart';

final _t = DateTime(2026, 11, 10);

Subject _subject({
  int id = 1,
  String code = 'IT 126',
  double units = 3,
  double? finalGrade,
  FinalMark? mark,
  AvgMethod method = AvgMethod.meanPercent,
}) => Subject(
  id: id,
  termId: 1,
  code: code,
  title: 'Mobile Development',
  units: units,
  avgMethod: method,
  finalGrade: finalGrade,
  finalMark: mark,
  createdAt: _t,
  updatedAt: _t,
);

List<GradeComponent> _components() => [
  for (final (i, c) in defaultComponentTemplate.indexed)
    c.copyWith(id: i + 1, subjectId: 1),
];

int _sid = 0;
Score _s(int componentId, double? score, double total) => Score(
  id: ++_sid,
  componentId: componentId,
  title: 'Item $_sid',
  score: score,
  total: total,
  date: _t,
  createdAt: _t,
  updatedAt: _t,
);

/// IT 126 from slide 14: Quizzes 85, Assignments 94, Activities 90, Exams 84.
List<Score> _it126Scores({bool withUpcoming = true}) => [
  _s(1, 16, 20),
  _s(1, 17, 20),
  _s(1, 18, 20),
  _s(2, 47, 50),
  _s(3, 44, 50),
  _s(3, 46, 50),
  _s(4, 42, 50),
  if (withUpcoming) _s(4, null, 60),
];

void main() {
  const calc = GradeCalculator();
  const scale = GradeScale.lccStandard;

  group('Slide 14 worked example', () {
    test('component averages and points', () {
      final r = calc.compute(
        subject: _subject(),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
      );
      final avgs = r.components.map((c) => c.average!).toList();
      expect(avgs[0], closeTo(85.0, 1e-9));
      expect(avgs[1], closeTo(94.0, 1e-9));
      expect(avgs[2], closeTo(90.0, 1e-9));
      expect(avgs[3], closeTo(84.0, 1e-9));
      final pts = r.components.map((c) => c.points!).toList();
      expect(pts, [
        closeTo(17.00, 1e-9),
        closeTo(14.10, 1e-9),
        closeTo(22.50, 1e-9),
        closeTo(33.60, 1e-9),
      ]);
    });

    test('IT 126 = 87.20% → 2.00', () {
      final r = calc.compute(
        subject: _subject(),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
      );
      expect(r.percent, closeTo(87.20, 1e-9));
      expect(r.equivalent, 2.00);
      expect(r.standing, Standing.onTrack);
      expect(r.gradedWeight, 100);
    });

    test('GWA = 24.25 ÷ 14 = 1.73', () {
      SubjectResult fixed(int id, double units, double g) => calc.compute(
        subject: _subject(id: id, units: units, finalGrade: g),
        components: const [],
        scores: const [],
        scale: scale,
      );
      final summary = GwaService.compute([
        fixed(1, 3, 2.00),
        fixed(2, 3, 1.50),
        fixed(3, 3, 1.75),
        fixed(4, 3, 2.00),
        fixed(5, 2, 1.25),
      ]);
      expect(summary.units, 14);
      expect(summary.gwa, closeTo(24.25 / 14, 1e-12));
      expect(summary.gwa!.toStringAsFixed(2), '1.73');
    });
  });

  group('Scale conversion boundaries', () {
    test('cutoffs', () {
      expect(calc.equivalentFor(97, scale), 1.00);
      expect(calc.equivalentFor(96.99, scale), 1.25);
      expect(calc.equivalentFor(87.99, scale), 2.00);
      expect(calc.equivalentFor(85.00, scale), 2.00);
      expect(calc.equivalentFor(84.99, scale), 2.25);
      expect(calc.equivalentFor(76, scale), 2.75);
      expect(calc.equivalentFor(75, scale), 3.00);
      expect(calc.equivalentFor(74.99, scale), 5.00);
      expect(calc.equivalentFor(0, scale), 5.00);
    });

    test('rounding rules', () {
      expect(
        const GradeCalculator().equivalentFor(84.995, scale),
        2.00,
      ); // 2dp → 85.00
      expect(
        const GradeCalculator(rounding: RoundingRule.none)
            .equivalentFor(84.995, scale),
        2.25,
      );
      expect(
        const GradeCalculator(rounding: RoundingRule.whole)
            .equivalentFor(84.5, scale),
        2.00,
      );
      expect(
        const GradeCalculator(rounding: RoundingRule.whole)
            .equivalentFor(84.4, scale),
        2.25,
      );
    });
  });

  group('Partial and special cases', () {
    test('no scores → no grade', () {
      final r = calc.compute(
        subject: _subject(),
        components: _components(),
        scores: const [],
        scale: scale,
      );
      expect(r.percent, isNull);
      expect(r.equivalent, isNull);
      expect(r.standing, Standing.none);
      expect(r.countsInGwa, isFalse);
    });

    test('in-progress grade normalizes over graded weight', () {
      final r = calc.compute(
        subject: _subject(),
        components: _components(),
        scores: [_s(1, 18, 20), _s(4, 40, 50)], // 90 @20, 80 @40
        scale: scale,
      );
      expect(r.gradedWeight, 60);
      expect(r.percent, closeTo((90 * 20 + 80 * 40) / 60, 1e-9));
      expect(r.inProgress, isTrue);
      expect(r.gradedShare, closeTo(60, 1e-9));
    });

    test('total points method', () {
      final r = calc.compute(
        subject: _subject(method: AvgMethod.totalPoints),
        components: _components().take(1).toList(),
        scores: [_s(1, 9, 10), _s(1, 30, 50)], // 39/60 = 65
        scale: scale,
      );
      expect(r.percent, closeTo(65, 1e-9));
    });

    test('final grade overrides; INC excluded from GWA', () {
      final fin = calc.compute(
        subject: _subject(finalGrade: 1.5),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
      );
      expect(fin.equivalent, 1.5);
      expect(fin.isFinal, isTrue);
      final inc = calc.compute(
        subject: _subject(id: 2, mark: FinalMark.inc),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
      );
      expect(inc.equivalent, isNull);
      expect(inc.countsInGwa, isFalse);
      final g = GwaService.compute([fin, inc]);
      expect(g.gwa, 1.5);
      expect(g.units, 3);
    });

    test('standing bands', () {
      expect(Standing.of(1.75), Standing.strong);
      expect(Standing.of(2.0), Standing.onTrack);
      expect(Standing.of(2.5), Standing.onTrack);
      expect(Standing.of(2.75), Standing.atRisk);
      expect(Standing.of(3.0), Standing.atRisk);
      expect(Standing.of(5.0), Standing.failing);
    });
  });

  group('TargetSolver', () {
    const solver = TargetSolver(calc);

    test('needs X% on the upcoming midterm to reach 1.75', () {
      // Exams: 84 + upcoming midterm. Other components fixed.
      final res = solver.solve(
        subject: _subject(),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
        targetEquivalent: 1.75,
      );
      expect(res.status, TargetStatus.needs);
      expect(res.targetMinPercent, 88);
      // With 2 dp rounding, 87.98 on the midterm gives 87.996 → 88.00.
      expect(res.neededPercent, closeTo(87.98, 0.001));

      // Without rounding: exams avg must reach (88 - 53.6) / 0.4 = 86 → (84 + x) / 2 = 86 → 88.
      const exact = TargetSolver(GradeCalculator(rounding: RoundingRule.none));
      final raw = exact.solve(
        subject: _subject(),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
        targetEquivalent: 1.75,
      );
      expect(raw.neededPercent, closeTo(88.0, 0.01));
    });

    test('secured and unreachable', () {
      // Only one quiz left: even 0% keeps the subject at 82.95% → 2.25.
      final secured = solver.solve(
        subject: _subject(),
        components: _components(),
        scores: [..._it126Scores(withUpcoming: false), _s(1, null, 20)],
        scale: scale,
        targetEquivalent: 2.25,
      );
      expect(secured.status, TargetStatus.secured);
      final unreachable = solver.solve(
        subject: _subject(),
        components: _components(),
        scores: _it126Scores(),
        scale: scale,
        targetEquivalent: 1.0,
      );
      expect(unreachable.status, TargetStatus.unreachable);
    });

    test('complete when nothing remains', () {
      final res = solver.solve(
        subject: _subject(),
        components: _components(),
        scores: _it126Scores(withUpcoming: false),
        scale: scale,
        targetEquivalent: 1.75,
      );
      expect(res.status, TargetStatus.complete);
    });

    test('ungraded components count as remaining work', () {
      final res = solver.solve(
        subject: _subject(),
        components: _components(),
        scores: [_s(1, 20, 20)], // only quizzes graded at 100
        scale: scale,
        targetEquivalent: 2.0,
      );
      // 100*0.2 + x*0.8 >= 85 → x >= 81.25
      expect(res.status, TargetStatus.needs);
      expect(res.neededPercent, closeTo(81.25, 0.01));
    });
  });
}
