import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/tokens.dart';

/// Opens a full-height form sheet (theria CompactFormModal as an Android sheet).
Future<T?> showFormSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: builder,
  );
}

/// Sheet layout: drag handle, header (✕ · title · ✓), scrolling body.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.onSubmit,
    this.submitting = false,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Null hides the ✓ button.
  final VoidCallback? onSubmit;
  final bool submitting;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(PhosphorIconsRegular.x, color: c.muted),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: context.tt.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: context.tt.bodySmall,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (onSubmit != null)
                  IconButton.filled(
                    tooltip: 'Save',
                    onPressed: submitting
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            onSubmit!();
                          },
                    style: IconButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                    ),
                    icon: const Icon(PhosphorIconsBold.check, size: 20),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Gt.pad, 8, Gt.pad, Gt.pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gt.pad, 0, Gt.pad, 12),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}

/// Small uppercase field label used above custom inputs.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: context.tt.labelSmall)),
        ?trailing,
      ],
    ),
  );
}
