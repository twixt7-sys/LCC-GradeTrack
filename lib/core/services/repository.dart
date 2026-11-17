import 'package:sqflite/sqflite.dart';

import '../daos/daos.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import 'grade_calculator.dart';
import 'gradebook.dart';

/// Thrown for user-facing data errors (shown in a toast).
class DataException implements Exception {
  const DataException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Logic layer over the DAOs. Multi-row writes run in a transaction.
class GradeRepository {
  GradeRepository(this.helper);
  final DatabaseHelper helper;

  Database get db => helper.db;

  Future<Gradebook> load({
    RoundingRule rounding = RoundingRule.twoDecimals,
  }) async {
    final results = await Future.wait([
      ProfileDao(db).get(),
      TermDao(db).all(),
      SubjectDao(db).all(),
      ComponentDao(db).all(),
      ScoreDao(db).all(),
      ScaleDao(db).all(),
    ]);
    return Gradebook(
      profile: results[0] as Profile?,
      terms: results[1]! as List<Term>,
      subjects: results[2]! as List<Subject>,
      components: results[3]! as List<GradeComponent>,
      scores: results[4]! as List<Score>,
      scales: results[5]! as List<GradeScale>,
      calculator: GradeCalculator(rounding: rounding),
    );
  }

  // Profile
  Future<void> saveProfile(Profile p) => ProfileDao(db).save(p);

  // Terms
  Future<int> addTerm(Term t) async {
    try {
      return await db.transaction((txn) => TermDao(txn).add(t));
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const DataException('That term already exists.');
      }
      rethrow;
    }
  }

  Future<void> editTerm(Term t) async {
    try {
      await db.transaction((txn) async {
        await TermDao(txn).edit(t);
        if (t.isCurrent) await TermDao(txn).setCurrent(t.id!);
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const DataException('That term already exists.');
      }
      rethrow;
    }
  }

  Future<void> setCurrentTerm(int id) => TermDao(db).setCurrent(id);

  Future<void> deleteTerm(int id) => db.transaction((txn) async {
    final wasCurrent = (await txn.query(
      'terms',
      where: 'id = ? AND is_current = 1',
      whereArgs: [id],
    )).isNotEmpty;
    await TermDao(txn).remove(id);
    if (wasCurrent) {
      final rest = await TermDao(txn).all();
      if (rest.isNotEmpty) await TermDao(txn).setCurrent(rest.last.id!);
    }
  });

  // Subjects
  Future<int> saveSubject(Subject s, List<GradeComponent> components) async {
    if (await SubjectDao(db).codeExists(s.termId, s.code, exceptId: s.id)) {
      throw DataException('${s.code.trim()} already exists in this term.');
    }
    return db.transaction((txn) async {
      final sdao = SubjectDao(txn);
      final cdao = ComponentDao(txn);
      final id = s.id ?? await sdao.add(s);
      if (s.id != null) await sdao.edit(s);
      final existing = await cdao.forSubject(id);
      final keep = components
          .where((c) => c.id != null)
          .map((c) => c.id)
          .toSet();
      for (final old in existing) {
        if (!keep.contains(old.id)) await cdao.remove(old.id!);
      }
      for (final (i, c) in components.indexed) {
        final row = c.copyWith(subjectId: id, sortOrder: i);
        if (c.id == null) {
          await cdao.add(row);
        } else {
          await cdao.edit(row);
        }
      }
      return id;
    });
  }

  Future<void> updateSubjectOnly(Subject s) => SubjectDao(db).edit(s);

  Future<void> deleteSubject(int id) => SubjectDao(db).remove(id);

  // Scores
  Future<int> saveScore(Score s) async {
    final dao = ScoreDao(db);
    if (s.id == null) return dao.add(s);
    await dao.edit(s);
    return s.id!;
  }

  Future<void> deleteScore(int id) => ScoreDao(db).remove(id);

  // Scales
  Future<int> saveScale(GradeScale s) =>
      db.transaction((txn) => ScaleDao(txn).save(s));

  /// Deletes every record and restores the default scale.
  Future<void> wipe() => db.transaction((txn) async {
    for (final t in [
      'scores',
      'components',
      'subjects',
      'terms',
      'grade_scale_rows',
      'grade_scales',
      'profile',
    ]) {
      await txn.delete(t);
    }
    await ScaleDao(txn).save(GradeScale.lccStandard);
  });
}
