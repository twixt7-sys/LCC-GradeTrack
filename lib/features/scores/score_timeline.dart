import 'package:lcc_gradetrack/ui.dart';

import '../../core/models/models.dart';
import '../../core/services/grade_calculator.dart';
import '../../core/services/gradebook.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/primitives.dart';

/// Date-grouped timeline (theria RecordTimeline): date label column, rail with
/// dots colored by result, and a card per score.
class ScoreTimeline extends StatelessWidget {
  const ScoreTimeline({
    super.key,
    required this.scores,
    required this.gradebook,
    required this.onTap,
  });

  final List<Score> scores;
  final Gradebook gradebook;
  final ValueChanged<Score> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    DateTime? last;
    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      final d = dayOf(s.date);
      final first = last == null || d != last;
      last = d;
      final isLast = i == scores.length - 1;
      rows.add(
        _TimelineRow(
          score: s,
          gradebook: gradebook,
          showDate: first,
          isLast: isLast,
          onTap: () => onTap(s),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.score,
    required this.gradebook,
    required this.showDate,
    required this.isLast,
    required this.onTap,
  });

  final Score score;
  final Gradebook gradebook;
  final bool showDate;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final subject = gradebook.subjectOfScore(score);
    final comp = gradebook.componentById(score.componentId);
    if (subject == null || comp == null) return const SizedBox.shrink();
    final scale = gradebook.scaleFor(subject);
    final pct = score.percent;
    final dot = score.isUpcoming
        ? c.amber
        : c.standing(
            Standing.of(gradebook.calculator.equivalentFor(pct!, scale)),
          );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: showDate
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmtMd(score.date).toUpperCase(),
                          style: context.tt.labelSmall!.copyWith(fontSize: 10),
                        ),
                        Text(
                          fmtDay(score.date),
                          style: context.tt.bodySmall!.copyWith(
                            fontSize: 10,
                            color: c.faint,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          SizedBox(
            width: 18,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 22 : null,
                  child: Container(width: 1, color: c.hairline),
                ),
                Positioned(
                  top: 17,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: dot, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GtCard(
                onTap: onTap,
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                radius: Gt.radiusSm + 2,
                child: Row(
                  children: [
                    CodeTile(subject: subject, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.title,
                            style: context.tt.titleSmall!.copyWith(
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${comp.name} · ${subject.code}',
                            style: context.tt.bodySmall!.copyWith(
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (score.isUpcoming)
                          Text(
                            'Upcoming',
                            style: context.tt.labelMedium!.copyWith(
                              color: c.amber,
                            ),
                          )
                        else
                          Num(
                            fmtPct(
                              pct,
                              dp: pct! == pct.roundToDouble() ? 0 : 1,
                            ),
                            size: 14,
                            weight: FontWeight.w700,
                            color: dot,
                          ),
                        const SizedBox(height: 1),
                        Num(
                          score.isUpcoming
                              ? '— /${fmtNum(score.total)}'
                              : '${fmtNum(score.score)}/${fmtNum(score.total)}',
                          size: 11,
                          color: c.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
