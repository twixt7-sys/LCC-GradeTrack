import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/services/pin_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';
import '../lock/pin_pad.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _canBio;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    try {
      final auth = LocalAuthentication();
      final ok =
          await auth.isDeviceSupported() && await auth.canCheckBiometrics;
      if (mounted) setState(() => _canBio = ok);
    } on Object {
      if (mounted) setState(() => _canBio = false);
    }
  }

  Future<void> _reschedule() =>
      ref.read(gradebookProvider.notifier).rescheduleReminders();

  Future<void> _toggleReminders(bool on) async {
    final prefs = ref.read(prefsProvider);
    if (on && ref.read(remindersEnabledProvider)) {
      final granted = await ReminderService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          showToast(
            context,
            'Allow notifications for GradeTrack in Android settings.',
            error: true,
          );
        }
        return;
      }
    }
    await prefs.setRemindersOn(on);
    setState(() {});
    await _reschedule();
  }

  Future<void> _setPin(Profile p) async {
    final pin = await showPinSetup(context);
    if (pin == null) return;
    final salt = PinService.newSalt();
    final hash = PinService.hash(pin, salt);
    await ref
        .read(gradebookProvider.notifier)
        .mutate(
          (r) => r.saveProfile(
            p.copyWith(pinHash: () => hash, pinSalt: () => salt),
          ),
        );
    if (mounted) showToast(context, 'PIN set');
  }

  Future<void> _removePin(Profile p) async {
    final ok = await confirmAction(
      context,
      title: 'Remove PIN?',
      body: 'The app will open without a lock.',
      confirm: 'Remove',
    );
    if (!ok) return;
    await ref
        .read(gradebookProvider.notifier)
        .mutate(
          (r) => r.saveProfile(
            p.copyWith(
              pinHash: () => null,
              pinSalt: () => null,
              biometric: false,
            ),
          ),
        );
    if (mounted) showToast(context, 'PIN removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final prefs = ref.watch(prefsProvider);
    final mode = ref.watch(themeModeProvider);
    final rounding = ref.watch(roundingProvider);
    final gb = ref.watch(gradebookProvider).value;
    final p = gb?.profile;

    return PageScaffold(
      title: 'Settings',
      children: [
        const SectionLabel('Appearance'),
        CapsuleSelector<ThemeMode>(
          values: const [ThemeMode.system, ThemeMode.dark, ThemeMode.light],
          selected: mode,
          labelOf: (m) => switch (m) {
            ThemeMode.system => 'System',
            ThemeMode.dark => 'Dark',
            ThemeMode.light => 'Light',
          },
          onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
        ),
        const SectionLabel('Grading'),
        _Group(
          children: [
            _NavRow(
              icon: Ph.ruler,
              title: 'Grade scale',
              value: gb?.defaultScale.name ?? '',
              onTap: () => context.push('/settings/scale'),
            ),
            _NavRow(
              icon: Ph.squaresFour,
              title: 'Default components',
              value: prefs.componentTemplate.map((x) => x.name).join(', '),
              onTap: () => context.push('/settings/components'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Labeled(
          title: 'Rounding before conversion',
          hint: 'Applied to the subject % before it is looked up in the scale.',
          child: CapsuleSelector<RoundingRule>(
            values: RoundingRule.values,
            selected: rounding,
            labelOf: (r) => switch (r) {
              RoundingRule.none => 'None',
              RoundingRule.twoDecimals => '2 decimals',
              RoundingRule.whole => 'Whole',
            },
            onChanged: (r) => ref.read(roundingProvider.notifier).set(r),
          ),
        ),
        const SizedBox(height: 12),
        _Labeled(
          title: 'Default component average',
          hint: 'Used for new subjects. Each subject can change it.',
          child: CapsuleSelector<AvgMethod>(
            values: AvgMethod.values,
            selected: prefs.defaultAvgMethod,
            labelOf: (m) =>
                m == AvgMethod.meanPercent ? 'Mean of %' : 'Total points',
            onChanged: (m) async {
              await prefs.setDefaultAvgMethod(m);
              setState(() {});
            },
          ),
        ),
        const SectionLabel('Reminders'),
        _Group(
          children: [
            _SwitchRow(
              icon: Ph.bell,
              title: 'Assessment reminders',
              hint: 'A notification before each upcoming quiz or exam.',
              value: prefs.remindersOn,
              onChanged: _toggleReminders,
            ),
            if (prefs.remindersOn) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: CapsuleSelector<int>(
                  values: const [0, 1, 2, 3],
                  selected: prefs.reminderDaysBefore,
                  labelOf: (d) =>
                      d == 0 ? 'Same day' : '$d day${d == 1 ? '' : 's'}',
                  onChanged: (d) async {
                    await prefs.setReminderDaysBefore(d);
                    setState(() {});
                    await _reschedule();
                  },
                ),
              ),
              _NavRow(
                icon: Ph.clock,
                title: 'Time',
                value: prefs.reminderTime.format(context),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: prefs.reminderTime,
                  );
                  if (t == null) return;
                  await prefs.setReminderTime(t);
                  setState(() {});
                  await _reschedule();
                },
              ),
            ],
          ],
        ),
        const SectionLabel('Security'),
        if (p == null)
          Text('Create a profile first.', style: context.tt.bodySmall)
        else
          _Group(
            children: [
              _NavRow(
                icon: Ph.lockSimple,
                title: p.hasPin ? 'Change PIN' : 'Set a 4-digit PIN',
                value: p.hasPin ? 'On' : 'Off',
                onTap: () => _setPin(p),
              ),
              if (p.hasPin) ...[
                if (_canBio ?? false)
                  _SwitchRow(
                    icon: Ph.fingerprint,
                    title: 'Unlock with fingerprint',
                    value: p.biometric,
                    onChanged: (v) => ref
                        .read(gradebookProvider.notifier)
                        .mutate((r) => r.saveProfile(p.copyWith(biometric: v))),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lock after leaving the app',
                        style: context.tt.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      CapsuleSelector<int>(
                        values: const [0, 60, 300, 900],
                        selected: prefs.lockDelay,
                        labelOf: (s) => switch (s) {
                          0 => 'Now',
                          60 => '1 min',
                          300 => '5 min',
                          _ => '15 min',
                        },
                        onChanged: (s) async {
                          await prefs.setLockDelay(s);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                _NavRow(
                  icon: Ph.lockSimpleOpen,
                  title: 'Remove PIN',
                  value: '',
                  color: c.red,
                  onTap: () => _removePin(p),
                ),
              ],
            ],
          ),
        const SectionLabel('Data'),
        _Group(
          children: [
            _NavRow(
              icon: Ph.database,
              title: 'Backup, export and reset',
              value: '',
              onTap: () => context.push('/settings/data'),
            ),
            _NavRow(
              icon: Ph.info,
              title: 'About',
              value: '',
              onTap: () => context.push('/about'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GtCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, w) in children.indexed) ...[
          if (i > 0) const Divider(),
          w,
        ],
      ],
    ),
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.title,
    required this.hint,
    required this.child,
  });
  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => GtCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.tt.titleSmall),
        Text(hint, style: context.tt.bodySmall),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? c.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: context.tt.titleSmall!.copyWith(color: color),
              ),
            ),
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  style: context.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(width: 6),
            Icon(Ph.caretRight, size: 14, color: c.faint),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    this.hint,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.tt.titleSmall),
                  if (hint != null) Text(hint!, style: context.tt.bodySmall),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
