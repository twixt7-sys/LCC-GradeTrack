import 'package:collection/collection.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/services/gradebook.dart';
import '../../core/services/target_solver.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';
import '../scores/score_sheet.dart';
import 'subject_sheet.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});
  final int subjectId;

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

enum _Tab { scores, breakdown }

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  _Tab _tab = _Tab.scores;

  Future<void> _menu(String v, Gradebook gb, Subject s) async {
    switch (v) {
      case 'edit':
        await openSubjectSheet(context, existing: s);
      case 'final':
        await showFormSheet<void>(context, (_) => _FinalGradeSheet(subject: s));
      case 'delete':
        final n = gb.scoresOfSubject(s.id!).length;
        final ok = await confirmAction(
          context,
          title: 'Delete ${s.code}?',
          body: n == 0
              ? 'The subject and its components will be removed.'
              : 'This also deletes its $n ${n == 1 ? 'score' : 'scores'}.',
        );
        if (!ok || !mounted) return;
        Navigator.of(context).pop();
        await ref
            .read(gradebookProvider.notifier)
            .mutate((r) => r.deleteSubject(s.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gb = ref.watch(gradebookProvider).value;
    final s = gb?.subjectById(widget.subjectId);
    if (gb == null || s == null) {
      return const PageScaffold(
        title: 'Subject',
        children: [SizedBox(height: 200)],
      );
    }
    final r = gb.resultOf(s.id!)!;
    final scale = gb.scaleFor(s);
    final term = gb.termById(s.termId);

    return PageScaffold(
      title: s.code,
      subtitle: s.title,
      actions: [
        IconButton(
          tooltip: 'Add score',
          onPressed: () => openScoreSheet(context, subjectId: s.id),
          icon: const Icon(PhosphorIconsRegular.plus),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
          onSelected: (v) => _menu(v, gb, s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit subject')),
            PopupMenuItem(value: 'final', child: Text('Set final grade')),
            PopupMenuItem(value: 'delete', child: Text('Delete subject')),
          ],
        ),
      ],
      children: [
        _GradeCard(result: r, scale: scale),
        const SizedBox(height: 8),
        Text(
          [
            fmtUnits(s.units),
            if (s.instructor.isNotEmpty) s.instructor,
            if (term != null) term.shortLabel,
            if (!s.countsInGwa) 'Not in GWA',
          ].join(' · '),
          style: context.tt.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        CapsuleSelector<_Tab>(
          values: _Tab.values,
          selected: _tab,
          labelOf: (t) => t == _Tab.scores ? 'Scores' : 'Breakdown',
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 4),
        if (_tab == _Tab.scores)
          _ScoresTab(gb: gb, result: r)
        else
          _BreakdownTab(gb: gb, result: r, scale: scale),
      ],
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.result, required this.scale});
  final SubjectResult result;
  final GradeScale scale;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final r = result;
    final passed =
        r.equivalent != null && r.equivalent! <= scale.passingEquivalent + 1e-9;
    String label;
    if (r.mark != null) {
      label = r.mark!.label;
    } else if (r.isFinal) {
      label = 'Final grade';
    } else if (r.percent == null) {
      label = 'No scores yet';
    } else {
      label = r.inProgress
          ? 'Current grade · based on ${r.gradedShare.round()}% of grade'
          : 'Current grade';
    }
    return GtCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          Text(label, style: context.tt.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Num(
            r.mark?.code ??
                (r.isFinal ? fmtGrade(r.equivalent) : fmtPct(r.percent)),
            size: 46,
            weight: FontWeight.w700,
            color: r.percent == null && !r.isFinal ? c.faint : c.text,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (r.equivalent != null && !r.isFinal)
                _Pill(
                  text: 'Equivalent ${fmtGrade(r.equivalent)}',
                  color: c.text,
                ),
              if (r.isFinal && r.percent != null)
                _Pill(text: 'Computed ${fmtPct(r.percent)}', color: c.muted),
              if (r.equivalent != null)
                _Pill(
                  text: passed
                      ? (r.inProgress ? 'Passing' : 'Passed')
                      : (r.inProgress ? 'Below passing' : 'Failed'),
                  color: passed ? c.laurel : c.red,
                  icon: passed ? PhosphorIconsBold.check : PhosphorIconsBold.x,
                ),
              if (r.equivalent != null) StandingTag(r.standing, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: ShapeDecoration(
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(text, style: context.tt.labelMedium!.copyWith(color: color)),
      ],
    ),
  );
}

class _ScoresTab extends StatelessWidget {
  const _ScoresTab({required this.gb, required this.result});
  final Gradebook gb;
  final SubjectResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final s = result.subject;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cr in result.components) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
            child: Row(
              children: [
                Text(
                  cr.component.name.toUpperCase(),
                  style: context.tt.labelSmall,
                ),
                const SizedBox(width: 6),
                Num(
                  '${fmtNum(cr.component.weight)}%',
                  size: 10.5,
                  color: c.faint,
                ),
                const Spacer(),
                if (cr.average != null)
                  Num(
                    'Avg ${fmtPct(cr.average)}',
                    size: 12,
                    weight: FontWeight.w700,
                    color: c.primaryText,
                  ),
                IconButton(
                  tooltip: 'Add ${singular(cr.component.name).toLowerCase()}',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => openScoreSheet(
                    context,
                    subjectId: s.id,
                    componentId: cr.component.id,
                  ),
                  icon: Icon(
                    PhosphorIconsRegular.plusCircle,
                    size: 20,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final items = gb
                  .scoresOfComponent(cr.component.id!)
                  .sorted((a, b) => a.date.compareTo(b.date));
              if (items.isEmpty) {
                return GtCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Text(
                    'No ${cr.component.name.toLowerCase()} yet.',
                    style: context.tt.bodySmall,
                  ),
                );
              }
              return GtCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, sc) in items.indexed) ...[
                      if (i > 0) const Divider(),
                      InkWell(
                        onTap: () => openScoreSheet(context, existing: sc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sc.title,
                                      style: context.tt.titleSmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      sc.isUpcoming
                                          ? 'Due ${fmtWmd(sc.date)} · ${fmtNum(sc.total)} items'
                                          : '${fmtNum(sc.score)}/${fmtNum(sc.total)} items · ${fmtMd(sc.date)}',
                                      style: context.tt.bodySmall!.copyWith(
                                        color: sc.isUpcoming
                                            ? c.amber
                                            : c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (sc.isUpcoming)
                                Icon(
                                  PhosphorIconsRegular.hourglass,
                                  size: 18,
                                  color: c.amber,
                                )
                              else
                                Num(
                                  fmtPct(
                                    sc.percent,
                                    dp:
                                        sc.percent! ==
                                            sc.percent!.roundToDouble()
                                        ? 0
                                        : 1,
                                  ),
                                  size: 15,
                                  weight: FontWeight.w700,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _BreakdownTab extends StatefulWidget {
  const _BreakdownTab({
    required this.gb,
    required this.result,
    required this.scale,
  });
  final Gradebook gb;
  final SubjectResult result;
  final GradeScale scale;

  @override
  State<_BreakdownTab> createState() => _BreakdownTabState();
}

class _BreakdownTabState extends State<_BreakdownTab> {
  double? _target;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final r = widget.result;
    final scale = widget.scale.sorted();
    final gb = widget.gb;
    final s = r.subject;
    final targets = [for (final row in scale.rows) row.equivalent];
    final current = r.equivalent;
    // Default target: one step better than now, or the passing grade.
    _target ??= current == null
        ? scale.passingEquivalent
        : (targets.where((t) => t < current - 1e-9).lastOrNull ??
              targets.first);

    final solver = TargetSolver(gb.calculator);
    final target = solver.solve(
      subject: s,
      components: gb.componentsOf(s.id!),
      scores: gb.scoresOfSubject(s.id!),
      scale: scale,
      targetEquivalent: _target!,
    );
    final totalPoints = r.components.fold<double>(
      0,
      (a, cr) => a + (cr.points ?? 0),
    );

    final TextStyle head = context.tt.bodySmall!.copyWith(fontSize: 11.5);
    Widget cell(
      String t, {
      TextAlign align = TextAlign.right,
      bool bold = false,
      Color? color,
      bool isMono = true,
    }) => Text(
      t,
      textAlign: align,
      style: isMono
          ? mono(
              13,
              weight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? c.text,
            )
          : context.tt.titleSmall!.copyWith(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        GtCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  Text('Component', style: head),
                  Text('Weight', style: head, textAlign: TextAlign.right),
                  Text('Avg', style: head, textAlign: TextAlign.right),
                  Text('Points', style: head, textAlign: TextAlign.right),
                ],
              ),
              for (final cr in r.components)
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.hairline)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: cell(
                        cr.component.name,
                        align: TextAlign.left,
                        isMono: false,
                      ),
                    ),
                    cell('${fmtNum(cr.component.weight)}%'),
                    cell(
                      cr.average == null ? '—' : cr.average!.toStringAsFixed(1),
                      color: cr.average == null ? c.faint : null,
                    ),
                    cell(
                      cr.points == null ? '—' : cr.points!.toStringAsFixed(2),
                      bold: true,
                      color: cr.points == null ? c.faint : null,
                    ),
                  ],
                ),
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.hairline)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: cell('Total', align: TextAlign.left, isMono: false),
                  ),
                  cell(
                    '${fmtNum(r.totalWeight)}%',
                    color: Validators.weightsComplete([r.totalWeight])
                        ? null
                        : c.amber,
                  ),
                  const SizedBox(),
                  cell(
                    r.percent == null
                        ? '—'
                        : (r.inProgress
                              ? totalPoints.toStringAsFixed(2)
                              : r.percent!.toStringAsFixed(2)),
                    bold: true,
                    color: c.primaryText,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(Gt.radiusSm + 2),
          ),
          child: Text(
            r.inProgress
                ? 'grade = Σ(avg × weight) ÷ ${fmtNum(r.gradedWeight)}%\n      = ${totalPoints.toStringAsFixed(2)} ÷ ${fmtNum(r.gradedWeight / 100)} = ${fmtPct(r.percent)}'
                : 'grade = Σ(average × weight)${r.percent == null ? '' : ' = ${fmtPct(r.percent)}'}',
            style: mono(12, color: c.muted, height: 1.5),
          ),
        ),
        if (!r.isFinal && r.mark == null) ...[
          const SectionLabel('Target'),
          ChipRow<double>(
            values: targets,
            selected: _target!,
            labelOf: fmtGrade,
            onChanged: (t) => setState(() => _target = t),
          ),
          const SizedBox(height: 8),
          _TargetCard(result: target, target: _target!),
        ],
        const SectionLabel('Grade scale'),
        GtCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.45,
                children: [
                  for (final row in scale.rows)
                    _ScaleCell(
                      top: fmtGrade(row.equivalent),
                      bottom: '${fmtNum(row.minPercent)}+',
                      on:
                          current != null &&
                          (row.equivalent - current).abs() < 1e-9,
                    ),
                  _ScaleCell(
                    top: fmtGrade(scale.failingEquivalent),
                    bottom: '<${fmtNum(scale.passingPercent)}',
                    on:
                        current != null &&
                        (scale.failingEquivalent - current).abs() < 1e-9,
                    fail: true,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: Text(
                  '${scale.name}. Edit it in Settings › Grade scale.',
                  style: context.tt.bodySmall!.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.result, required this.target});
  final TargetResult result;
  final double target;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final (
      IconData icon,
      Color color,
      String title,
      String body,
    ) = switch (result.status) {
      TargetStatus.secured => (
        PhosphorIconsRegular.sealCheck,
        c.laurel,
        '${fmtGrade(target)} is secured',
        'You keep at least ${fmtNum(result.targetMinPercent)}% even with 0 on remaining work.',
      ),
      TargetStatus.needs => (
        PhosphorIconsRegular.flag,
        c.primaryText,
        'Target ${fmtGrade(target)} (${fmtNum(result.targetMinPercent)}%)',
        'Score at least ${fmtPct(result.neededPercent)} on all remaining work to reach it.',
      ),
      TargetStatus.unreachable => (
        PhosphorIconsRegular.warning,
        c.amber,
        '${fmtGrade(target)} is out of reach',
        'Even 100% on remaining work stays below ${fmtNum(result.targetMinPercent)}%.',
      ),
      TargetStatus.complete => (
        PhosphorIconsRegular.checkCircle,
        c.muted,
        'No remaining work',
        'Add upcoming assessments to plan for a target.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Gt.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.tt.titleSmall!.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(body, style: context.tt.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleCell extends StatelessWidget {
  const _ScaleCell({
    required this.top,
    required this.bottom,
    required this.on,
    this.fail = false,
  });
  final String top;
  final String bottom;
  final bool on;
  final bool fail;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final fg = on ? c.onPrimary : (fail ? c.red : c.text);
    return Container(
      decoration: BoxDecoration(
        color: on ? (fail ? c.red : c.primary) : c.raised,
        borderRadius: BorderRadius.circular(Gt.radiusSm),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              top,
              style: mono(13, weight: FontWeight.w700, color: fg),
            ),
            Text(
              bottom,
              style: mono(
                10.5,
                color: on ? fg.withValues(alpha: 0.85) : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FinalKind { computed, grade, mark }

/// Set the registrar's final grade or a mark (INC/DRP/W).
class _FinalGradeSheet extends ConsumerStatefulWidget {
  const _FinalGradeSheet({required this.subject});
  final Subject subject;

  @override
  ConsumerState<_FinalGradeSheet> createState() => _FinalGradeSheetState();
}

class _FinalGradeSheetState extends ConsumerState<_FinalGradeSheet> {
  late _FinalKind _kind;
  late final TextEditingController _grade;
  late FinalMark _mark;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final s = widget.subject;
    _kind = s.finalMark != null
        ? _FinalKind.mark
        : (s.finalGrade != null ? _FinalKind.grade : _FinalKind.computed);
    _grade = TextEditingController(
      text: s.finalGrade == null ? '' : fmtGrade(s.finalGrade),
    );
    _mark = s.finalMark ?? FinalMark.inc;
  }

  @override
  void dispose() {
    _grade.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_kind == _FinalKind.grade && !_form.currentState!.validate()) return;
    final s = widget.subject;
    final updated = s.copyWith(
      finalGrade: () =>
          _kind == _FinalKind.grade ? Validators.parseNum(_grade.text) : null,
      finalMark: () => _kind == _FinalKind.mark ? _mark : null,
    );
    await ref
        .read(gradebookProvider.notifier)
        .mutate((r) => r.updateSubjectOnly(updated));
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(context, 'Final grade updated');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return FormSheet(
      title: 'Final grade',
      subtitle: '${widget.subject.code} · ${widget.subject.title}',
      onSubmit: _save,
      children: [
        CapsuleSelector<_FinalKind>(
          values: _FinalKind.values,
          selected: _kind,
          labelOf: (k) => switch (k) {
            _FinalKind.computed => 'Computed',
            _FinalKind.grade => 'Official',
            _FinalKind.mark => 'INC / DRP / W',
          },
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: 14),
        switch (_kind) {
          _FinalKind.computed => Text(
            'The grade is computed from your scores and the grade scale.',
            style: context.tt.bodyMedium!.copyWith(color: c.muted),
          ),
          _FinalKind.grade => Form(
            key: _form,
            child: TextFormField(
              controller: _grade,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: mono(22, weight: FontWeight.w700, color: c.text),
              decoration: const InputDecoration(
                labelText: 'Grade from the registrar',
                hintText: '1.75',
              ),
              validator: (v) =>
                  Validators.required(v, 'Grade') ?? Validators.finalGrade(v),
            ),
          ),
          _FinalKind.mark => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChipRow<FinalMark>(
                values: FinalMark.values,
                selected: _mark,
                labelOf: (m) => '${m.code} · ${m.label}',
                onChanged: (m) => setState(() => _mark = m),
              ),
              const SizedBox(height: 10),
              Text(
                'Marked subjects are left out of the GWA.',
                style: context.tt.bodySmall,
              ),
            ],
          ),
        },
      ],
    );
  }
}
