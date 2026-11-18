import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/db/seed_sample.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/pin_service.dart';
import '../../core/services/repository.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/primitives.dart';
import '../history/term_sheet.dart';
import '../lock/pin_pad.dart';

/// First run: profile, current term, grade scale, optional PIN, start.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 6;
  int _step = 0;
  final _profileForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _no = TextEditingController();
  final _program = TextEditingController(text: 'BSIT');
  int _year = 1;
  late int _termYear;
  late TermKind _termKind;
  String? _pin;
  bool _bio = false;
  bool _canBio = false;
  bool _sample = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = suggestedTerm(DateTime.now());
    _termYear = t.startYear;
    _termKind = t.kind;
    _checkBio();
  }

  Future<void> _checkBio() async {
    try {
      final a = LocalAuthentication();
      final ok = await a.isDeviceSupported() && await a.canCheckBiometrics;
      if (mounted) setState(() => _canBio = ok);
    } on Object {
      // No biometrics.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _no.dispose();
    _program.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 1 && !_profileForm.currentState!.validate()) return;
    if (_step < _steps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    String? hash;
    String? salt;
    if (_pin != null) {
      salt = PinService.newSalt();
      hash = PinService.hash(_pin!, salt);
    }
    final profile = Profile(
      name: _name.text.trim(),
      studentNo: _no.text.trim(),
      program: _program.text.trim().toUpperCase(),
      yearLevel: _year,
      pinHash: hash,
      pinSalt: salt,
      biometric: _pin != null && _bio,
      createdAt: DateTime.now(),
    );
    final notifier = ref.read(gradebookProvider.notifier);
    try {
      await notifier.mutate((r) async {
        await r.saveProfile(profile);
        if (_sample) {
          await SampleData.seed(r.db, withProfile: false);
        } else {
          try {
            await r.addTerm(
              Term(startYear: _termYear, kind: _termKind, isCurrent: true),
            );
          } on DataException {
            // Term already exists (e.g. after a reset); make it current.
            final gb = await r.load();
            final t = gb.terms
                .where((x) => x.startYear == _termYear && x.kind == _termKind)
                .firstOrNull;
            if (t != null) await r.setCurrentTerm(t.id!);
          }
        }
      });
      await ref.read(prefsProvider).setOnboarded(true);
      if (mounted) context.go('/');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'Could not finish setup: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final pages = [_welcome, _profile, _term, _scale, _security, _start];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: Gt.med,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _step ? c.primary : c.hairline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.reduceMotion ? Duration.zero : Gt.med,
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      children: [pages[_step](context)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      SizedBox(
                        width: 56,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _back,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(52, 52),
                          ),
                          child: Icon(
                            Ph.arrowLeft,
                            color: c.text,
                            semanticLabel: 'Back',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        key: const Key('onboarding-next'),
                        onPressed: _saving ? null : _next,
                        child: Text(switch (_step) {
                          0 => 'Get started',
                          5 => _sample ? 'Start with sample data' : 'Start',
                          _ => 'Continue',
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: context.tt.headlineSmall),
      const SizedBox(height: 6),
      Text(
        sub,
        style: context.tt.bodyMedium!.copyWith(color: context.gt.muted),
      ),
      const SizedBox(height: 22),
    ],
  );

  Widget _welcome(BuildContext context) {
    final c = context.gt;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: c.hairline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c.text),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: context.tt.bodyLarge)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Image.asset(
            'assets/brand/lcc_logo.png',
            width: 168,
            height: 168,
            cacheWidth: 500,
          ),
        ),
        const SizedBox(height: 26),
        Text('LCC GradeTrack', style: context.tt.displaySmall),
        const SizedBox(height: 6),
        Text(
          'Know your standing before grades come out.',
          style: context.tt.bodyLarge!.copyWith(color: c.muted),
        ),
        const SizedBox(height: 28),
        point(
          Ph.notePencil,
          'Record quiz, assignment, activity and exam scores.',
        ),
        point(
          Ph.scales,
          'Weighted grades, equivalents and GWA, computed for you.',
        ),
        point(Ph.deviceMobile, 'Stays on this phone. No account, no internet.'),
      ],
    );
  }

  Widget _profile(BuildContext context) => Form(
    key: _profileForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('About you', 'Used for the greeting and your grade report.'),
        TextFormField(
          key: const Key('onboarding-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
          validator: (v) => Validators.required(v, 'Name'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _no,
          decoration: const InputDecoration(
            labelText: 'Student number',
            hintText: 'Optional',
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _program,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Program',
            hintText: 'BSIT',
          ),
        ),
        const FieldLabel('Year level'),
        CapsuleSelector<int>(
          values: const [1, 2, 3, 4, 5],
          selected: _year,
          labelOf: (y) => '$y',
          onChanged: (y) => setState(() => _year = y),
        ),
      ],
    ),
  );

  Widget _term(BuildContext context) {
    final c = context.gt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'Current term',
          'Subjects and scores are grouped by semester. Add past terms later in History.',
        ),
        const FieldLabel('School year'),
        GtCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous year',
                onPressed: () => setState(() => _termYear--),
                icon: const Icon(Ph.caretLeft),
              ),
              Expanded(
                child: Text(
                  'AY $_termYear–${_termYear + 1}',
                  textAlign: TextAlign.center,
                  style: mono(18, weight: FontWeight.w700, color: c.text),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                onPressed: () => setState(() => _termYear++),
                icon: const Icon(Ph.caretRight),
              ),
            ],
          ),
        ),
        const FieldLabel('Semester'),
        CapsuleSelector<TermKind>(
          values: TermKind.values,
          selected: _termKind,
          labelOf: (k) => k.label,
          onChanged: (k) => setState(() => _termKind = k),
        ),
      ],
    );
  }

  Widget _scale(BuildContext context) {
    final c = context.gt;
    const s = GradeScale.lccStandard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'Grade scale',
          'Percent grades convert to 1.00–5.00 with this table. Change it any time in Settings to match a syllabus.',
        ),
        GtCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, r) in s.rows.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Num(
                          '${fmtNum(r.minPercent)}% and up',
                          size: 13,
                          color: c.muted,
                        ),
                      ),
                      Num(
                        fmtGrade(r.equivalent),
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(child: Num('Below 75%', size: 13, color: c.red)),
                    Num(
                      '5.00',
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Default weights for new subjects: Quizzes 20%, Assignments 15%, Activities 25%, Exams 40%.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }

  Widget _security(BuildContext context) {
    final c = context.gt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'App lock',
          'Optional. Keeps your grades private if someone else uses your phone.',
        ),
        GtCard(
          onTap: () async {
            final pin = await showPinSetup(context);
            if (pin != null) setState(() => _pin = pin);
          },
          child: Row(
            children: [
              Icon(
                _pin == null ? Ph.lockSimpleOpen : PhFill.lockSimple,
                color: _pin == null ? c.muted : c.laurel,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _pin == null ? 'Set a 4-digit PIN' : 'PIN set',
                  style: context.tt.titleSmall,
                ),
              ),
              if (_pin != null)
                TextButton(
                  onPressed: () => setState(() => _pin = null),
                  child: const Text('Remove'),
                )
              else
                Icon(Ph.caretRight, size: 14, color: c.faint),
            ],
          ),
        ),
        if (_pin != null && _canBio) ...[
          const SizedBox(height: 8),
          GtCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Icon(Ph.fingerprint, color: c.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unlock with fingerprint',
                    style: context.tt.titleSmall,
                  ),
                ),
                Switch(value: _bio, onChanged: (v) => setState(() => _bio = v)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'If you forget the PIN, the only way back in is to erase the app\'s data. Keep a backup.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }

  Widget _start(BuildContext context) {
    final c = context.gt;
    Widget option(bool sample, IconData icon, String title, String hint) {
      final on = _sample == sample;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GtCard(
          onTap: () => setState(() => _sample = sample),
          borderColor: on ? c.primaryText : null,
          child: Row(
            children: [
              Icon(icon, color: on ? c.primaryText : c.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleSmall),
                    Text(hint, style: context.tt.bodySmall),
                  ],
                ),
              ),
              Icon(
                on ? PhFill.radioButton : Ph.circle,
                color: on ? c.primaryText : c.faint,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'Ready',
          'Start with your own subjects, or explore with a sample semester first. You can delete everything later.',
        ),
        option(
          false,
          Ph.books,
          'Start empty',
          'Add your ${_termKind.label} subjects next.',
        ),
        option(
          true,
          Ph.student,
          'Sample semester',
          '3 terms of BSIT subjects with scores, from the project proposal.',
        ),
      ],
    );
  }
}
