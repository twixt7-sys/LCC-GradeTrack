import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Sample semester from the proposal (slides 10–15): Juan, BSIT, 5 subjects,
/// 14 units. IT 126 = 87.20% → 2.00 and GWA = 1.73. Two past terms give the
/// 2.10 → 1.92 → 1.73 trend.
class SampleData {
  const SampleData._();

  /// Seeds sample data into an empty gradebook. [now] fixes dates for tests.
  static Future<void> seed(
    Database db, {
    DateTime? now,
    bool withProfile = true,
  }) async {
    final today = now ?? DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    DateTime daysAgo(int n) => d0.subtract(Duration(days: n));
    // Next Wednesday (at least 1 day away), for the upcoming midterm.
    var nextWed = d0.add(const Duration(days: 1));
    while (nextWed.weekday != DateTime.wednesday) {
      nextWed = nextWed.add(const Duration(days: 1));
    }
    final stamp = today;

    await db.transaction((txn) async {
      if (withProfile) {
        await txn.insert(
          'profile',
          Profile(
            name: 'Juan Dela Cruz',
            studentNo: '2024-00123',
            program: 'BSIT',
            yearLevel: 2,
            createdAt: stamp,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final scaleId =
          (await txn.query(
                'grade_scales',
                where: 'is_default = 1',
                limit: 1,
              )).firstOrNull?['id']
              as int?;

      Future<int> term(int year, TermKind k, {bool current = false}) async {
        final existing = await txn.query(
          'terms',
          where: 'school_year = ? AND term = ?',
          whereArgs: ['$year-${year + 1}', k.code],
        );
        if (existing.isNotEmpty) return existing.first['id']! as int;
        return txn.insert(
          'terms',
          Term(startYear: year, kind: k, isCurrent: current).toMap()
            ..remove('id'),
        );
      }

      Future<int> subject(
        int termId,
        String code,
        String title,
        double units,
        int color, {
        String instructor = '',
        double? finalGrade,
      }) {
        return txn.insert(
          'subjects',
          Subject(
            termId: termId,
            code: code,
            title: title,
            units: units,
            instructor: instructor,
            colorIdx: color,
            scaleId: scaleId,
            finalGrade: finalGrade,
            createdAt: stamp,
            updatedAt: stamp,
          ).toMap()..remove('id'),
        );
      }

      Future<List<int>> components(int subjectId) async => [
        for (final c in defaultComponentTemplate)
          await txn.insert(
            'components',
            c.copyWith(subjectId: subjectId).toMap()..remove('id'),
          ),
      ];

      Future<void> score(
        int componentId,
        String title,
        double? s,
        double total,
        DateTime date,
      ) => txn.insert(
        'scores',
        Score(
          componentId: componentId,
          title: title,
          score: s,
          total: total,
          date: date,
          createdAt: stamp,
          updatedAt: stamp,
        ).toMap()..remove('id'),
      );

      // Past terms (official final grades).
      final t1 = await term(2025, TermKind.first);
      for (final (i, (code, title, g)) in [
        ('IT 111', 'Introduction to Computing', 2.25),
        ('IT 112', 'Computer Programming 1', 2.00),
        ('GE 1', 'Understanding the Self', 2.25),
        ('GE 2', 'Readings in Philippine History', 2.00),
        ('GE 3', 'The Contemporary World', 2.00),
      ].indexed) {
        await subject(t1, code, title, 3, i, finalGrade: g);
      }
      final t2 = await term(2025, TermKind.second);
      for (final (i, (code, title, g)) in [
        ('IT 121', 'Computer Programming 2', 1.75),
        ('IT 122', 'Discrete Mathematics', 2.00),
        ('CC 102', 'Fundamentals of Programming', 1.75),
        ('GE 5', 'Purposive Communication', 2.25),
        ('GE 6', 'Art Appreciation', 1.75),
        ('IT 124', 'Human Computer Interaction', 2.00),
      ].indexed) {
        await subject(t2, code, title, 3, i + 2, finalGrade: g);
      }

      // Current term.
      final t3 = await term(2026, TermKind.first, current: true);
      await txn.rawUpdate(
        'UPDATE terms SET is_current = CASE WHEN id = ? THEN 1 ELSE 0 END',
        [t3],
      );

      // IT 126: Quizzes 85, Assignments 94, Activities 90, Exams 84 → 87.20.
      final it126 = await subject(
        t3,
        'IT 126',
        'Mobile Development',
        3,
        0,
        instructor: 'Mr. R. Dela Cruz',
      );
      final c = await components(it126);
      await score(c[0], 'Quiz 1 – Dart Basics', 16, 20, daysAgo(40));
      await score(c[0], 'Quiz 2 – Layouts', 17, 20, daysAgo(26));
      await score(c[0], 'Quiz 3 – Flutter Widgets', 18, 20, daysAgo(7));
      await score(c[1], 'Assignment 1 – Wireframes', 47, 50, daysAgo(30));
      await score(c[2], 'Lab 1 – Counter App', 44, 50, daysAgo(33));
      await score(c[2], 'Lab 2 – Navigation', 46, 50, daysAgo(12));
      await score(c[3], 'Prelim Exam', 42, 50, daysAgo(35));
      await score(c[3], 'Midterm Exam', null, 60, nextWed);

      // Other subjects: each component at the subject's target percent.
      Future<void> uniform(
        int subjectId,
        List<(double, double)> perComponent,
        int startDaysAgo,
      ) async {
        final comps = await components(subjectId);
        final names = ['Quiz 1', 'Assignment 1', 'Activity 1', 'Prelim Exam'];
        for (final (i, (s, t)) in perComponent.indexed) {
          await score(comps[i], names[i], s, t, daysAgo(startDaysAgo - i * 6));
        }
      }

      final cc104 = await subject(
        t3,
        'CC 104',
        'Data Structures & Algorithms',
        3,
        1,
        instructor: 'Ms. A. Santos',
      );
      await uniform(cc104, [
        (114, 125),
        (45.6, 50),
        (91.2, 100),
        (114, 125),
      ], 38); // 91.2 → 1.50
      final it123 = await subject(
        t3,
        'IT 123',
        'Web Systems & Technologies',
        3,
        2,
        instructor: 'Mr. J. Reyes',
      );
      await uniform(it123, [
        (89, 100),
        (44.5, 50),
        (89, 100),
        (89, 100),
      ], 36); // 89.0 → 1.75
      final ge4 = await subject(
        t3,
        'GE 4',
        'Mathematics in the Modern World',
        3,
        3,
        instructor: 'Dr. L. Garcia',
      );
      await uniform(ge4, [
        (107, 125),
        (42.8, 50),
        (85.6, 100),
        (107, 125),
      ], 34); // 85.6 → 2.00
      final pe3 = await subject(
        t3,
        'PE 3',
        'Physical Activities',
        2,
        4,
        instructor: 'Coach M. Lim',
      );
      await uniform(pe3, [
        (19, 20),
        (95, 100),
        (47.5, 50),
        (95, 100),
      ], 32); // 95.0 → 1.25
    });
  }
}
