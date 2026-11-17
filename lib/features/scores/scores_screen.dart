import 'package:collection/collection.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/primitives.dart';
import 'score_sheet.dart';
import 'score_timeline.dart';

enum Scope {
  week('Week', PhosphorIconsRegular.square),
  month('Month', PhosphorIconsRegular.rows),
  term('Term', PhosphorIconsRegular.gridFour),
  all('All', PhosphorIconsRegular.circle);

  const Scope(this.label, this.icon);
  final String label;
  final IconData icon;
  Scope get next => Scope.values[(index + 1) % Scope.values.length];
}

enum StatusFilter { all, graded, upcoming }

class ScoresScreen extends ConsumerStatefulWidget {
  const ScoresScreen({super.key});

  @override
  ConsumerState<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends ConsumerState<ScoresScreen> {
  final _search = TextEditingController();
  Scope _scope = Scope.term;
  bool _filterOpen = false;
  int? _subjectId;
  StatusFilter _status = StatusFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered => _subjectId != null || _status != StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    if (gb == null) return const Center(child: CircularProgressIndicator());
    final term = gb.currentTerm;
    final now = DateTime.now();
    final today = dayOf(now);
    final q = _search.text.trim().toLowerCase();

    final termIds = _scope == Scope.all ? null : term?.id;
    final subjectIds = gb.subjectsIn(termIds).map((s) => s.id).toSet();
    final scores = gb.scores
        .where((s) {
          final subj = gb.subjectOfScore(s);
          if (subj == null || !subjectIds.contains(subj.id)) return false;
          if (_subjectId != null && subj.id != _subjectId) return false;
          if (_status == StatusFilter.graded && s.isUpcoming) return false;
          if (_status == StatusFilter.upcoming && !s.isUpcoming) return false;
          final d = dayOf(s.date);
          if (_scope == Scope.week &&
              (d.isBefore(today.subtract(const Duration(days: 6))) ||
                  d.isAfter(today.add(const Duration(days: 7))))) {
            return false;
          }
          if (_scope == Scope.month &&
              (d.isBefore(today.subtract(const Duration(days: 30))) ||
                  d.isAfter(today.add(const Duration(days: 30))))) {
            return false;
          }
          if (q.isNotEmpty) {
            final comp = gb.componentById(s.componentId);
            final hay =
                '${s.title} ${s.note} ${subj.code} ${subj.title} ${comp?.name ?? ''}'
                    .toLowerCase();
            if (!hay.contains(q)) return false;
          }
          return true;
        })
        .sorted((a, b) {
          final d = b.date.compareTo(a.date);
          return d != 0 ? d : (b.id ?? 0).compareTo(a.id ?? 0);
        });

    final graded = scores.where((s) => !s.isUpcoming).toList();
    final upcoming = scores.length - graded.length;
    final avg = graded.isEmpty ? null : graded.map((s) => s.percent!).average;

    return ListView(
      padding: EdgeInsets.fromLTRB(Gt.pad, 4, Gt.pad, shellBottomPad(context)),
      children: [
        // Toolbar: search · scope stepper · filter
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: StadiumBorder(side: BorderSide(color: c.hairline)),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 15,
                      color: c.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: context.tt.bodyMedium!.copyWith(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search scores',
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(_search.clear),
                        child: Icon(
                          PhosphorIconsRegular.x,
                          size: 14,
                          color: c.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'Range: ${_scope.label}. Tap to change.',
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _scope = _scope.next);
                },
                child: Row(
                  children: [
                    Container(
                      height: 38,
                      padding: const EdgeInsets.only(left: 12, right: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.raised,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(19),
                        ),
                      ),
                      child: Text(
                        _scope.label,
                        style: context.tt.labelMedium!.copyWith(fontSize: 11.5),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(-19, 0),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.inverse,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_scope.icon, size: 15, color: c.onInverse),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(-13, 0),
              child: Semantics(
                button: true,
                label: 'Filters',
                child: Material(
                  color: _filtered || _filterOpen ? c.primary : c.surface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: _filtered || _filterOpen ? c.primary : c.hairline,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _filterOpen = !_filterOpen),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        PhosphorIconsRegular.funnel,
                        size: 17,
                        color: _filtered || _filterOpen ? c.onPrimary : c.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: context.reduceMotion ? Duration.zero : Gt.med,
          curve: Gt.curve,
          alignment: Alignment.topCenter,
          child: !_filterOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GtCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CapsuleSelector<StatusFilter>(
                          values: StatusFilter.values,
                          selected: _status,
                          height: 36,
                          labelOf: (s) => switch (s) {
                            StatusFilter.all => 'All',
                            StatusFilter.graded => 'Graded',
                            StatusFilter.upcoming => 'Upcoming',
                          },
                          onChanged: (s) => setState(() => _status = s),
                        ),
                        const SizedBox(height: 10),
                        ChipRow<int>(
                          values: [
                            -1,
                            for (final s in gb.subjectsIn(termIds)) s.id!,
                          ],
                          selected: _subjectId ?? -1,
                          labelOf: (id) => id == -1
                              ? 'All subjects'
                              : gb.subjectById(id)!.code,
                          onChanged: (id) =>
                              setState(() => _subjectId = id == -1 ? null : id),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        // Summary chips: Graded · Avg · Upcoming
        Row(
          children: [
            _Chip(
              icon: PhosphorIconsBold.checkCircle,
              text: '${graded.length} graded',
              fg: c.laurel,
              bg: c.laurel.withValues(alpha: 0.12),
              radius: const BorderRadius.horizontal(
                left: Radius.circular(16),
                right: Radius.circular(6),
              ),
            ),
            const SizedBox(width: 4),
            _Chip(
              icon: PhosphorIconsBold.percent,
              text: avg == null ? 'Avg —' : 'Avg ${fmtPct(avg, dp: 1)}',
              fg: c.text,
              bg: c.raised,
              radius: BorderRadius.circular(6),
            ),
            const SizedBox(width: 4),
            _Chip(
              icon: PhosphorIconsBold.hourglass,
              text: '$upcoming upcoming',
              fg: c.amber,
              bg: c.amber.withValues(alpha: 0.12),
              radius: const BorderRadius.horizontal(
                left: Radius.circular(6),
                right: Radius.circular(16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (scores.isEmpty)
          EmptyState(
            icon: PhosphorIconsRegular.listChecks,
            title: q.isNotEmpty || _filtered
                ? 'Nothing matches'
                : 'No scores in this range',
            hint: q.isNotEmpty || _filtered
                ? 'Clear the search or filters.'
                : 'Use + to record a quiz, activity or exam.',
          )
        else
          ScoreTimeline(
            scores: scores,
            gradebook: gb,
            onTap: (s) => openScoreSheet(context, existing: s),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.fg,
    required this.bg,
    required this.radius,
  });
  final IconData icon;
  final String text;
  final Color fg;
  final Color bg;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 32,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Num(text, size: 11.5, weight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Exposed for tests.
List<Score> sortScoresNewestFirst(Iterable<Score> s) =>
    s.sorted((a, b) => b.date.compareTo(a.date));
