import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/providers.dart';
import '../../core/services/gradebook.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';
import '../scores/score_sheet.dart';

/// Derived reminders: overdue (no score recorded) and due within 3 days.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    final prefs = ref.watch(prefsProvider);
    if (gb == null) return const PageScaffold(title: 'Reminders', children: []);
    final now = DateTime.now();
    final today = dayOf(now);
    final items = gb.upcoming();
    final overdue = items
        .where((u) => dayOf(u.score.date).isBefore(today))
        .toList();
    final soon = items.where((u) {
      final d = dayOf(u.score.date);
      return !d.isBefore(today) &&
          !d.isAfter(today.add(const Duration(days: 3)));
    }).toList();

    return PageScaffold(
      title: 'Reminders',
      children: [
        GtCard(
          onTap: () => context.push('/settings'),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                prefs.remindersOn
                    ? PhosphorIconsRegular.bellRinging
                    : PhosphorIconsRegular.bellSlash,
                color: prefs.remindersOn ? c.primaryText : c.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  prefs.remindersOn
                      ? 'Notifications on: ${prefs.reminderDaysBefore == 0 ? 'same day' : '${prefs.reminderDaysBefore} day${prefs.reminderDaysBefore == 1 ? '' : 's'} before'} at ${prefs.reminderTime.format(context)}.'
                      : 'Notifications are off. Turn them on in Settings.',
                  style: context.tt.bodyMedium,
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 14, color: c.faint),
            ],
          ),
        ),
        if (overdue.isEmpty && soon.isEmpty)
          const EmptyState(
            icon: PhosphorIconsRegular.bell,
            title: 'All clear',
            hint:
                'Nothing is due in the next 3 days and no scores are missing.',
          ),
        if (overdue.isNotEmpty) ...[
          const SectionLabel('Missing scores'),
          for (final u in overdue)
            _Reminder(
              item: u,
              now: now,
              tone: c.red,
              text:
                  'Was due ${fmtRelative(u.score.date, now).toLowerCase()}. Record the score.',
            ),
        ],
        if (soon.isNotEmpty) ...[
          const SectionLabel('Due soon'),
          for (final u in soon)
            _Reminder(
              item: u,
              now: now,
              tone: c.amber,
              text:
                  '${fmtRelative(u.score.date, now)} · ${fmtNum(u.component.weight)}% of grade',
            ),
        ],
      ],
    );
  }
}

class _Reminder extends StatelessWidget {
  const _Reminder({
    required this.item,
    required this.now,
    required this.tone,
    required this.text,
  });
  final UpcomingItem item;
  final DateTime now;
  final Color tone;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GtCard(
      onTap: () => openScoreSheet(context, existing: item.score, record: true),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          CodeTile(subject: item.subject, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.score.title,
                  style: context.tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  text,
                  style: context.tt.bodySmall!.copyWith(color: tone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
