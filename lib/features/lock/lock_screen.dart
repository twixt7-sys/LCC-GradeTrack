import 'package:lcc_gradetrack/ui.dart';

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/providers/providers.dart';
import '../../core/services/pin_service.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/primitives.dart';
import 'pin_pad.dart';

/// Full-screen PIN lock shown over the app.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  String _entry = '';
  bool _error = false;
  int _fails = 0;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final p = ref.read(gradebookProvider).value?.profile;
    if (p == null || !p.biometric) return;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock GradeTrack',
        biometricOnly: true,
      );
      if (ok && mounted) ref.read(lockProvider.notifier).unlock();
    } on Object {
      // Fall back to PIN.
    }
  }

  void _digit(String d) {
    if (_entry.length >= 4) return;
    setState(() {
      _error = false;
      _entry += d;
    });
    if (_entry.length == 4) _check();
  }

  void _check() {
    final p = ref.read(gradebookProvider).value?.profile;
    if (p == null ||
        !p.hasPin ||
        PinService.verify(_entry, p.pinSalt!, p.pinHash!)) {
      ref.read(lockProvider.notifier).unlock();
      return;
    }
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _fails++;
      _error = true;
      _entry = '';
    });
  }

  Future<void> _forgot() async {
    final ok = await confirmAction(
      context,
      title: 'Forgot your PIN?',
      body: 'There is no account to recover it. The only way in is to delete all data on this phone and start over. Restore a backup afterwards if you have one.',
      confirm: 'Delete all data',
    );
    if (!ok) return;
    await ref.read(gradebookProvider.notifier).mutate((r) => r.wipe());
    await ref.read(prefsProvider).setOnboarded(false);
    ref.read(lockProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final p = ref.watch(gradebookProvider).value?.profile;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Image.asset(
              'assets/brand/lcc_logo_512.png',
              width: 72,
              height: 72,
              cacheWidth: 240,
            ),
            const SizedBox(height: 14),
            Text(
              p == null ? 'Enter PIN' : 'Hi, ${p.firstName}',
              style: context.tt.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _error
                  ? 'Wrong PIN${_fails >= 3 ? ' · $_fails tries' : ''}'
                  : 'Enter your PIN',
              style: context.tt.bodyMedium!.copyWith(
                color: _error ? c.red : c.muted,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                // Damped horizontal shake on a wrong PIN.
                final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
                return Transform.translate(
                  offset: Offset(_shake.isAnimating ? dx : 0, 0),
                  child: child,
                );
              },
              child: PinDots(count: _entry.length, error: _error),
            ),
            const Spacer(),
            PinPad(
              onDigit: _digit,
              onBackspace: () => setState(
                () => _entry = _entry.isEmpty
                    ? ''
                    : _entry.substring(0, _entry.length - 1),
              ),
              extra: (p?.biometric ?? false)
                  ? IconButton(
                      tooltip: 'Use fingerprint',
                      onPressed: _tryBiometric,
                      icon: Icon(
                        Ph.fingerprint,
                        size: 28,
                        color: c.primaryText,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _forgot,
              style: TextButton.styleFrom(foregroundColor: c.muted),
              child: const Text('Forgot PIN'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
