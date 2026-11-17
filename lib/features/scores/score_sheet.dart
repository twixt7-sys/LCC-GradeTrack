import 'package:collection/collection.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/gradebook.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/primitives.dart';
import '../subjects/subject_sheet.dart';

/// Add/edit a score. With [upcoming], records an assessment with no score yet.
Future<void> openScoreSheet(
  BuildContext context, {
  Score? existing,
  int? subjectId,
  int? componentId,
  bool upcoming = false,
  bool record = false,
}) => showFormSheet<void>(
  context,
  (_) => ScoreSheet(
    existing: existing,
    subjectId: subjectId,
    componentId: componentId,
    upcoming: upcoming,
    record: record,
  ),
);

/// "Quizzes" → "Quiz", "Activities" → "Activity", "Exams" → "Exam".
String singular(String name) {
  final n = name.trim();
  if (n.toLowerCase().endsWith('zzes')) return n.substring(0, n.length - 3);
  if (n.toLowerCase().endsWith('zes')) return n.substring(0, n.length - 3);
  if (n.toLowerCase().endsWith('ies')) {
    return '${n.substring(0, n.length - 3)}y';
  }
  if (n.toLowerCase().endsWith('s') && !n.toLowerCase().endsWith('ss')) {
    return n.substring(0, n.length - 1);
  }
  return n;
}

class ScoreSheet extends ConsumerStatefulWidget {
  const ScoreSheet({
    super.key,
    this.existing,
    this.subjectId,
    this.componentId,
    this.upcoming = false,
    this.record = false,
  });
  final Score? existing;

  /// Opens an upcoming assessment ready to enter its score.
  final bool record;
  final int? subjectId;
  final int? componentId;
  final bool upcoming;

