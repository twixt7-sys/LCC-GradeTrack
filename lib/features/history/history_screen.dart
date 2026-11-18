import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';
import '../subjects/subject_row.dart';
import 'term_sheet.dart';

/// Past and current terms with their GWA (performance history).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const Center(child: CircularProgressIndicator());
    final cum = gb.cumulativeGwa;
    final terms = gb.terms.reversed.toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(Gt.pad, 4, Gt.pad, shellBottomPad(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Cumulative GWA',
                value: fmtGrade(cum.gwa),
                valueColor: c.primaryText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Units earned',
                value: fmtNum(gb.unitsEarned),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(label: 'Terms', value: '${terms.length}'),
            ),
          ],
        ),
        const SectionLabel('Terms'),
        if (terms.isEmpty)
          GtCard(
            child: EmptyState(
              icon: Ph.calendarPlus,
              title: 'No terms yet',
              hint: 'Add a semester to start tracking.',
              action: 'Add term',
              onAction: () => openTermSheet(context),
            ),
          ),
        for (final t in terms)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(
              builder: (context) {
                final g = gb.termGwa(t.id!);
                final subjects = gb.subjectsIn(t.id);
                final units = subjects.fold<double>(0, (a, s) => a + s.units);
                return GtCard(
                  onTap: () => context.push('/term/${t.id}'),
                  onLongPress: () => openTermSheet(context, existing: t),
                  borderColor: t.isCurrent
                      ? c.primary.withValues(alpha: 0.6)
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  t.kind.label,
                                  style: context.tt.titleMedium,
                                ),
                                if (t.isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.primarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: context.tt.labelSmall!.copyWith(
                                        color: c.primaryText,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Num(t.ayLong, size: 12, color: c.muted),
                            const SizedBox(height: 6),
                            Text(
                              '${subjects.length} ${subjects.length == 1 ? 'subject' : 'subjects'} · ${fmtUnits(units)}',
                              style: context.tt.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Num(
                            fmtGrade(g.gwa),
                            size: 26,
                            weight: FontWeight.w700,
                            color: g.gwa == null ? c.faint : c.text,
                          ),
                          Text(
                            'GWA',
                            style: context.tt.bodySmall!.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Read-only view of one term with actions.
class TermDetailScreen extends ConsumerWidget {
  const TermDetailScreen({super.key, required this.termId});
  final int termId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    final t = gb?.termById(termId);
    if (gb == null || t == null) {
      return const PageScaffold(title: 'Term', children: []);
    }
    final results = gb.resultsIn(t.id)
      ..sort((a, b) => a.subject.code.compareTo(b.subject.code));
    final g = gb.termGwa(t.id!);
    return PageScaffold(
      title: t.kind.label,
      subtitle: t.ayLong,
      actions: [
        IconButton(
          tooltip: 'Edit term',
          onPressed: () => openTermSheet(context, existing: t),
          icon: const Icon(Ph.pencilSimple),
        ),
      ],
      children: [
        GtCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Term GWA', style: context.tt.bodySmall),
                    Num(fmtGrade(g.gwa), size: 40, weight: FontWeight.w700),
                    Text(
                      '${fmtUnits(g.units)} counted · ${g.subjects} of ${results.length} subjects',
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!t.isCurrent)
                OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(gradebookProvider.notifier)
                        .mutate((r) => r.setCurrentTerm(t.id!));
                    if (context.mounted) {
                      showToast(
                        context,
                        '${t.shortLabel} is now the current term',
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Make current'),
                ),
            ],
          ),
        ),
        const SectionLabel('Subjects'),
        if (results.isEmpty)
          Text('No subjects in this term.', style: context.tt.bodySmall)
        else
          GtCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, r) in results.indexed) ...[
                  if (i > 0) const Divider(),
                  SubjectRow(
                    result: r,
                    passing: gb.defaultScale.passingPercent,
                    onTap: () => context.push('/subject/${r.subject.id}'),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          'Tip: set the registrar\'s final grade from a subject\'s menu once grades are released.',
          style: context.tt.bodySmall!.copyWith(color: c.faint),
        ),
      ],
    );
  }
}
