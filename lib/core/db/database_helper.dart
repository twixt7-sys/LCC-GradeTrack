import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'migrations.dart';

/// Opens `grades.db` and applies versioned migrations.
class DatabaseHelper {
  DatabaseHelper._(this.db);

  final Database db;

  static const fileName = 'grades.db';

  /// [factory] and [path] are injectable for tests (sqflite_common_ffi).
  static Future<DatabaseHelper> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return DatabaseHelper._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    await db.transaction((txn) async {
      for (var v = from + 1; v <= to; v++) {
        for (final sql in migrations[v] ?? const <String>[]) {
          await txn.execute(sql);
        }
        if (v == 1) await _seedDefaults(txn);
      }
    });
  }

  static Future<void> _seedDefaults(Transaction txn) async {
    const s = GradeScale.lccStandard;
    final id = await txn.insert('grade_scales', s.toMap()..remove('id'));
    for (final r in s.rows) {
      await txn.insert('grade_scale_rows', r.toMap(id));
    }
  }

  Future<void> close() => db.close();
}
