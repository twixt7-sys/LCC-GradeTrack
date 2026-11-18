import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/primitives.dart';

Future<void> openTermSheet(BuildContext context, {Term? existing}) =>
    showFormSheet<void>(context, (_) => TermSheet(existing: existing));

/// Default term for "now": Aug–Dec → 1st, Jan–May → 2nd, Jun–Jul → Summer.
Term suggestedTerm(DateTime now) {
  if (now.month >= 8) return Term(startYear: now.year, kind: TermKind.first);
  if (now.month <= 5) {
    return Term(startYear: now.year - 1, kind: TermKind.second);
  }
  return Term(startYear: now.year - 1, kind: TermKind.summer);
}

class TermSheet extends ConsumerStatefulWidget {
  const TermSheet({super.key, this.existing});
  final Term? existing;

  @override
  ConsumerState<TermSheet> createState() => _TermSheetState();
}

class _TermSheetState extends ConsumerState<TermSheet> {
  late int _year;
  late TermKind _kind;
  late bool _current;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing ?? suggestedTerm(DateTime.now());
    _year = s.startYear;
    _kind = s.kind;
    _current = widget.existing?.isCurrent ?? true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final e = widget.existing;
    final t = e == null
        ? Term(startYear: _year, kind: _kind, isCurrent: _current)
        : e.copyWith(
            startYear: _year,
            kind: _kind,
            isCurrent: _current || e.isCurrent,
          );
    try {
      await ref.read(gradebookProvider.notifier).mutate((r) async {
        if (e == null) {
          await r.addTerm(t);
        } else {
          await r.editTerm(t);
        }
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, e == null ? '${t.shortLabel} added' : 'Term updated');
    } on DataException catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, err.message, error: true);
    }
  }

  Future<void> _delete() async {
    final gb = ref.read(gradebookProvider).value!;
    final e = widget.existing!;
    final n = gb.subjectsIn(e.id).length;
    final ok = await confirmAction(
      context,
      title: 'Delete ${e.shortLabel}?',
      body: n == 0
          ? 'This term has no subjects.'
          : 'This also deletes its $n ${n == 1 ? 'subject' : 'subjects'} and all their scores.',
    );
    if (!ok || !mounted) return;
    await ref
        .read(gradebookProvider.notifier)
        .mutate((r) => r.deleteTerm(e.id!));
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(context, 'Term deleted');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final e = widget.existing;
    return FormSheet(
      title: e == null ? 'Add term' : 'Edit term',
      onSubmit: _save,
      submitting: _saving,
      footer: e == null
          ? null
          : TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: c.red),
              icon: const Icon(Ph.trash, size: 18),
              label: const Text('Delete term'),
            ),
      children: [
        const FieldLabel('School year'),
        GtCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous year',
                onPressed: () => setState(() => _year--),
                icon: const Icon(Ph.caretLeft),
              ),
              Expanded(
                child: Text(
                  'AY $_year–${_year + 1}',
                  textAlign: TextAlign.center,
                  style: mono(18, weight: FontWeight.w700, color: c.text),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                onPressed: () => setState(() => _year++),
                icon: const Icon(Ph.caretRight),
              ),
            ],
          ),
        ),
        const FieldLabel('Semester'),
        CapsuleSelector<TermKind>(
          values: TermKind.values,
          selected: _kind,
          labelOf: (k) => k.label,
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: 14),
        if (!(e?.isCurrent ?? false))
          GtCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            radius: Gt.radiusSm + 2,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set as current term', style: context.tt.titleSmall),
                      Text(
                        'Home, Subjects and Scores show this term.',
                        style: context.tt.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _current,
                  onChanged: (v) => setState(() => _current = v),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
