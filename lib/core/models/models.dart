/// Plain Dart models with toMap()/fromMap() for sqflite (proposal slide 24).
library;

import 'package:collection/collection.dart';

DateTime _date(Object? v) => DateTime.parse(v! as String);
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
double? _dbl(Object? v) => v == null ? null : (v as num).toDouble();
bool _bool(Object? v) => v == 1 || v == true;

/// Single local profile (replaces register/login; see plan "Accounts").
class Profile {
  const Profile({
    this.id = 1,
    required this.name,
    this.studentNo = '',
    this.program = '',
    this.yearLevel = 1,
    this.pinHash,
    this.pinSalt,
    this.biometric = false,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String studentNo;
  final String program;
  final int yearLevel;
  final String? pinHash;
  final String? pinSalt;
  final bool biometric;
  final DateTime createdAt;

  bool get hasPin => pinHash != null && pinSalt != null;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'student_no': studentNo,
    'program': program,
    'year_level': yearLevel,
    'pin_hash': pinHash,
    'pin_salt': pinSalt,
    'biometric': biometric ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory Profile.fromMap(Map<String, Object?> m) => Profile(
    id: m['id']! as int,
    name: m['name']! as String,
    studentNo: (m['student_no'] as String?) ?? '',
    program: (m['program'] as String?) ?? '',
    yearLevel: (m['year_level'] as int?) ?? 1,
    pinHash: m['pin_hash'] as String?,
    pinSalt: m['pin_salt'] as String?,
    biometric: _bool(m['biometric']),
    createdAt: _date(m['created_at']),
  );

  Profile copyWith({
    String? name,
    String? studentNo,
    String? program,
    int? yearLevel,
    String? Function()? pinHash,
    String? Function()? pinSalt,
    bool? biometric,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    studentNo: studentNo ?? this.studentNo,
    program: program ?? this.program,
    yearLevel: yearLevel ?? this.yearLevel,
    pinHash: pinHash != null ? pinHash() : this.pinHash,
    pinSalt: pinSalt != null ? pinSalt() : this.pinSalt,
    biometric: biometric ?? this.biometric,
    createdAt: createdAt,
  );
}

enum TermKind {
  first('1st', '1st Sem'),
  second('2nd', '2nd Sem'),
  summer('Summer', 'Summer');

  const TermKind(this.code, this.label);
  final String code;
  final String label;

  static TermKind fromCode(String c) => TermKind.values.firstWhere(
    (k) => k.code == c,
    orElse: () => TermKind.first,
  );
}

/// A semester within a school year, e.g. 1st Sem, AY 2026–2027.
class Term {
  const Term({
    this.id,
    required this.startYear,
    required this.kind,
    this.isCurrent = false,
  });

  final int? id;

  /// First year of the school year: 2026 for AY 2026–2027.
  final int startYear;
  final TermKind kind;
  final bool isCurrent;

  String get schoolYear => '$startYear-${startYear + 1}';
  String get ayLabel => 'AY $startYear–${(startYear + 1) % 100}';
  String get ayLong => 'AY $startYear–${startYear + 1}';
  String get shortLabel =>
      '${kind.label} ${startYear % 100}–${(startYear + 1) % 100}';
  String get longLabel => '${kind.label} · $ayLong';

  /// Chronological sort key.
  int get order => startYear * 10 + kind.index;

  Map<String, Object?> toMap() => {
    'id': id,
    'school_year': schoolYear,
    'term': kind.code,
    'is_current': isCurrent ? 1 : 0,
    'sort_order': order,
  };

  factory Term.fromMap(Map<String, Object?> m) => Term(
    id: m['id']! as int,
    startYear: int.parse((m['school_year']! as String).split('-').first),
    kind: TermKind.fromCode(m['term']! as String),
    isCurrent: _bool(m['is_current']),
  );

  Term copyWith({int? startYear, TermKind? kind, bool? isCurrent}) => Term(
    id: id,
    startYear: startYear ?? this.startYear,
    kind: kind ?? this.kind,
    isCurrent: isCurrent ?? this.isCurrent,
  );
}

enum AvgMethod {
  /// Mean of each item's percentage (proposal slide 14).
  meanPercent('mean', 'Average of percentages'),

  /// Sum of scores over sum of totals.
  totalPoints('points', 'Total points');

  const AvgMethod(this.code, this.label);
  final String code;
  final String label;
  static AvgMethod fromCode(String? c) => AvgMethod.values.firstWhere(
    (m) => m.code == c,
    orElse: () => meanPercent,
  );
}

/// Registrar marks that replace a numeric grade and are excluded from GWA.
enum FinalMark {
  inc('INC', 'Incomplete'),
  drp('DRP', 'Dropped'),
  w('W', 'Withdrawn');

  const FinalMark(this.code, this.label);
  final String code;
  final String label;
  static FinalMark? fromCode(String? c) =>
      FinalMark.values.firstWhereOrNull((m) => m.code == c);
}

class Subject {
  const Subject({
    this.id,
    required this.termId,
    required this.code,
    required this.title,
    required this.units,
    this.instructor = '',
    this.colorIdx = 0,
    this.scaleId,
    this.avgMethod = AvgMethod.meanPercent,
    this.countsInGwa = true,
    this.finalGrade,
    this.finalMark,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int termId;
  final String code;
  final String title;
  final double units;
  final String instructor;
  final int colorIdx;
  final int? scaleId;
  final AvgMethod avgMethod;
  final bool countsInGwa;

  /// Official grade from the registrar; overrides the computed equivalent.
  final double? finalGrade;
  final FinalMark? finalMark;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "IT 126" -> ("IT", "126"). Used by the code tile.
  (String, String) get codeParts {
    final t = code.trim();
    final m = RegExp(r'^([A-Za-z]+)\s*(.*)$').firstMatch(t);
    if (m == null) return (t, '');
    return (m.group(1)!.toUpperCase(), m.group(2)!.trim());
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'term_id': termId,
    'code': code.trim(),
    'title': title.trim(),
    'units': units,
    'instructor': instructor.trim(),
    'color_idx': colorIdx,
    'scale_id': scaleId,
    'avg_method': avgMethod.code,
    'counts_in_gwa': countsInGwa ? 1 : 0,
    'final_grade': finalGrade,
    'final_mark': finalMark?.code,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Subject.fromMap(Map<String, Object?> m) => Subject(
    id: m['id']! as int,
    termId: m['term_id']! as int,
    code: m['code']! as String,
    title: m['title']! as String,
    units: _dbl(m['units'])!,
    instructor: (m['instructor'] as String?) ?? '',
    colorIdx: (m['color_idx'] as int?) ?? 0,
    scaleId: m['scale_id'] as int?,
    avgMethod: AvgMethod.fromCode(m['avg_method'] as String?),
    countsInGwa: _bool(m['counts_in_gwa']),
    finalGrade: _dbl(m['final_grade']),
    finalMark: FinalMark.fromCode(m['final_mark'] as String?),
    createdAt: _date(m['created_at']),
    updatedAt: _date(m['updated_at']),
  );

  Subject copyWith({
    int? termId,
    String? code,
    String? title,
    double? units,
    String? instructor,
    int? colorIdx,
    int? Function()? scaleId,
    AvgMethod? avgMethod,
    bool? countsInGwa,
    double? Function()? finalGrade,
    FinalMark? Function()? finalMark,
    DateTime? updatedAt,
  }) => Subject(
    id: id,
    termId: termId ?? this.termId,
    code: code ?? this.code,
    title: title ?? this.title,
    units: units ?? this.units,
    instructor: instructor ?? this.instructor,
    colorIdx: colorIdx ?? this.colorIdx,
    scaleId: scaleId != null ? scaleId() : this.scaleId,
    avgMethod: avgMethod ?? this.avgMethod,
    countsInGwa: countsInGwa ?? this.countsInGwa,
    finalGrade: finalGrade != null ? finalGrade() : this.finalGrade,
    finalMark: finalMark != null ? finalMark() : this.finalMark,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

/// A weighted grading component of a subject, e.g. Quizzes 20%.
class GradeComponent {
  const GradeComponent({
    this.id,
    this.subjectId,
    required this.name,
    required this.weight,
    this.sortOrder = 0,
  });

  final int? id;
  final int? subjectId;
  final String name;

  /// Percent of the subject grade, 0–100.
  final double weight;
  final int sortOrder;

  Map<String, Object?> toMap() => {
    'id': id,
    'subject_id': subjectId,
    'name': name.trim(),
    'weight': weight,
    'sort_order': sortOrder,
  };

  factory GradeComponent.fromMap(Map<String, Object?> m) => GradeComponent(
    id: m['id']! as int,
    subjectId: m['subject_id']! as int,
    name: m['name']! as String,
    weight: _dbl(m['weight'])!,
    sortOrder: (m['sort_order'] as int?) ?? 0,
  );

  GradeComponent copyWith({
    int? id,
    int? subjectId,
    String? name,
    double? weight,
    int? sortOrder,
  }) => GradeComponent(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    name: name ?? this.name,
    weight: weight ?? this.weight,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, Object?> toTemplate() => {'name': name, 'weight': weight};
  factory GradeComponent.fromTemplate(Map<String, Object?> m, int i) =>
      GradeComponent(
        name: m['name']! as String,
        weight: _dbl(m['weight'])!,
        sortOrder: i,
      );
}

/// A recorded score, or an upcoming assessment when [score] is null.
class Score {
  const Score({
    this.id,
    required this.componentId,
    required this.title,
    this.score,
    required this.total,
    required this.date,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int componentId;
  final String title;
  final double? score;
  final double total;
  final DateTime date;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUpcoming => score == null;
  double? get percent =>
      score == null || total <= 0 ? null : score! / total * 100;

  Map<String, Object?> toMap() => {
    'id': id,
    'component_id': componentId,
    'title': title.trim(),
    'score': score,
    'total': total,
    'date': _dateOnly(date),
    'note': note.trim(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Score.fromMap(Map<String, Object?> m) => Score(
    id: m['id']! as int,
    componentId: m['component_id']! as int,
    title: m['title']! as String,
    score: _dbl(m['score']),
    total: _dbl(m['total'])!,
    date: _date(m['date']),
    note: (m['note'] as String?) ?? '',
    createdAt: _date(m['created_at']),
    updatedAt: _date(m['updated_at']),
  );

  Score copyWith({
    int? componentId,
    String? title,
    double? Function()? score,
    double? total,
    DateTime? date,
    String? note,
  }) => Score(
    id: id,
    componentId: componentId ?? this.componentId,
    title: title ?? this.title,
    score: score != null ? score() : this.score,
    total: total ?? this.total,
    date: date ?? this.date,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

class ScaleRow {
  const ScaleRow({required this.minPercent, required this.equivalent});
  final double minPercent;
  final double equivalent;

  Map<String, Object?> toMap(int scaleId) => {
    'scale_id': scaleId,
    'min_percent': minPercent,
    'equivalent': equivalent,
  };

  factory ScaleRow.fromMap(Map<String, Object?> m) => ScaleRow(
    minPercent: _dbl(m['min_percent'])!,
    equivalent: _dbl(m['equivalent'])!,
  );
}

/// Percent → 1.00–5.00 conversion table (proposal slide 14).
class GradeScale {
  const GradeScale({
    this.id,
    required this.name,
    required this.rows,
    this.failingEquivalent = 5.0,
    this.isDefault = false,
  });

  final int? id;
  final String name;

  /// Rows sorted by [ScaleRow.minPercent] descending.
  final List<ScaleRow> rows;
  final double failingEquivalent;
  final bool isDefault;

  /// Lowest passing percent (the min of the last row).
  double get passingPercent => rows.isEmpty ? 75 : rows.last.minPercent;

  /// Lowest passing equivalent, e.g. 3.00.
  double get passingEquivalent => rows.isEmpty ? 3.0 : rows.last.equivalent;

  double? minPercentFor(double equivalent) => rows
      .firstWhereOrNull((r) => (r.equivalent - equivalent).abs() < 1e-9)
      ?.minPercent;

  GradeScale sorted() => GradeScale(
    id: id,
    name: name,
    failingEquivalent: failingEquivalent,
    isDefault: isDefault,
    rows: [...rows]..sort((a, b) => b.minPercent.compareTo(a.minPercent)),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'failing_equivalent': failingEquivalent,
    'is_default': isDefault ? 1 : 0,
  };

  /// LCC default; slides omit 2.75, added here at 76%.
  static const lccStandard = GradeScale(
    name: 'LCC Standard',
    isDefault: true,
    rows: [
      ScaleRow(minPercent: 97, equivalent: 1.00),
      ScaleRow(minPercent: 94, equivalent: 1.25),
      ScaleRow(minPercent: 91, equivalent: 1.50),
      ScaleRow(minPercent: 88, equivalent: 1.75),
      ScaleRow(minPercent: 85, equivalent: 2.00),
      ScaleRow(minPercent: 82, equivalent: 2.25),
      ScaleRow(minPercent: 79, equivalent: 2.50),
      ScaleRow(minPercent: 76, equivalent: 2.75),
      ScaleRow(minPercent: 75, equivalent: 3.00),
    ],
  );
}

/// Default component template (proposal slide 14).
const defaultComponentTemplate = <GradeComponent>[
  GradeComponent(name: 'Quizzes', weight: 20, sortOrder: 0),
  GradeComponent(name: 'Assignments', weight: 15, sortOrder: 1),
  GradeComponent(name: 'Activities', weight: 25, sortOrder: 2),
  GradeComponent(name: 'Exams', weight: 40, sortOrder: 3),
];

String dateOnly(DateTime d) => _dateOnly(d);
