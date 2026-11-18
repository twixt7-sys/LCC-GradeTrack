import 'package:lcc_gradetrack/ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/providers/providers.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/services/gradebook.dart';
import '../../core/services/target_solver.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/primitives.dart';

enum _Mode { gwa, target }

/// What-if tools. Nothing here is saved.
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _Row {
  _Row({String label = '', String units = '3', String grade = ''})
    : label = TextEditingController(text: label),
      units = TextEditingController(text: units),
      grade = TextEditingController(text: grade);
  final TextEditingController label;
  final TextEditingController units;
  final TextEditingController grade;
  void dispose() {
    label.dispose();
    units.dispose();
    grade.dispose();
  }
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  _Mode _mode = _Mode.gwa;
  final List<_Row> _rows = [];
  bool _seeded = false;
  int? _subjectId;
  double? _target;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _seed(Gradebook gb) {
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    for (final r in gb.resultsIn(gb.currentTerm?.id)) {
      if (!r.subject.countsInGwa || r.mark != null) continue;
      _rows.add(
        _Row(
          label: r.subject.code,
          units: fmtNum(r.subject.units),
          grade: r.equivalent == null ? '' : fmtGrade(r.equivalent),
        ),
      );
    }
    if (_rows.isEmpty) _rows.add(_Row());
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const Center(child: CircularProgressIndicator());
    if (!_seeded) _seed(gb);

    return ListView(
      padding: EdgeInsets.fromLTRB(Gt.pad, 4, Gt.pad, shellBottomPad(context)),
      children: [
        CapsuleSelector<_Mode>(
          values: _Mode.values,
          selected: _mode,
          labelOf: (m) => m == _Mode.gwa ? 'GWA what-if' : 'Target score',
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 12),
        if (_mode == _Mode.gwa) _gwa(context, gb) else _targetView(context, gb),
      ],
    );
  }

  Widget _gwa(BuildContext context, Gradebook gb) {
    final c = context.gt;
    var weighted = 0.0;
    var units = 0.0;
    var invalid = false;
    for (final r in _rows) {
      final u = Validators.parseNum(r.units.text);
      final g = Validators.parseNum(r.grade.text);
      if (r.grade.text.trim().isEmpty) continue;
      if (u == null || u <= 0 || g == null || g < 1 || g > 5) {
        invalid = true;
        continue;
      }
      weighted += u * g;
      units += u;
    }
    final gwa = units > 0 ? weighted / units : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GtCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projected GWA', style: context.tt.bodySmall),
                    Num(
                      fmtGrade(gwa),
                      size: 40,
                      weight: FontWeight.w700,
                      color: gwa == null ? c.faint : c.text,
                    ),
                    Text(
                      gwa == null
                          ? 'Enter grades below.'
                          : '${fmtUnits(units)} · Σ(units × grade) ÷ Σ units',
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
              ),
              if (gwa != null) StandingTag(Standing.of(gwa)),
            ],
          ),
        ),
        if (invalid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Rows with units ≤ 0 or grades outside 1.00–5.00 are skipped.',
              style: context.tt.bodySmall!.copyWith(color: c.amber),
            ),
          ),
        SectionLabel(
          'Subjects',
          trailing: 'Reset',
          onTrailing: () => setState(() => _seed(gb)),
        ),
        GtCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('Subject', style: context.tt.bodySmall),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Units', style: context.tt.bodySmall),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Grade', style: context.tt.bodySmall),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              for (final (i, r) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _field(
                          r.label,
                          hint: 'Subject',
                          isMono: true,
                          numeric: false,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: _field(r.units, hint: '3')),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: _field(r.grade, hint: '1.75')),
                      IconButton(
                        tooltip: 'Remove row',
                        onPressed: _rows.length <= 1
                            ? null
                            : () => setState(() => _rows.removeAt(i).dispose()),
                        icon: Icon(Ph.minusCircle, size: 20, color: c.muted),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_Row())),
                  icon: const Icon(Ph.plus, size: 16),
                  label: const Text('Add row'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Change grades to see how each subject moves your GWA. Nothing here is saved.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctl, {
    required String hint,
    bool isMono = true,
    bool numeric = true,
  }) {
    final c = context.gt;
    return TextField(
      controller: ctl,
      onChanged: (_) => setState(() {}),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: mono(14, weight: FontWeight.w600, color: c.text),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _targetView(BuildContext context, Gradebook gb) {
    final c = context.gt;
    final subjects =
        gb
            .resultsIn(gb.currentTerm?.id)
            .where((r) => !r.isFinal && r.mark == null)
            .toList()
          ..sort((a, b) => a.subject.code.compareTo(b.subject.code));
    if (subjects.isEmpty) {
      return const EmptyState(
        icon: Ph.target,
        title: 'No subjects to plan',
        hint: 'Add subjects in the current term to compute target scores.',
      );
    }
    // Default to the first subject that still has work left.
    _subjectId ??=
        (subjects.where((x) => x.hasPending).firstOrNull ?? subjects.first)
            .subject
            .id;
    final r = subjects.firstWhere(
      (x) => x.subject.id == _subjectId,
      orElse: () => subjects.first,
    );
    final scale = gb.scaleFor(r.subject).sorted();
    final targets = [for (final row in scale.rows) row.equivalent];
    // Default target: one step better than now, else the passing grade.
    final now = r.equivalent;
    _target ??= now == null
        ? scale.passingEquivalent
        : (targets.where((t) => t < now - 1e-9).lastOrNull ?? targets.first);
    final result = TargetSolver(gb.calculator).solve(
      subject: r.subject,
      components: gb.componentsOf(r.subject.id!),
      scores: gb.scoresOfSubject(r.subject.id!),
      scale: scale,
      targetEquivalent: _target!,
    );
    final remaining = gb
        .scoresOfSubject(r.subject.id!)
        .where((s) => s.isUpcoming)
        .length;
    final ungradedComps = r.components
        .where((x) => x.average == null)
        .map((x) => x.component.name)
        .toList();

    final (String big, String line, Color color) = switch (result.status) {
      TargetStatus.needs => (
        fmtPct(result.neededPercent),
        'needed on all remaining work',
        c.primaryText,
      ),
      TargetStatus.secured => (
        'Secured',
        'even with 0% on remaining work',
        c.laurel,
      ),
      TargetStatus.unreachable => (
        'Out of reach',
        'even 100% stays below ${fmtNum(result.targetMinPercent)}%',
        c.amber,
      ),
      TargetStatus.complete => (
        'Complete',
        'no remaining work in this subject',
        c.muted,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Subject'),
        ChipRow<int>(
          values: [for (final x in subjects) x.subject.id!],
          selected: r.subject.id!,
          labelOf: (id) => gb.subjectById(id)!.code,
          onChanged: (id) => setState(() => _subjectId = id),
        ),
        const SectionLabel('Target grade'),
        ChipRow<double>(
          values: targets,
          selected: _target!,
          labelOf: fmtGrade,
          onChanged: (t) => setState(() => _target = t),
        ),
        const SizedBox(height: 12),
        GtCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.subject.code} → ${fmtGrade(_target)} (${fmtNum(result.targetMinPercent)}%+)',
                style: context.tt.bodySmall,
              ),
              const SizedBox(height: 4),
              Num(big, size: 34, weight: FontWeight.w700, color: color),
              Text(line, style: context.tt.bodyMedium),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              _kv(
                context,
                'Current',
                r.percent == null
                    ? 'No scores'
                    : '${fmtPct(r.percent)} → ${fmtGrade(r.equivalent)}',
              ),
              _kv(
                context,
                'Graded so far',
                '${r.gradedShare.round()}% of grade',
              ),
              _kv(context, 'Upcoming items', '$remaining'),
              if (ungradedComps.isNotEmpty)
                _kv(context, 'Not started', ungradedComps.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Assumes the same percent on every upcoming item and on components with no scores yet. Add upcoming assessments in the Planner for a sharper estimate.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(k, style: context.tt.bodySmall)),
        Flexible(
          child: Text(
            v,
            style: context.tt.labelLarge,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}
