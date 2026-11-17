import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/repository.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/primitives.dart';
import '../history/term_sheet.dart';

Future<void> openSubjectSheet(BuildContext context, {Subject? existing}) =>
    showFormSheet<void>(context, (_) => SubjectSheet(existing: existing));

class _CompRow {
  _CompRow({this.id, String name = '', double? weight})
    : name = TextEditingController(text: name),
      weight = TextEditingController(
        text: weight == null ? '' : fmtNum(weight),
      );
  final int? id;
  final TextEditingController name;
  final TextEditingController weight;
  void dispose() {
    name.dispose();
    weight.dispose();
  }
}

class SubjectSheet extends ConsumerStatefulWidget {
  const SubjectSheet({super.key, this.existing});
  final Subject? existing;

  @override
  ConsumerState<SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends ConsumerState<SubjectSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _units;
  late final TextEditingController _instructor;
  final List<_CompRow> _rows = [];
  late int _color;
  late AvgMethod _method;
  late bool _countsInGwa;
  int? _scaleId;
  bool _saving = false;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final gb = ref.read(gradebookProvider).value;
    final prefs = ref.read(prefsProvider);
    _code = TextEditingController(text: e?.code ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _units = TextEditingController(text: e == null ? '3' : fmtNum(e.units));
    _instructor = TextEditingController(text: e?.instructor ?? '');
    _color =
        e?.colorIdx ??
        ((gb?.subjectsIn(gb.currentTerm?.id).length ?? 0) %
            subjectPalette.length);
    _method = e?.avgMethod ?? prefs.defaultAvgMethod;
    _countsInGwa = e?.countsInGwa ?? true;
    _scaleId = e?.scaleId ?? gb?.defaultScale.id;
    final comps = e == null
        ? prefs.componentTemplate
        : (gb?.componentsOf(e.id!) ?? const <GradeComponent>[]);
    for (final c in comps) {
      _rows.add(
        _CompRow(id: e == null ? null : c.id, name: c.name, weight: c.weight)
          ..weight.addListener(_rebuild),
      );
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _code.dispose();
    _title.dispose();
    _units.dispose();
    _instructor.dispose();
    super.dispose();
  }

  List<double> get _weights => [
    for (final r in _rows) Validators.parseNum(r.weight.text) ?? 0,
  ];

  Future<void> _save() async {
    final gb = ref.read(gradebookProvider).value!;
    final term = widget.existing == null
        ? gb.currentTerm
        : gb.termById(widget.existing!.termId);
    if (term == null) return;
    if (!_form.currentState!.validate()) return;
    if (_rows.isEmpty) {
      showToast(context, 'Add at least one component.', error: true);
      return;
    }
    if (!Validators.weightsComplete(_weights)) {
      showToast(
        context,
        'Weights must total 100%. Now ${Validators.weightsStatus(_weights)}.',
        error: true,
      );
      return;
    }
    final e = widget.existing;
    if (e != null) {
      final keep = _rows.map((r) => r.id).whereType<int>().toSet();
      final removed = gb.componentsOf(e.id!).where((c) => !keep.contains(c.id));
      final lost = removed.fold<int>(
        0,
        (n, c) => n + gb.scoresOfComponent(c.id!).length,
      );
      if (lost > 0) {
        final ok = await confirmAction(
          context,
          title: 'Remove components?',
          body:
              'Removing ${removed.map((c) => c.name).join(', ')} also deletes $lost ${lost == 1 ? 'score' : 'scores'}.',
          confirm: 'Remove',
        );
        if (!ok || !mounted) return;
      }
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final subject = e == null
        ? Subject(
            termId: term.id!,
            code: _code.text.trim().toUpperCase(),
            title: _title.text.trim(),
            units: Validators.parseNum(_units.text)!,
            instructor: _instructor.text.trim(),
            colorIdx: _color,
            scaleId: _scaleId,
            avgMethod: _method,
            countsInGwa: _countsInGwa,
            createdAt: now,
            updatedAt: now,
          )
        : e.copyWith(
            code: _code.text.trim().toUpperCase(),
            title: _title.text.trim(),
            units: Validators.parseNum(_units.text),
            instructor: _instructor.text.trim(),
            colorIdx: _color,
            scaleId: () => _scaleId,
            avgMethod: _method,
            countsInGwa: _countsInGwa,
          );
    final comps = [
      for (final (i, r) in _rows.indexed)
        GradeComponent(
          id: r.id,
          name: r.name.text.trim(),
          weight: Validators.parseNum(r.weight.text)!,
          sortOrder: i,
        ),
    ];
    try {
      await ref
          .read(gradebookProvider.notifier)
          .mutate((repo) => repo.saveSubject(subject, comps));
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context,
        e == null ? '${subject.code} added' : '${subject.code} updated',
      );
    } on DataException catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, err.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const SizedBox(height: 200);
    final term = widget.existing == null
        ? gb.currentTerm
        : gb.termById(widget.existing!.termId);

    if (term == null) {
      return FormSheet(
        title: 'Add subject',
        children: [
          EmptyState(
            icon: PhosphorIconsRegular.calendarPlus,
            title: 'No term yet',
            hint: 'Create a term (semester and school year) first.',
            action: 'Add term',
            onAction: () async {
              Navigator.of(context).pop();
              await openTermSheet(context);
            },
          ),
        ],
      );
    }

    final complete = Validators.weightsComplete(_weights);
    return FormSheet(
      title: widget.existing == null ? 'Add subject' : 'Edit subject',
      subtitle: term.longLabel,
      onSubmit: _save,
      submitting: _saving,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: const Key('code-field'),
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      style: mono(16, weight: FontWeight.w700, color: c.text),
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        hintText: 'IT 126',
                      ),
                      validator: (v) => Validators.required(v, 'Code'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const Key('units-field'),
                      controller: _units,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: mono(16, weight: FontWeight.w700, color: c.text),
                      decoration: const InputDecoration(labelText: 'Units'),
                      validator: Validators.units,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('title-field'),
                controller: _title,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Descriptive title',
                  hintText: 'Mobile Development',
                ),
                validator: (v) => Validators.required(v, 'Title'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructor,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Instructor',
                  hintText: 'Optional',
                ),
              ),
              const FieldLabel('Color'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < subjectPalette.length; i++)
                    Semantics(
                      button: true,
                      selected: i == _color,
                      label: 'Color ${i + 1}',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: subjectPalette[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _color ? c.text : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: i == _color
                              ? const Icon(
                                  PhosphorIconsBold.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              FieldLabel(
                'Grading components',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      complete
                          ? PhosphorIconsBold.checkCircle
                          : PhosphorIconsBold.warningCircle,
                      size: 13,
                      color: complete ? c.laurel : c.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Validators.weightsStatus(_weights),
                      key: const Key('weights-status'),
                      style: mono(
                        11,
                        weight: FontWeight.w700,
                        color: complete ? c.laurel : c.amber,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, r) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: r.name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Component',
                          ),
                          validator: (v) => Validators.required(v, 'Name'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 92,
                        child: TextFormField(
                          controller: r.weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          style: mono(
                            15,
                            weight: FontWeight.w600,
                            color: c.text,
                          ),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(suffixText: '%'),
                          validator: Validators.weight,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove component',
                        onPressed: _rows.length <= 1
                            ? null
                            : () => setState(() {
                                _rows.removeAt(i).dispose();
                              }),
                        icon: Icon(
                          PhosphorIconsRegular.minusCircle,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    final left =
                        100 - _weights.fold<double>(0, (a, b) => a + b);
                    _rows.add(
                      _CompRow(weight: left > 0 ? left : null)
                        ..weight.addListener(_rebuild),
                    );
                  }),
                  icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                  label: const Text('Add component'),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _more = !_more),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'More options',
                        style: context.tt.labelLarge!.copyWith(color: c.muted),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _more ? 0.5 : 0,
                        duration: Gt.fast,
                        child: Icon(
                          PhosphorIconsRegular.caretDown,
                          size: 14,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_more) ...[
                const FieldLabel('Component average'),
                CapsuleSelector<AvgMethod>(
                  values: AvgMethod.values,
                  selected: _method,
                  labelOf: (m) =>
                      m == AvgMethod.meanPercent ? 'Mean of %' : 'Total points',
                  onChanged: (m) => setState(() => _method = m),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    _method == AvgMethod.meanPercent
                        ? 'Each item counts equally. 16/20 and 45/50 average to 85%.'
                        : 'Bigger items count more. 16/20 and 45/50 give 61/70 = 87.14%.',
                    style: context.tt.bodySmall,
                  ),
                ),
                if (gb.scales.length > 1) ...[
                  const FieldLabel('Grade scale'),
                  ChipRow<int>(
                    values: [for (final s in gb.scales) s.id!],
                    selected: _scaleId ?? gb.defaultScale.id!,
                    labelOf: (id) =>
                        gb.scales.firstWhere((s) => s.id == id).name,
                    onChanged: (id) => setState(() => _scaleId = id),
                  ),
                ],
                const SizedBox(height: 12),
                GtCard(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  radius: Gt.radiusSm + 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Count toward GWA',
                              style: context.tt.titleSmall,
                            ),
                            Text(
                              'Turn off for non-credit subjects like NSTP.',
                              style: context.tt.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _countsInGwa,
                        onChanged: (v) => setState(() => _countsInGwa = v),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
