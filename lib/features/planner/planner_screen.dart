import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/providers.dart';
import '../../core/services/gradebook.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/primitives.dart';
import '../scores/score_sheet.dart';

/// Ungraded assessments grouped by urgency. Tap to record the score.
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final today = dayOf(now);
    final items = gb.upcoming(termId: gb.currentTerm?.id);
    final overdue = items
        .where((u) => dayOf(u.score.date).isBefore(today))
        .toList();
    final week = items.where((u) {
      final d = dayOf(u.score.date);
      return !d.isBefore(today) &&
          !d.isAfter(today.add(const Duration(days: 7)));
    }).toList();
    final later = items
        .where(
          (u) =>
              dayOf(u.score.date).isAfter(today.add(const Duration(days: 7))),
        )
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(Gt.pad, 4, Gt.pad, shellBottomPad(context)),
      children: [
        if (items.isEmpty)
          GtCard(
            child: EmptyState(
              icon: PhosphorIconsRegular.calendarDots,
              title: 'Nothing planned',
              hint: 'Add quizzes and exams before they happen. They count toward your target and show up in reminders.',
              action: 'Add assessment',
              onAction: () => openScoreSheet(context, upcoming: true),
            ),
          ),
        if (overdue.isNotEmpty)
          _Group(
            title: 'Overdue · record the score',
            items: overdue,
            now: now,
            tone: context.gt.red,
          ),
        if (week.isNotEmpty)
          _Group(
            title: 'Next 7 days',
            items: week,
            now: now,
            tone: context.gt.amber,
          ),
        if (later.isNotEmpty)
          _Group(
            title: 'Later',
            items: later,
            now: now,
            tone: context.gt.muted,
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.items,
    required this.now,
    required this.tone,
  });
  final String title;
  final List<UpcomingItem> items;
  final DateTime now;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionLabel(title),
      for (final u in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PlanCard(item: u, now: now, tone: tone),
        ),
    ],
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.item, required this.now, required this.tone});
  final UpcomingItem item;
  final DateTime now;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final d = item.score.date;
    return GtCard(
      onTap: () => openScoreSheet(context, existing: item.score, record: true),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: tone.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  fmtDay(d).toUpperCase(),
                  style: context.tt.labelSmall!.copyWith(
                    color: tone,
                    fontSize: 9.5,
                  ),
                ),
                Num('${d.day}', size: 18, weight: FontWeight.w700),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CodeTile(subject: item.subject, size: 20),
                    const SizedBox(width: 6),
                    Num(
                      item.subject.code,
                      size: 12,
                      weight: FontWeight.w700,
                      color: c.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.score.title,
                  style: context.tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.component.name} · ${fmtNum(item.component.weight)}% of grade · ${fmtNum(item.score.total)} items',
                  style: context.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtRelative(d, now),
                style: context.tt.labelMedium!.copyWith(color: tone),
              ),
              const SizedBox(height: 6),
              Icon(PhosphorIconsRegular.notePencil, size: 18, color: c.muted),
            ],
          ),
        ],
      ),
    );
  }
}
