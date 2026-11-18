import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/providers/providers.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/primitives.dart';
import 'subject_sheet.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  /// Selected term id; -1 = All; null = current term.
  int? _termId;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const Center(child: CircularProgressIndicator());
    final current = gb.currentTerm;
    final selected = _termId ?? current?.id ?? -1;
    final terms = gb.terms.reversed.toList();
    final q = _search.text.trim().toLowerCase();
    final results =
        gb
            .resultsIn(selected == -1 ? null : selected)
            .where(
              (r) =>
                  q.isEmpty ||
                  r.subject.code.toLowerCase().contains(q) ||
                  r.subject.title.toLowerCase().contains(q) ||
                  r.subject.instructor.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            if (selected == -1) {
              final t = (gb.termById(b.subject.termId)?.order ?? 0).compareTo(
                gb.termById(a.subject.termId)?.order ?? 0,
              );
              if (t != 0) return t;
            }
            return a.subject.code.compareTo(b.subject.code);
          });
    final passing = gb.defaultScale.passingPercent;

    return ListView(
      padding: EdgeInsets.fromLTRB(Gt.pad, 4, Gt.pad, shellBottomPad(context)),
      children: [
        ChipRow<int>(
          values: [for (final t in terms) t.id!, -1],
          selected: selected,
          labelOf: (id) => id == -1 ? 'All' : gb.termById(id)!.shortLabel,
          onChanged: (id) => setState(() => _termId = id),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search code, title, instructor',
              prefixIcon: Icon(Ph.magnifyingGlass, size: 18, color: c.muted),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: Icon(Ph.x, size: 16, color: c.muted),
                      onPressed: () => setState(_search.clear),
                    ),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40),
                borderSide: BorderSide(color: c.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40),
                borderSide: BorderSide(color: c.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40),
                borderSide: BorderSide(color: c.primaryText, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          GtCard(
            child: EmptyState(
              icon: Ph.books,
              title: q.isNotEmpty ? 'No matches' : 'No subjects in this term',
              hint: q.isNotEmpty
                  ? 'Try a subject code like "IT 126".'
                  : 'Use + to add a subject with its units and weights.',
              action: q.isEmpty && selected == current?.id
                  ? 'Add subject'
                  : null,
              onAction: () => openSubjectSheet(context),
            ),
          )
        else
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubjectCard(
                result: r,
                passing: passing,
                termLabel: selected == -1
                    ? gb.termById(r.subject.termId)?.shortLabel
                    : null,
              ),
            ),
        if (results.isNotEmpty && selected != -1) ...[
          const SizedBox(height: 4),
          Center(
            child: Num(
              '${results.length} subjects · ${fmtUnits(results.fold<double>(0, (a, r) => a + r.subject.units))}',
              size: 11,
              color: c.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.result,
    required this.passing,
    this.termLabel,
  });
  final SubjectResult result;
  final double passing;
  final String? termLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final s = result.subject;
    final color = c.standing(result.standing);
    return GtCard(
      onTap: () => context.push('/subject/${s.id}'),
      onLongPress: () => openSubjectSheet(context, existing: s),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              CodeTile(subject: s, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Num(s.code, size: 15, weight: FontWeight.w700),
                    const SizedBox(height: 2),
                    Text(
                      '${s.title} · ${fmtUnits(s.units)}',
                      style: context.tt.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Num(
                result.mark?.code ?? fmtGrade(result.equivalent),
                size: 22,
                weight: FontWeight.w700,
                color: result.mark != null ? c.muted : color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ScaleBar(
            percent: result.percent,
            passing: passing,
            color: result.percent == null
                ? c.faint
                : (result.percent! < passing
                      ? c.red
                      : subjectColor(s.colorIdx)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    ?termLabel,
                    if (s.instructor.isNotEmpty) s.instructor,
                    if (!s.countsInGwa) 'Not in GWA',
                  ].join(' · '),
                  style: context.tt.bodySmall!.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (result.isFinal)
                Text(
                  'Final grade',
                  style: context.tt.labelMedium!.copyWith(
                    color: c.muted,
                    fontSize: 11,
                  ),
                )
              else if (result.percent != null)
                Num(
                  result.inProgress
                      ? '${fmtPct(result.percent)} · ${result.gradedShare.round()}% graded'
                      : fmtPct(result.percent),
                  size: 11,
                  color: c.muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
