import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/migrations.dart';
import 'repository.dart';

/// JSON backup: {app, schema, exportedAt, data: {table: rows}}.
/// The PIN hash is never exported.
class BackupService {
  const BackupService(this.db);
  final Database db;

  static const appId = 'lcc_gradetrack';

  /// Insert order respects foreign keys.
  static const tables = [
    'profile',
    'terms',
    'grade_scales',
    'grade_scale_rows',
    'subjects',
    'components',
    'scores',
  ];

  Future<String> exportJson({DateTime? now}) async {
    final data = <String, Object?>{};
    for (final t in tables) {
      final rows = await db.query(t);
      data[t] = t == 'profile'
          ? [
              for (final r in rows)
                {...r, 'pin_hash': null, 'pin_salt': null, 'biometric': 0},
            ]
          : rows;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': appId,
      'schema': schemaVersion,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'data': data,
    });
  }

  /// Parses and checks a backup. Returns row counts per table for confirmation.
  static Map<String, List<Map<String, Object?>>> parse(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const DataException('This file is not a GradeTrack backup.');
    }
    if (decoded is! Map<String, Object?> || decoded['app'] != appId) {
      throw const DataException('This file is not a GradeTrack backup.');
    }
    final schema = decoded['schema'];
    if (schema is! int || schema > schemaVersion) {
      throw const DataException(
        'This backup is from a newer version of the app.',
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const DataException('The backup is damaged.');
    }
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in tables) {
      final rows = data[t];
      if (rows == null) {
        out[t] = const [];
        continue;
      }
      if (rows is! List<Object?>)
        throw const DataException('The backup is damaged.');
      out[t] = [
        for (final r in rows)
          if (r is Map<String, Object?>)
            r
          else
            throw const DataException('The backup is damaged.'),
      ];
    }
    return out;
  }

  /// Replaces all data with [parsed] in one transaction; rolls back on error.
  Future<void> restore(Map<String, List<Map<String, Object?>>> parsed) async {
    try {
      await db.transaction((txn) async {
        for (final t in tables.reversed) {
          await txn.delete(t);
        }
        for (final t in tables) {
          for (final r in parsed[t] ?? const <Map<String, Object?>>[]) {
            await txn.insert(t, r);
          }
        }
        final scales = await txn.query('grade_scales', limit: 1);
        if (scales.isEmpty)
          throw const DataException('The backup has no grade scale.');
      });
    } on DatabaseException {
      throw const DataException('The backup is damaged and was not restored.');
    }
  }
}
