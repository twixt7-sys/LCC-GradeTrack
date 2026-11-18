import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';

/// Edit the default percent → equivalent table to match a syllabus.
class ScaleEditorScreen extends ConsumerStatefulWidget {
  const ScaleEditorScreen({super.key});

  @override
  ConsumerState<ScaleEditorScreen> createState() => _ScaleEditorScreenState();
}

class _R {
  _R(double min, double eq)
    : min = TextEditingController(text: fmtNum(min)),
      eq = TextEditingController(text: eq.toStringAsFixed(2));
  final TextEditingController min;
  final TextEditingController eq;
  void dispose() {
    min.dispose();
    eq.dispose();
  }
}

class _ScaleEditorScreenState extends ConsumerState<ScaleEditorScreen> {
  final _form = GlobalKey<FormState>();
  final List<_R> _rows = [];
  late TextEditingController _name;
  late TextEditingController _fail;
  GradeScale? _scale;

  @override
  void initState() {
    super.initState();
    _scale =
        ref.read(gradebookProvider).value?.defaultScale ??
        GradeScale.lccStandard;
    _load(_scale!);
  }

  void _load(GradeScale s) {
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll([
        for (final r in s.sorted().rows) _R(r.minPercent, r.equivalent),
      ]);
    _name = TextEditingController(text: s.name);
    _fail = TextEditingController(text: s.failingEquivalent.toStringAsFixed(2));
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _name.dispose();
    _fail.dispose();
    super.dispose();
  }

  String? _check() {
    final mins = [for (final r in _rows) Validators.parseNum(r.min.text)];
    if (mins.toSet().length != mins.length) {
      return 'Each minimum % must be different.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final err = _check();
    if (err != null) {
      showToast(context, err, error: true);
      return;
    }
    final s = GradeScale(
      id: _scale?.id,
      name: _name.text.trim(),
      isDefault: true,
      failingEquivalent: Validators.parseNum(_fail.text)!,
      rows: [
        for (final r in _rows)
          ScaleRow(
            minPercent: Validators.parseNum(r.min.text)!,
            equivalent: Validators.parseNum(r.eq.text)!,
          ),
      ],
    ).sorted();
    await ref
        .read(gradebookProvider.notifier)
        .mutate((repo) => repo.saveScale(s));
    if (!mounted) return;
    showToast(context, 'Grade scale saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    String? pct(String? v) {
      final n = Validators.parseNum(v);
      if (n == null) return 'Number';
      if (n < 0 || n > 100) return '0–100';
      return null;
    }

    String? eq(String? v) {
      final n = Validators.parseNum(v);
      if (n == null) return 'Number';
      if (n < 1 || n > 5) return '1–5';
      return null;
    }

    return PageScaffold(
      title: 'Grade scale',
      subtitle: 'Percent to equivalent',
      actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      children: [
        Text(
          'Set this to match your instructors\' syllabus. A subject grade at or above a row\'s minimum gets that equivalent. Below the lowest row is failing.',
          style: context.tt.bodySmall,
        ),
        const SizedBox(height: 14),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Scale name'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 14),
              GtCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Minimum %', style: context.tt.bodySmall),
                        ),
                        Expanded(
                          child: Text(
                            'Equivalent',
                            style: context.tt.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    for (final (i, r) in _rows.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _num(r.min, pct, suffix: '%+')),
                            const SizedBox(width: 8),
                            Expanded(child: _num(r.eq, eq)),
                            IconButton(
                              tooltip: 'Remove row',
                              onPressed: _rows.length <= 1
                                  ? null
                                  : () => setState(
                                      () => _rows.removeAt(i).dispose(),
                                    ),
                              icon: Icon(
                                Ph.minusCircle,
                                size: 20,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Below lowest row',
                              style: context.tt.titleSmall!.copyWith(
                                color: c.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _num(_fail, eq)),
                        const SizedBox(width: 48),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _rows.add(_R(0, 3))),
                        icon: const Icon(Ph.plus, size: 16),
                        label: const Text('Add row'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() {
                  final id = _scale?.id;
                  _load(GradeScale.lccStandard);
                  _scale = GradeScale(
                    id: id,
                    name: GradeScale.lccStandard.name,
                    rows: GradeScale.lccStandard.rows,
                  );
                }),
                child: const Text('Reset to LCC Standard'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _num(
    TextEditingController ctl,
    String? Function(String?) v, {
    String? suffix,
  }) => TextFormField(
    controller: ctl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    style: mono(15, weight: FontWeight.w600, color: context.gt.text),
    decoration: InputDecoration(suffixText: suffix),
    validator: v,
  );
}
