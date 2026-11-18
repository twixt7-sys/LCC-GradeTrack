import 'package:flutter_test/flutter_test.dart';
import 'package:lcc_gradetrack/core/db/database_helper.dart';
import 'package:lcc_gradetrack/core/db/seed_sample.dart';
import 'package:lcc_gradetrack/core/models/models.dart';
import 'package:lcc_gradetrack/core/services/backup_service.dart';
import 'package:lcc_gradetrack/core/services/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late DatabaseHelper helper;
  late GradeRepository repo;
  final now = DateTime(2026, 11, 17);

  setUp(() async {
    helper = await DatabaseHelper.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = GradeRepository(helper);
  });
  tearDown(() => helper.close());

  test('fresh database has the default scale and nothing else', () async {
    final gb = await repo.load();
    expect(gb.profile, isNull);
    expect(gb.terms, isEmpty);
    expect(gb.scales, hasLength(1));
    expect(gb.defaultScale.name, 'LCC Standard');
    expect(gb.defaultScale.rows, hasLength(9));
  });

  test('sample data reproduces the proposal numbers', () async {
    await SampleData.seed(helper.db, now: now);
    final gb = await repo.load();
    final term = gb.currentTerm!;
    expect(term.shortLabel, '1st Sem 26–27');
    final it126 = gb.subjects.firstWhere((s) => s.code == 'IT 126');
    final r = gb.resultOf(it126.id!)!;
    expect(r.percent, closeTo(87.20, 1e-9));
    expect(r.equivalent, 2.00);
    final gwa = gb.termGwa(term.id!);
    expect(gwa.units, 14);
    expect(gwa.gwa!.toStringAsFixed(2), '1.73');
    final prev = gb.previousTerm(term)!;
    expect(gb.termGwa(prev.id!).gwa!.toStringAsFixed(2), '1.92');
    final first = gb.terms.first;
    expect(gb.termGwa(first.id!).gwa!.toStringAsFixed(2), '2.10');
    final up = gb.upcoming(termId: term.id);
    expect(up, hasLength(1));
    expect(up.first.score.title, 'Midterm Exam');
    expect(up.first.score.date.weekday, DateTime.wednesday);
    expect(up.first.component.weight, 40);
  });

  test('subject code is unique per term (case-insensitive)', () async {
    final t = await repo.addTerm(
      const Term(startYear: 2026, kind: TermKind.first, isCurrent: true),
    );
    Subject s(String code) => Subject(
      termId: t,
      code: code,
      title: 'X',
      units: 3,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveSubject(s('IT 126'), defaultComponentTemplate);
    expect(
      () => repo.saveSubject(s('it 126'), defaultComponentTemplate),
      throwsA(isA<DataException>()),
    );
  });

  test('deleting a subject cascades to components and scores', () async {
    await SampleData.seed(helper.db, now: now);
    var gb = await repo.load();
    final it126 = gb.subjects.firstWhere((s) => s.code == 'IT 126');
    final before = gb.scores.length;
    final own = gb.scoresOfSubject(it126.id!).length;
    await repo.deleteSubject(it126.id!);
    gb = await repo.load();
    expect(gb.scores.length, before - own);
    expect(gb.componentsOf(it126.id!), isEmpty);
  });

  test('editing components keeps scores of kept components', () async {
    await SampleData.seed(helper.db, now: now);
    var gb = await repo.load();
    final it126 = gb.subjects.firstWhere((s) => s.code == 'IT 126');
    final comps = gb.componentsOf(it126.id!);
    // Merge Assignments into Activities: drop Assignments, Activities 40.
    final edited = [comps[0], comps[2].copyWith(weight: 40), comps[3]];
    await repo.saveSubject(it126, edited);
    gb = await repo.load();
    expect(gb.componentsOf(it126.id!).map((c) => c.name), [
      'Quizzes',
      'Activities',
      'Exams',
    ]);
    expect(gb.scoresOfComponent(comps[0].id!), hasLength(3));
    expect(gb.scoresOfComponent(comps[1].id!), isEmpty);
  });

  test('database rejects a score above its total', () async {
    await SampleData.seed(helper.db, now: now);
    final gb = await repo.load();
    final c = gb.components.first;
    expect(
      () => repo.saveScore(
        Score(
          componentId: c.id!,
          title: 'Bad',
          score: 21,
          total: 20,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'deleting the current term moves current to the latest remaining',
    () async {
      await SampleData.seed(helper.db, now: now);
      var gb = await repo.load();
      await repo.deleteTerm(gb.currentTerm!.id!);
      gb = await repo.load();
      expect(gb.currentTerm!.kind, TermKind.second);
      expect(gb.currentTerm!.isCurrent, isTrue);
    },
  );

  test('backup round trip restores everything except the PIN', () async {
    await SampleData.seed(helper.db, now: now);
    var gb = await repo.load();
    await repo.saveProfile(
      gb.profile!.copyWith(pinHash: () => 'h', pinSalt: () => 's'),
    );
    final json = await BackupService(helper.db).exportJson(now: now);
    expect(json, isNot(contains('"pin_hash": "h"')));

    await repo.wipe();
    expect((await repo.load()).subjects, isEmpty);

    final parsed = BackupService.parse(json);
    await BackupService(helper.db).restore(parsed);
    gb = await repo.load();
    expect(gb.subjects, hasLength(16));
    expect(gb.profile!.name, 'Juan Dela Cruz');
    expect(gb.profile!.hasPin, isFalse);
    expect(gb.termGwa(gb.currentTerm!.id!).gwa!.toStringAsFixed(2), '1.73');
  });

  test('backup parse rejects foreign files', () {
    expect(
      () => BackupService.parse('not json'),
      throwsA(isA<DataException>()),
    );
    expect(
      () => BackupService.parse('{"app":"other"}'),
      throwsA(isA<DataException>()),
    );
    expect(
      () =>
          BackupService.parse('{"app":"lcc_gradetrack","schema":99,"data":{}}'),
      throwsA(isA<DataException>()),
    );
  });
}
