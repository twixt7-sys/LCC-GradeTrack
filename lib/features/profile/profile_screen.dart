import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/validators.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _no = TextEditingController();
  final _program = TextEditingController();
  int _year = 1;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _no.dispose();
    _program.dispose();
    super.dispose();
  }

  Future<void> _save(Profile? p) async {
    if (!_form.currentState!.validate()) return;
    final updated = (p ?? Profile(name: '', createdAt: DateTime.now()))
        .copyWith(
          name: _name.text.trim(),
          studentNo: _no.text.trim(),
          program: _program.text.trim().toUpperCase(),
          yearLevel: _year,
        );
    await ref
        .read(gradebookProvider.notifier)
        .mutate((r) => r.saveProfile(updated));
    if (mounted) showToast(context, 'Profile saved');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    final p = gb?.profile;
    if (!_loaded && gb != null) {
      _name.text = p?.name ?? '';
      _no.text = p?.studentNo ?? '';
      _program.text = p?.program ?? '';
      _year = p?.yearLevel ?? 1;
      _loaded = true;
    }
    return PageScaffold(
      title: 'Profile',
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: c.primary,
              child: Text(
                p?.initials ?? '?',
                style: context.tt.titleLarge!.copyWith(color: c.onPrimary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p?.name ?? 'Student', style: context.tt.titleLarge),
                  Text(
                    'Legacy College of Compostela',
                    style: context.tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Cumulative GWA',
                value: fmtGrade(gb?.cumulativeGwa.gwa),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Units earned',
                value: fmtNum(gb?.unitsEarned ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Subjects',
                value: '${gb?.subjects.length ?? 0}',
              ),
            ),
          ],
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Name'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const FieldLabel('Student number'),
              TextFormField(
                controller: _no,
                decoration: const InputDecoration(hintText: 'Optional'),
              ),
              const FieldLabel('Program'),
              TextFormField(
                controller: _program,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'BSIT'),
              ),
              const FieldLabel('Year level'),
              CapsuleSelector<int>(
                values: const [1, 2, 3, 4, 5],
                selected: _year,
                labelOf: (y) => '$y',
                onChanged: (y) => setState(() => _year = y),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => _save(p),
                child: const Text('Save profile'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
