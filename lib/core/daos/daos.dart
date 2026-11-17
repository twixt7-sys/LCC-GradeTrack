/// Data access objects (proposal slides 22–24). All SQL is parameterized.
library;

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class ProfileDao {
  ProfileDao(this.db);
  final DatabaseExecutor db;

  Future<Profile?> get() async {
    final rows = await db.query('profile', where: 'id = 1');
    return rows.isEmpty ? null : Profile.fromMap(rows.first);
  }

  Future<void> save(Profile p) => db.insert(
    'profile',
    p.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

class TermDao {
  TermDao(this.db);
  final DatabaseExecutor db;

  Future<List<Term>> all() async {
    final rows = await db.query('terms', orderBy: 'sort_order ASC');
    return rows.map(Term.fromMap).toList();
  }

  Future<int> add(Term t) async {
    final id = await db.insert('terms', t.toMap()..remove('id'));
    if (t.isCurrent) await setCurrent(id);
    return id;
  }

  Future<int> edit(Term t) =>
      db.update('terms', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> setCurrent(int id) async {
    await db.rawUpdate(
      'UPDATE terms SET is_current = CASE WHEN id = ? THEN 1 ELSE 0 END',
      [id],
    );
  }

  Future<int> remove(int id) =>
      db.delete('terms', where: 'id = ?', whereArgs: [id]);
}

class SubjectDao {
  SubjectDao(this.db);
  final DatabaseExecutor db;

  Future<List<Subject>> all() async {
    final rows = await db.query('subjects', orderBy: 'code COLLATE NOCASE ASC');
    return rows.map(Subject.fromMap).toList();
  }

  Future<bool> codeExists(int termId, String code, {int? exceptId}) async {
    final rows = await db.query(
      'subjects',
      columns: ['id'],
      where: 'term_id = ? AND code = ? COLLATE NOCASE AND id != ?',
      whereArgs: [termId, code.trim(), exceptId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> add(Subject s) => db.insert('subjects', s.toMap()..remove('id'));

  Future<int> edit(Subject s) =>
      db.update('subjects', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<int> remove(int id) =>
      db.delete('subjects', where: 'id = ?', whereArgs: [id]);
}

class ComponentDao {
  ComponentDao(this.db);
  final DatabaseExecutor db;

  Future<List<GradeComponent>> all() async {
    final rows = await db.query(
      'components',
      orderBy: 'subject_id, sort_order',
    );
    return rows.map(GradeComponent.fromMap).toList();
  }

  Future<List<GradeComponent>> forSubject(int subjectId) async {
    final rows = await db.query(
      'components',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'sort_order',
    );
    return rows.map(GradeComponent.fromMap).toList();
  }

  Future<int> add(GradeComponent c) =>
      db.insert('components', c.toMap()..remove('id'));

  Future<int> edit(GradeComponent c) =>
      db.update('components', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<int> remove(int id) =>
      db.delete('components', where: 'id = ?', whereArgs: [id]);
}

class ScoreDao {
  ScoreDao(this.db);
  final DatabaseExecutor db;

  Future<List<Score>> all() async {
    final rows = await db.query('scores', orderBy: 'date DESC, id DESC');
    return rows.map(Score.fromMap).toList();
  }

  Future<int> add(Score s) => db.insert('scores', s.toMap()..remove('id'));

  Future<int> edit(Score s) =>
      db.update('scores', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<int> remove(int id) =>
      db.delete('scores', where: 'id = ?', whereArgs: [id]);
}

class ScaleDao {
  ScaleDao(this.db);
  final DatabaseExecutor db;

  Future<List<GradeScale>> all() async {
    final scales = await db.query('grade_scales', orderBy: 'id');
    final rows = await db.query(
      'grade_scale_rows',
      orderBy: 'min_percent DESC',
    );
    return [
      for (final s in scales)
        GradeScale(
          id: s['id']! as int,
          name: s['name']! as String,
          failingEquivalent: (s['failing_equivalent']! as num).toDouble(),
          isDefault: s['is_default'] == 1,
          rows: rows
              .where((r) => r['scale_id'] == s['id'])
              .map(ScaleRow.fromMap)
              .toList(),
        ),
    ];
  }

  /// Inserts or replaces a scale and all its rows.
  Future<int> save(GradeScale s) async {
    int id;
    if (s.id == null) {
      id = await db.insert('grade_scales', s.toMap()..remove('id'));
    } else {
      id = s.id!;
      await db.update(
        'grade_scales',
        s.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'grade_scale_rows',
        where: 'scale_id = ?',
        whereArgs: [id],
      );
    }
    for (final r in s.sorted().rows) {
      await db.insert('grade_scale_rows', r.toMap(id));
    }
    return id;
  }

  Future<int> remove(int id) =>
      db.delete('grade_scales', where: 'id = ?', whereArgs: [id]);
}
