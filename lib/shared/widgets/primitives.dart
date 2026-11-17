import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/models.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Mono, tabular number or code.
class Num extends StatelessWidget {
  const Num(
    this.text, {
    super.key,
    this.size = 14,
    this.weight = FontWeight.w500,
    this.color,
    this.align,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    maxLines: 1,
    softWrap: false,
    style: mono(size, weight: weight, color: color ?? context.gt.text),
  );
}

/// Flat card: surface fill, 1px hairline, no shadow.
class GtCard extends StatelessWidget {
  const GtCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gt.pad),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.radius = Gt.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? c.hairline),
    );
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Uppercase tracked section label with an optional trailing action.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.onTrailing});
  final String text;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: context.tt.labelSmall)),
        if (trailing != null)
          InkWell(
            onTap: onTrailing,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                trailing!,
                style: context.tt.labelMedium!.copyWith(
                  color: context.gt.primaryText,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Flat subject tile with the code stacked in mono: "IT" over "126".
class CodeTile extends StatelessWidget {
  const CodeTile({super.key, required this.subject, this.size = 44});
  final Subject subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (prefix, number) = subject.codeParts;
    const fg = Colors.white;
    final big = size >= 40;
    return Semantics(
      label: subject.code,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: subjectColor(subject.colorIdx),
          borderRadius: BorderRadius.circular(size * 0.26),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prefix,
                style: mono(
                  big ? 12 : 10,
                  weight: FontWeight.w700,
                  color: fg,
                  height: 1.05,
                ),
              ),
              if (number.isNotEmpty)
                Text(
                  number,
                  style: mono(
                    big ? 12 : 10,
                    weight: FontWeight.w500,
                    color: fg.withValues(alpha: 0.85),
                    height: 1.05,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar with a fixed tick at the passing mark.
class ScaleBar extends StatelessWidget {
  const ScaleBar({
    super.key,
    required this.percent,
    required this.passing,
    required this.color,
    this.height = 6,
  });

  final double? percent;
  final double passing;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final v = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    return Semantics(
      label: percent == null
          ? 'No grade yet'
          : '${percent!.toStringAsFixed(1)} percent, passing ${passing.toStringAsFixed(0)}',
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return SizedBox(
            height: height + 6,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
                AnimatedContainer(
                  duration: Gt.med,
                  curve: Gt.curve,
                  height: height,
                  width: w * v,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
                Positioned(
                  left: (w * passing / 100 - 1).clamp(0, w - 2),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: c.text.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Standing as icon + text. Never color alone.
class StandingTag extends StatelessWidget {
  const StandingTag(this.standing, {super.key, this.compact = false});
  final Standing standing;
  final bool compact;

  static IconData iconFor(Standing s) => switch (s) {
    Standing.strong => PhosphorIconsBold.arrowUp,
    Standing.onTrack => PhosphorIconsBold.check,
    Standing.atRisk => PhosphorIconsBold.warning,
    Standing.failing => PhosphorIconsBold.x,
    Standing.none => PhosphorIconsBold.minus,
  };

  @override
  Widget build(BuildContext context) {
    final color = context.gt.standing(standing);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconFor(standing), size: compact ? 12 : 14, color: color),
        const SizedBox(width: 4),
        Text(
          standing.label,
          style: (compact ? context.tt.labelMedium : context.tt.labelLarge)!
              .copyWith(color: color, fontSize: compact ? 11.5 : 13),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.sub,
    this.trailing,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => GtCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.tt.bodySmall, maxLines: 1),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Num(
                  value,
                  size: 22,
                  weight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, style: context.tt.bodySmall, maxLines: 1),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String hint;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: c.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: c.muted, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: context.tt.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(hint, style: context.tt.bodySmall, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Row that opens a picker: icon chip, small label over value, chevron.
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.valueWidget,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return GtCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: Gt.radiusSm + 2,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: context.tt.labelSmall!.copyWith(fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                valueWidget ??
                    Text(
                      value,
                      style: context.tt.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(PhosphorIconsRegular.caretRight, size: 16, color: c.faint),
        ],
      ),
    );
  }
}

/// Segmented capsule with a sliding selected pill (theria CapsuleSelector).
class CapsuleSelector<T> extends StatelessWidget {
  const CapsuleSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.height = 40,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final idx = values.indexOf(selected).clamp(0, values.length - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(height),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: context.reduceMotion ? Duration.zero : Gt.med,
                curve: Gt.curve,
                left: idx * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(height),
                    border: Border.all(color: c.hairline),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final v in values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: v == selected,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(height),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(v);
                          },
                          child: Center(
                            child: Text(
                              labelOf(v),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.labelMedium!.copyWith(
                                color: v == selected ? c.text : c.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal scrolling chips (term filter).
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final v = values[i];
          final on = v == selected;
          return Material(
            color: on ? c.inverse : c.surface,
            shape: StadiumBorder(
              side: BorderSide(color: on ? c.inverse : c.hairline),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    labelOf(v),
                    style: context.tt.labelMedium!.copyWith(
                      color: on ? c.onInverse : c.text,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  final c = context.gt;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? PhosphorIconsBold.warningCircle
                  : PhosphorIconsBold.checkCircle,
              size: 18,
              color: error ? c.red : c.onInverse,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(milliseconds: 2400),
      ),
    );
}

/// Confirmation dialog for destructive actions.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  String confirm = 'Delete',
  bool destructive = true,
}) async {
  final c = context.gt;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: c.muted),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? c.red : c.primaryText,
          ),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Simple screen padding for pushed (non-shell) pages.
const pagePad = EdgeInsets.fromLTRB(Gt.pad, 8, Gt.pad, 32);
