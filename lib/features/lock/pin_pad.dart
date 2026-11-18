import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/form_sheet.dart';

/// Four dots showing how many digits are entered.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.count, this.error = false});
  final int count;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return Semantics(
      label: '$count of 4 digits entered',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            AnimatedContainer(
              duration: Gt.fast,
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < count
                    ? (error ? c.red : c.text)
                    : Colors.transparent,
                border: Border.all(
                  color: error ? c.red : (i < count ? c.text : c.faint),
                  width: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Numeric keypad: 1–9, [extra] (e.g. fingerprint), 0, backspace.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.extra,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    Widget key(String d) => _Key(
      label: d,
      onTap: () {
        HapticFeedback.selectionClick();
        onDigit(d);
      },
      child: Text(
        d,
        style: mono(26, weight: FontWeight.w500, color: c.text),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 84, height: 72, child: Center(child: extra)),
            key('0'),
            _Key(
              label: 'Delete',
              onTap: onBackspace,
              child: Icon(Ph.backspace, color: c.muted, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: SizedBox(
      width: 84,
      height: 72,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(child: child),
      ),
    ),
  );
}

/// Asks for a new PIN twice. Returns the PIN or null if cancelled.
Future<String?> showPinSetup(BuildContext context) =>
    showFormSheet<String>(context, (_) => const _PinSetupSheet());

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  String _first = '';
  String _entry = '';
  bool _confirming = false;
  bool _mismatch = false;

  void _digit(String d) {
    if (_entry.length >= 4) return;
    setState(() {
      _mismatch = false;
      _entry += d;
    });
    if (_entry.length < 4) return;
    if (!_confirming) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() {
          _first = _entry;
          _entry = '';
          _confirming = true;
        });
      });
    } else if (_entry == _first) {
      Navigator.of(context).pop(_entry);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _mismatch = true;
        _entry = '';
        _first = '';
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: _confirming ? 'Confirm PIN' : 'New PIN',
    children: [
      const SizedBox(height: 8),
      Text(
        _mismatch
            ? 'PINs did not match. Try again.'
            : (_confirming
                  ? 'Enter the same 4 digits again.'
                  : 'Choose 4 digits to lock GradeTrack.'),
        textAlign: TextAlign.center,
        style: context.tt.bodyMedium!.copyWith(
          color: _mismatch ? context.gt.red : context.gt.muted,
        ),
      ),
      const SizedBox(height: 18),
      Center(
        child: PinDots(count: _entry.length, error: _mismatch),
      ),
      const SizedBox(height: 18),
      PinPad(
        onDigit: _digit,
        onBackspace: () => setState(
          () => _entry = _entry.isEmpty
              ? ''
              : _entry.substring(0, _entry.length - 1),
        ),
      ),
    ],
  );
}
