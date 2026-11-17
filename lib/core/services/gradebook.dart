import 'package:collection/collection.dart';

import '../models/models.dart';
import 'grade_calculator.dart';
import 'gwa_service.dart';

/// An upcoming (ungraded) assessment with its context.
class UpcomingItem {
  const UpcomingItem({
    required this.score,
    required this.subject,
    required this.component,
  });
  final Score score;
  final Subject subject;
  final GradeComponent component;
}

/// Immutable snapshot of everything on the device plus computed results.
/// Data volumes are small (hundreds of rows), so a full snapshot keeps the UI
/// simple and every screen consistent after each write.
class Gradebook {
  Gradebook({
    required this.profile,
    required this.terms,
    required this.subjects,
    required this.components,
    required this.scores,
    required this.scales,
    required this.calculator,
  }) {
    _componentsBySubject = groupBy(
      components,
      (GradeComponent c) => c.subjectId!,
    );
    _componentById = {for (final c in components) c.id!: c};
    _subjectById = {for (final s in subjects) s.id!: s};
    _scoresByComponent = groupBy(scores, (Score s) => s.componentId);
    for (final s in subjects) {
      final comps = _componentsBySubject[s.id] ?? const <GradeComponent>[];
      final sc = [for (final c in comps) ...?_scoresByComponent[c.id]];
      _results[s.id!] = calculator.compute(
        subject: s,
        components: comps,
        scores: sc,
        scale: scaleFor(s),
      );
    }
  }

  factory Gradebook.empty() => Gradebook(
    profile: null,
    terms: const [],
    subjects: const [],
    components: const [],
    scores: const [],
    scales: const [GradeScale.lccStandard],
    calculator: const GradeCalculator(),
  );

  final Profile? profile;
  final List<Term> terms;
  final List<Subject> subjects;
  final List<GradeComponent> components;
  final List<Score> scores;
  final List<GradeScale> scales;
  final GradeCalculator calculator;

  late final Map<int, List<GradeComponent>> _componentsBySubject;
  late final Map<int, GradeComponent> _componentById;
  late final Map<int, Subject> _subjectById;
  late final Map<int, List<Score>> _scoresByComponent;
  final Map<int, SubjectResult> _results = {};

  GradeScale get defaultScale =>
      scales.firstWhereOrNull((s) => s.isDefault) ??
      scales.firstOrNull ??
      GradeScale.lccStandard;

  GradeScale scaleFor(Subject s) =>
      scales.firstWhereOrNull((x) => x.id == s.scaleId) ?? defaultScale;

  Term? get currentTerm =>
      terms.firstWhereOrNull((t) => t.isCurrent) ?? terms.lastOrNull;

  Term? termById(int? id) => terms.firstWhereOrNull((t) => t.id == id);

  /// The term chronologically before [t] that has at least one graded subject.
  Term? previousTerm(Term t) => terms
      .where((x) => x.order < t.order && termGwa(x.id!).gwa != null)
      .sortedBy<num>((x) => x.order)
      .lastOrNull;

  Subject? subjectById(int id) => _subjectById[id];
  GradeComponent? componentById(int id) => _componentById[id];
  List<GradeComponent> componentsOf(int subjectId) =>
      (_componentsBySubject[subjectId] ?? const <GradeComponent>[])
          .sortedBy<num>((c) => c.sortOrder);
  List<Score> scoresOfComponent(int componentId) =>
      _scoresByComponent[componentId] ?? const [];
  List<Score> scoresOfSubject(int subjectId) => [
    for (final c in componentsOf(subjectId)) ...scoresOfComponent(c.id!),
  ];

  Subject? subjectOfScore(Score s) {
    final c = _componentById[s.componentId];
    return c == null ? null : _subjectById[c.subjectId];
  }

  SubjectResult? resultOf(int subjectId) => _results[subjectId];

  List<Subject> subjectsIn(int? termId) => termId == null
      ? subjects
      : subjects.where((s) => s.termId == termId).toList();

  List<SubjectResult> resultsIn(int? termId) => [
    for (final s in subjectsIn(termId)) _results[s.id]!,
  ];

  GwaSummary termGwa(int termId) => GwaService.compute(resultsIn(termId));

  GwaSummary get cumulativeGwa => GwaService.compute(_results.values);

  double get unitsEarned => GwaService.unitsEarned(
    _results.values.where((r) => r.isFinal || !r.inProgress),
    passingEquivalent: defaultScale.passingEquivalent,
  );

  /// Ungraded assessments in [termId] (all terms when null), soonest first.
  List<UpcomingItem> upcoming({int? termId}) {
    final ids = subjectsIn(termId).map((s) => s.id).toSet();
    return [
      for (final s in scores.where((s) => s.isUpcoming))
        if (_componentById[s.componentId] case final c?)
          if (ids.contains(c.subjectId))
            UpcomingItem(
              score: s,
              subject: _subjectById[c.subjectId]!,
              component: c,
            ),
    ]..sort((a, b) => a.score.date.compareTo(b.score.date));
  }

  /// Graded scores in [termId], newest first.
  List<Score> graded({int? termId}) {
    final ids = subjectsIn(termId).map((s) => s.id).toSet();
    return scores
        .where(
          (s) =>
              !s.isUpcoming &&
              ids.contains(_componentById[s.componentId]?.subjectId),
        )
        .sorted((a, b) {
          final d = b.date.compareTo(a.date);
          return d != 0 ? d : (b.id ?? 0).compareTo(a.id ?? 0);
        });
  }

  /// Upcoming assessments due within [days] days from [now] (inclusive), excluding overdue.
  int dueSoonCount(DateTime now, {int days = 7, int? termId}) {
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: days));
    return upcoming(termId: termId)
        .where(
          (u) => !u.score.date.isBefore(today) && !u.score.date.isAfter(end),
        )
        .length;
  }
}
