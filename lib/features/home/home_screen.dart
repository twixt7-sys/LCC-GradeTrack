import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/providers.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/services/gradebook.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/app_tabs.dart';
import '../../shared/widgets/grade_ruler.dart';
import '../../shared/widgets/primitives.dart';
import '../scores/score_sheet.dart';
import '../scores/score_timeline.dart';
import '../subjects/subject_row.dart';
import '../subjects/subject_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gradebookProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load data: $e')),
      data: (gb) => _HomeBody(gb: gb),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.gb});
  final Gradebook gb;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final term = gb.currentTerm;
    final results = gb.resultsIn(term?.id)
      ..sort((a, b) => a.subject.code.compareTo(b.subject.code));
    final passing = gb.defaultScale.passingPercent;
    final now = DateTime.now();
    final upcoming = gb
        .upcoming(termId: term?.id)
        .where((u) => !dayOf(u.score.date).isBefore(dayOf(now)))
        .toList();
    final attention = results
        .where(
          (r) =>
              r.standing == Standing.atRisk || r.standing == Standing.failing,
        )
        .toList();
    final recent = gb.graded(termId: term?.id).take(5).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Gt.pad,
          4,
          Gt.pad,
          shellBottomPad(context),
        ),
        children: [
          _GwaHero(gb: gb),
          const SizedBox(height: 10),
          _StatStrip(results: results),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 10),
            _NextUp(item: upcoming.first, now: now),
          ],
          if (attention.isNotEmpty) ...[
            const SectionLabel('Needs attention'),
            GtCard(
              padding: EdgeInsets.zero,
              borderColor: c.amber.withValues(alpha: 0.5),
              child: Column(
                children: [
                  for (final (i, r) in attention.indexed) ...[
                    if (i > 0) const Divider(),
                    SubjectRow(
                      result: r,
                      passing: passing,
                      onTap: () => context.push('/subject/${r.subject.id}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SectionLabel(
            'Subjects',
            trailing: results.isEmpty ? null : 'See all',
            onTrailing: () => context.go(AppTab.subjects.path),
          ),
          if (results.isEmpty)
            GtCard(
              child: EmptyState(
                icon: PhosphorIconsRegular.books,
                title: 'No subjects yet',
                hint: term == null
                    ? 'Add a term, then your subjects.'
                    : 'Add your ${term.kind.label} subjects with units and grading weights.',
                action: 'Add subject',
                onAction: () => openSubjectSheet(context),
              ),
            )
          else
            GtCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, r) in results.indexed) ...[
                    if (i > 0) const Divider(),
                    SubjectRow(
                      result: r,
                      passing: passing,
                      onTap: () => context.push('/subject/${r.subject.id}'),
                    ),
                  ],
                ],
              ),
            ),
          if (recent.isNotEmpty) ...[
            SectionLabel(
              'Recent scores',
              trailing: 'All scores',
              onTrailing: () => context.go(AppTab.scores.path),
            ),
            ScoreTimeline(
              scores: recent,
              gradebook: gb,
              onTap: (s) => openScoreSheet(context, existing: s),
            ),
          ],
        ],
      ),
    );
  }
}

class _GwaHero extends StatelessWidget {
  const _GwaHero({required this.gb});
  final Gradebook gb;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final term = gb.currentTerm;
    final summary = term == null ? null : gb.termGwa(term.id!);
    final gwa = summary?.gwa;
    final prev = term == null ? null : gb.previousTerm(term);
    final prevGwa = prev == null ? null : gb.termGwa(prev.id!).gwa;
    final delta = (gwa != null && prevGwa != null)
        ? double.parse(gwa.toStringAsFixed(2)) -
              double.parse(prevGwa.toStringAsFixed(2))
        : null;
    final standing = Standing.of(gwa);

    return GtCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'General Weighted Average',
                  style: context.tt.bodySmall,
                ),
              ),
              if (gwa != null) StandingTag(standing, compact: true),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Num(
                fmtGrade(gwa),
                size: 56,
                weight: FontWeight.w700,
                color: gwa == null ? c.faint : c.text,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (delta != null && delta.abs() >= 0.005)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              delta < 0
                                  ? PhosphorIconsBold.arrowDown
                                  : PhosphorIconsBold.arrowUp,
                              size: 13,
                              color: delta < 0 ? c.laurel : c.red,
                            ),
                            const SizedBox(width: 3),
                            Num(
                              delta.abs().toStringAsFixed(2),
                              size: 13,
                              weight: FontWeight.w700,
                              color: delta < 0 ? c.laurel : c.red,
                            ),
                          ],
                        ),
                      if (delta != null && delta.abs() >= 0.005)
                        Text(
                          '${delta < 0 ? 'better' : 'lower'} than ${prev!.kind.label}',
                          style: context.tt.bodySmall!.copyWith(fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            gwa == null
                ? 'Add scores to compute your GWA.'
                : '${fmtUnits(summary!.units)} · ${summary.subjects} ${summary.subjects == 1 ? 'subject' : 'subjects'}${term == null ? '' : ' · ${term.shortLabel}'}',
            style: context.tt.bodySmall,
          ),
          const SizedBox(height: 14),
          GradeRuler(value: gwa, scale: gb.defaultScale),
        ],
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.results});
  final List<SubjectResult> results;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final units = results.fold<double>(0, (a, r) => a + r.subject.units);
    final totalUnits = units == 0 ? 1 : units;
    final graded =
        results.fold<double>(
          0,
          (a, r) => a + (r.isFinal ? 100 : r.gradedShare) * r.subject.units,
        ) /
        totalUnits;
    Widget cell(String label, String value) => Expanded(
      child: Column(
        children: [
          Num(value, size: 17, weight: FontWeight.w700),
          const SizedBox(height: 2),
          Text(label, style: context.tt.bodySmall!.copyWith(fontSize: 11)),
        ],
      ),
    );
    Widget sep() => Container(width: 1, height: 28, color: c.hairline);
    return GtCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          cell('Units', fmtNum(units)),
          sep(),
          cell('Subjects', '${results.length}'),
          sep(),
          cell('Graded', results.isEmpty ? '—' : '${graded.round()}%'),
        ],
      ),
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.item, required this.now});
  final UpcomingItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return GtCard(
      onTap: () => openScoreSheet(context, existing: item.score, record: true),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              PhosphorIconsRegular.calendarDots,
              color: c.amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT UP',
                  style: context.tt.labelSmall!.copyWith(
                    color: c.amber,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.subject.code} ${item.score.title}',
                  style: context.tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${fmtWmd(item.score.date)} · ${fmtNum(item.component.weight)}% of grade (${item.component.name})',
                  style: context.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtRelative(item.score.date, now),
            style: context.tt.labelMedium!.copyWith(color: c.amber),
          ),
        ],
      ),
    );
  }
}
