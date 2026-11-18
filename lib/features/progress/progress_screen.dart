import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/gradebook.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/primitives.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const Center(child: CircularProgressIndicator());
    final term = gb.currentTerm;
    final points = [
      for (final t in gb.terms)
        if (gb.termGwa(t.id!).gwa case final g?) (t, g),
    ];
    final current = term == null ? null : gb.termGwa(term.id!).gwa;
    final prev = term == null ? null : gb.previousTerm(term);
    final prevGwa = prev == null ? null : gb.termGwa(prev.id!).gwa;
    final trend = (current != null && prevGwa != null)
        ? double.parse(current.toStringAsFixed(2)) -
              double.parse(prevGwa.toStringAsFixed(2))
        : null;

    Widget trendIcon() {
      if (trend == null || trend.abs() < 0.005) {
        return Icon(PhBold.minus, size: 20, color: c.muted);
      }
      // Lower GWA = better.
      return Icon(
        trend < 0 ? PhFill.triangle : PhFill.triangle,
        size: 18,
        color: trend < 0 ? c.laurel : c.red,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(Gt.pad, 4, Gt.pad, shellBottomPad(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Current GWA',
                value: fmtGrade(current),
                valueColor: c.primaryText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Units earned',
                value: fmtNum(gb.unitsEarned),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Trend',
                value: trend == null ? '—' : trend.abs().toStringAsFixed(2),
                valueColor: trend == null
                    ? c.faint
                    : (trend <= 0 ? c.laurel : c.red),
                trailing: trend == null
                    ? null
                    : RotatedBox(
                        quarterTurns: trend < 0 ? 0 : 2,
                        child: trendIcon(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GtCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GWA per term', style: context.tt.titleMedium),
              Text(
                'Lower is better (1.00 is the highest grade)',
                style: context.tt.bodySmall,
              ),
              const SizedBox(height: 14),
              if (points.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    points.isEmpty
                        ? 'No graded terms yet.'
                        : 'The trend appears once two terms have grades.',
                    style: context.tt.bodySmall,
                  ),
                )
              else
                SizedBox(
                  height: 190,
                  child: _GwaChart(points: points, currentId: term?.id),
                ),
              if (points.length == 1)
                Row(
                  children: [
                    Text(
                      points.first.$1.shortLabel,
                      style: context.tt.bodySmall,
                    ),
                    const Spacer(),
                    Num(
                      fmtGrade(points.first.$2),
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _BySubject(gb: gb, term: term),
        const SizedBox(height: 10),
        _Distribution(gb: gb),
      ],
    );
  }
}

class _GwaChart extends StatelessWidget {
  const _GwaChart({required this.points, required this.currentId});
  final List<(Term, double)> points;
  final int? currentId;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final values = points.map((p) => p.$2);
    // Inverted axis: plot -gwa so better grades sit higher.
    final lo = (values.reduce(math.min) * 4).floor() / 4 - 0.25;
    final hi = (values.reduce(math.max) * 4).ceil() / 4 + 0.25;
    return LineChart(
      LineChartData(
        minX: -0.3,
        maxX: points.length - 0.7,
        minY: -hi,
        maxY: -lo,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.hairline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.inverse,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${points[s.x.toInt()].$1.shortLabel}\n${(-s.y).toStringAsFixed(2)}',
                  mono(11, weight: FontWeight.w700, color: c.onInverse),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: 0.25,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  (-v).toStringAsFixed(2),
                  style: mono(10, color: c.muted),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if ((v - i).abs() > 0.01 || i < 0 || i >= points.length) {
                  return const SizedBox();
                }
                final t = points[i].$1;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${t.kind.label}\n${t.startYear % 100}–${(t.startYear + 1) % 100}',
                    textAlign: TextAlign.center,
                    style: context.tt.bodySmall!.copyWith(
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in points.indexed) FlSpot(i.toDouble(), -p.$2),
            ],
            color: c.primary,
            barWidth: 2.5,
            isCurved: false,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                radius: 4.5,
                color: c.surface,
                strokeWidth: 2.5,
                strokeColor: points[i].$1.id == currentId
                    ? c.primaryText
                    : c.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BySubject extends StatelessWidget {
  const _BySubject({required this.gb, required this.term});
  final Gradebook gb;
  final Term? term;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final results =
        gb.resultsIn(term?.id).where((r) => r.percent != null).toList()
          ..sort((a, b) => a.subject.code.compareTo(b.subject.code));
    final passing = gb.defaultScale.passingPercent;
    return GtCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This term by subject', style: context.tt.titleMedium),
          Text(
            'Current %; the tick marks passing (${fmtNum(passing)}%)',
            style: context.tt.bodySmall,
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            Text('No graded subjects yet.', style: context.tt.bodySmall),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Num(
                      r.subject.code,
                      size: 12,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: ScaleBar(
                      percent: r.percent,
                      passing: passing,
                      height: 8,
                      color: r.percent! < passing
                          ? c.red
                          : subjectColor(r.subject.colorIdx),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Num(
                      r.percent!.toStringAsFixed(1),
                      size: 12,
                      weight: FontWeight.w600,
                      align: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.gb});
  final Gradebook gb;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final scale = gb.defaultScale.sorted();
    final steps = [
      ...[for (final r in scale.rows) r.equivalent]..sort(),
      scale.failingEquivalent,
    ];
    final counts = {for (final s in steps) s: 0};
    for (final r in gb.resultsIn(null)) {
      final e = r.equivalent;
      if (e == null || r.mark != null) continue;
      final key = steps.firstWhere(
        (s) => (s - e).abs() < 1e-9,
        orElse: () =>
            steps.reduce((a, b) => (a - e).abs() < (b - e).abs() ? a : b),
      );
      counts[key] = counts[key]! + 1;
    }
    final maxCount = counts.values.fold(0, math.max);
    return GtCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grade distribution', style: context.tt.titleMedium),
          Text('All subjects across terms', style: context.tt.bodySmall),
          const SizedBox(height: 14),
          if (maxCount == 0)
            Text('No grades yet.', style: context.tt.bodySmall)
          else
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: maxCount + 1.0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 18,
                        getTitlesWidget: (v, meta) {
                          final n = counts[steps[v.toInt()]]!;
                          return SideTitleWidget(
                            meta: meta,
                            child: n == 0
                                ? const SizedBox()
                                : Text(
                                    '$n',
                                    style: mono(
                                      10,
                                      weight: FontWeight.w700,
                                      color: c.text,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            steps[v.toInt()].toStringAsFixed(2),
                            style: mono(
                              9,
                              color: steps[v.toInt()] > scale.passingEquivalent
                                  ? c.red
                                  : c.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final (i, s) in steps.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: counts[s]!.toDouble(),
                            width: 14,
                            color: s > scale.passingEquivalent
                                ? c.red
                                : (s <= 1.75 ? c.laurel : c.primary),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