  @override
  ConsumerState<ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends ConsumerState<ScoreSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _score;
  late final TextEditingController _total;
  late final TextEditingController _note;
  int? _subjectId;
  int? _componentId;
  late DateTime _date;
  late bool _upcoming;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final gb = ref.read(gradebookProvider).value;
    _title = TextEditingController(text: e?.title ?? '');
    _score = TextEditingController(
      text: e?.score == null ? '' : fmtNum(e!.score),
    );
    _total = TextEditingController(text: e == null ? '' : fmtNum(e.total));
    _note = TextEditingController(text: e?.note ?? '');
    _upcoming = widget.record ? false : (e?.isUpcoming ?? widget.upcoming);
    _date =
        e?.date ??
        dayOf(DateTime.now()).add(Duration(days: widget.upcoming ? 7 : 0));
    // Recording a past-due item: keep its date unless it is in the future.
    if (widget.record && e != null && e.date.isAfter(DateTime.now())) {
      _date = dayOf(DateTime.now());
    }
    _componentId = e?.componentId ?? widget.componentId;
    if (gb != null) {
      if (e != null) {
        _subjectId = gb.subjectOfScore(e)?.id;
      } else if (widget.subjectId != null) {
        _subjectId = widget.subjectId;
      } else if (_componentId != null) {
        _subjectId = gb.componentById(_componentId!)?.subjectId;
      } else {
        _subjectId = gb.subjectsIn(gb.currentTerm?.id).firstOrNull?.id;
      }
      _componentId ??= _subjectId == null
          ? null
          : gb.componentsOf(_subjectId!).firstOrNull?.id;
    }
    _score.addListener(_rebuild);
    _total.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _score.dispose();
    _total.dispose();
    _note.dispose();
    super.dispose();
  }

  String _titleHint(Gradebook gb) {
    final comp = _componentId == null ? null : gb.componentById(_componentId!);
    if (comp == null) return 'e.g. Quiz 3';
    final n =
        gb
            .scoresOfComponent(comp.id!)
            .where((s) => s.id != widget.existing?.id)
            .length +
        1;
    return '${singular(comp.name)} $n';
  }

  Future<void> _pickSubject(Gradebook gb) async {
    final subjects = gb.subjectsIn(gb.currentTerm?.id);
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text('Subject', style: ctx.tt.titleMedium),
            const SizedBox(height: 10),
            for (final s in subjects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CodeTile(subject: s, size: 38),
                title: Text(s.code, style: ctx.tt.titleSmall),
                subtitle: Text(
                  s.title,
                  style: ctx.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: s.id == _subjectId
                    ? Icon(PhosphorIconsBold.check, color: ctx.gt.primaryText)
                    : null,
                onTap: () => Navigator.pop(ctx, s.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _subjectId) {
      setState(() {
        _subjectId = picked;
        _componentId = gb.componentsOf(picked).firstOrNull?.id;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save(Gradebook gb) async {
    if (_subjectId == null || _componentId == null) {
      showToast(context, 'Pick a subject first.', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final title = _title.text.trim().isEmpty
        ? _titleHint(gb)
        : _title.text.trim();
    final total = Validators.parseNum(_total.text)!;
    final score = _upcoming ? null : Validators.parseNum(_score.text);
    final e = widget.existing;
    final s = e == null
        ? Score(
            componentId: _componentId!,
            title: title,
            score: score,
            total: total,
            date: _date,
            note: _note.text,
            createdAt: now,
            updatedAt: now,
          )
        : e.copyWith(
            componentId: _componentId,
            title: title,
            score: () => score,
            total: total,
            date: _date,
            note: _note.text,
          );
    try {
      await ref.read(gradebookProvider.notifier).mutate((r) => r.saveScore(s));
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context,
        e == null
            ? (_upcoming ? 'Assessment added' : 'Score saved')
            : 'Score updated',
      );
    } on Object catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'Could not save: $err', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete this score?',
      body: '"${widget.existing!.title}" will be removed.',
    );
    if (!ok || !mounted) return;
    await ref
        .read(gradebookProvider.notifier)
        .mutate((r) => r.deleteScore(widget.existing!.id!));
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(context, 'Score deleted');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const SizedBox(height: 200);
    final subject = _subjectId == null ? null : gb.subjectById(_subjectId!);
    final components = subject == null
        ? const <GradeComponent>[]
        : gb.componentsOf(subject.id!);
    final comp = components.firstWhereOrNull((x) => x.id == _componentId);
    final isEdit = widget.existing != null;

    if (gb.subjectsIn(gb.currentTerm?.id).isEmpty && subject == null) {
      return FormSheet(
        title: _upcoming ? 'Add assessment' : 'Add score',
        children: [
          EmptyState(
            icon: PhosphorIconsRegular.books,
            title: 'No subjects in this term',
            hint: 'Add a subject with its grading components first.',
            action: 'Add subject',
            onAction: () async {
              Navigator.of(context).pop();
              await openSubjectSheet(context);
            },
          ),
        ],
      );
    }

    final s = Validators.parseNum(_score.text);
    final t = Validators.parseNum(_total.text);
    final pct = (s != null && t != null && t > 0 && s <= t && s >= 0)
        ? s / t * 100
        : null;

    return FormSheet(
      title: widget.record
          ? 'Record score'
          : isEdit
          ? (_upcoming ? 'Edit assessment' : 'Edit score')
          : (_upcoming ? 'Add assessment' : 'Add score'),
      subtitle: subject == null ? null : '${subject.code} · ${subject.title}',
      onSubmit: () => _save(gb),
      submitting: _saving,
      footer: isEdit
          ? TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: c.red),
              icon: const Icon(PhosphorIconsRegular.trash, size: 18),
              label: const Text('Delete'),
            )
          : null,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.subjectId == null)
                PickerRow(
                  icon: PhosphorIconsRegular.books,
                  label: 'Subject',
                  value: subject == null
                      ? 'Choose'
                      : '${subject.code} · ${subject.title}',
                  onTap: () => _pickSubject(gb),
                ),
              if (components.isNotEmpty) ...[
                const FieldLabel('Component'),
                if (components.length <= 4)
                  CapsuleSelector<int>(
                    values: [for (final x in components) x.id!],
                    selected: _componentId ?? components.first.id!,
                    labelOf: (id) =>
                        _short(components.firstWhere((x) => x.id == id).name),
                    onChanged: (id) => setState(() => _componentId = id),
                  )
                else
                  ChipRow<int>(
                    values: [for (final x in components) x.id!],
                    selected: _componentId ?? components.first.id!,
                    labelOf: (id) =>
                        components.firstWhere((x) => x.id == id).name,
                    onChanged: (id) => setState(() => _componentId = id),
                  ),
              ],
              const FieldLabel('Title'),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: _titleHint(gb)),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                label: 'Not taken yet',
                hint: 'Plan it now and add the score later.',
                value: _upcoming,
                onChanged: (v) => setState(() => _upcoming = v),
              ),
              FieldLabel(_upcoming ? 'Total items' : 'Score'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_upcoming) ...[
                    Expanded(
                      child: TextFormField(
                        key: const Key('score-field'),
                        controller: _score,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        style: mono(24, weight: FontWeight.w700, color: c.text),
                        decoration: const InputDecoration(labelText: 'Score'),
                        validator: (v) => Validators.score(v, _total.text),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                      child: Text('/', style: mono(26, color: c.faint)),
                    ),
                  ],
                  Expanded(
                    child: TextFormField(
                      key: const Key('total-field'),
                      controller: _total,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: mono(24, weight: FontWeight.w700, color: c.text),
                      decoration: const InputDecoration(
                        labelText: 'Total items',
                      ),
                      validator: Validators.total,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(Gt.radiusSm + 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      _upcoming
                          ? PhosphorIconsRegular.scales
                          : PhosphorIconsRegular.percent,
                      size: 18,
                      color: c.primaryText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _upcoming
                            ? (comp == null
                                  ? 'Counts toward the grade'
                                  : 'Counts toward ${comp.name} · ${fmtNum(comp.weight)}% of grade')
                            : 'Auto-computed',
                        style: context.tt.labelLarge!.copyWith(
                          color: c.primaryText,
                        ),
                      ),
                    ),
                    if (!_upcoming)
                      Num(
                        fmtPct(pct),
                        size: 18,
                        weight: FontWeight.w700,
                        color: c.primaryText,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PickerRow(
                icon: PhosphorIconsRegular.calendarBlank,
                label: _upcoming ? 'Due date' : 'Date taken',
                value: fmtMdy(_date),
                onTap: _pickDate,
              ),
              const FieldLabel('Note'),
              TextFormField(
                controller: _note,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Optional'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _short(String name) => switch (name.toLowerCase()) {
    'assignments' => 'Assign.',
    'activities' => 'Activity',
    'quizzes' => 'Quiz',
    'exams' => 'Exam',
    _ => name.length > 9 ? '${name.substring(0, 8)}.' : name,
  };
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GtCard(
    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
    radius: Gt.radiusSm + 2,
    onTap: () => onChanged(!value),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.tt.titleSmall),
              Text(hint, style: context.tt.bodySmall),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}
