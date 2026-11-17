import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';

/// Components and weights pre-filled for every new subject.
class ComponentsTemplateScreen extends ConsumerStatefulWidget {
  const ComponentsTemplateScreen({super.key});

  @override
  ConsumerState<ComponentsTemplateScreen> createState() => _State();
}

class _Row {
  _Row(String name, double? w)
    : name = TextEditingController(text: name),
      weight = TextEditingController(text: w == null ? '' : fmtNum(w));
  final TextEditingController name;
  final TextEditingController weight;
}

class _State extends ConsumerState<ComponentsTemplateScreen> {
  final _form = GlobalKey<FormState>();
  final List<_Row> _rows = [];

  @override
  void initState() {
    super.initState();
    _load(ref.read(prefsProvider).componentTemplate);
  }

  void _load(List<GradeComponent> list) {
    _rows
      ..clear()
      ..addAll([for (final c in list) _Row(c.name, c.weight)]);
    for (final r in _rows) {
      r.weight.addListener(() => setState(() {}));
    }
  }

  List<double> get _weights => [
    for (final r in _rows) Validators.parseNum(r.weight.text) ?? 0,
  ];

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!Validators.weightsComplete(_weights)) {
      showToast(context, 'Weights must total 100%.', error: true);
      return;
    }
    await ref.read(prefsProvider).setComponentTemplate([
      for (final (i, r) in _rows.indexed)
        GradeComponent(
          name: r.name.text.trim(),
          weight: Validators.parseNum(r.weight.text)!,
          sortOrder: i,
        ),
    ]);
    if (!mounted) return;
    showToast(context, 'Default components saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final complete = Validators.weightsComplete(_weights);
    return PageScaffold(
      title: 'Default components',
      actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      children: [
        Text(
          'New subjects start with these components. Existing subjects keep their own.',
          style: context.tt.bodySmall,
        ),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: Column(
            children: [
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
                          textAlign: TextAlign.right,
                          style: mono(
                            15,
                            weight: FontWeight.w600,
                            color: c.text,
                          ),
                          decoration: const InputDecoration(suffixText: '%'),
                          validator: Validators.weight,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: _rows.length <= 1
                            ? null
                            : () => setState(() => _rows.removeAt(i)),
                        icon: Icon(
                          PhosphorIconsRegular.minusCircle,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                final r = _Row('', null);
                r.weight.addListener(() => setState(() {}));
                _rows.add(r);
              }),
              icon: const Icon(PhosphorIconsRegular.plus, size: 16),
              label: const Text('Add component'),
            ),
            const Spacer(),
            Text(
              Validators.weightsStatus(_weights),
              style: mono(
                12,
                weight: FontWeight.w700,
                color: complete ? c.laurel : c.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _load(defaultComponentTemplate)),
          child: const Text(
            'Reset to Quizzes 20 · Assignments 15 · Activities 25 · Exams 40',
          ),
        ),
      ],
    );
  }
}
