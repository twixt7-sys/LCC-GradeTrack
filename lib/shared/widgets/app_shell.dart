import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';

import '../../core/providers/providers.dart';
import '../../core/services/gradebook.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../features/history/term_sheet.dart';
import '../../features/scores/score_sheet.dart';
import '../../features/subjects/subject_sheet.dart';
import 'app_drawer.dart';
import 'app_tabs.dart';
import 'primitives.dart';

/// Bottom space screens must leave for the floating nav.
double shellBottomPad(BuildContext context) =>
    96 + MediaQuery.paddingOf(context).bottom;

/// Root of the tab screens (theria AppShell): top bar, content, floating nav.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _fabOpen = false;

  AppTab get _tab => AppTab.values[widget.shell.currentIndex];

  void _go(AppTab t) {
    HapticFeedback.selectionClick();
    if (t.group >= 0 && t.group != ref.read(navGroupProvider)) {
      ref.read(navGroupProvider.notifier).set(t.group);
    }
    widget.shell.goBranch(t.index, initialLocation: t == _tab);
  }

  void _switchGroup() {
    HapticFeedback.selectionClick();
    final g = ref.read(navGroupProvider) == 0 ? 1 : 0;
    ref.read(navGroupProvider.notifier).set(g);
    widget.shell.goBranch(AppTab.ofGroup(g).first.index);
  }

  Future<void> _fab() async {
    switch (_tab) {
      case AppTab.home:
        setState(() => _fabOpen = !_fabOpen);
      case AppTab.subjects:
        await openSubjectSheet(context);
      case AppTab.scores:
        await openScoreSheet(context);
      case AppTab.planner:
        await openScoreSheet(context, upcoming: true);
      case AppTab.history:
        await openTermSheet(context);
      case AppTab.progress:
      case AppTab.calculator:
        break;
    }
  }

  Future<void> _menuAction(Future<void> Function() action) async {
    setState(() => _fabOpen = false);
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    // The visible group follows the current tab (deep links, drawer, menus).
    final group = _tab.group >= 0 ? _tab.group : ref.watch(navGroupProvider);
    final gb = ref.watch(gradebookProvider).value;
    final showFab = _tab != AppTab.progress && _tab != AppTab.calculator;

    return PopScope(
      canPop: !_fabOpen && _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_fabOpen) {
          setState(() => _fabOpen = false);
        } else {
          _go(AppTab.home);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        body: Stack(
          children: [
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _TopBar(
                    tab: _tab,
                    gradebook: gb,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onUpcoming: () => _go(AppTab.planner),
                  ),
                ),
                Expanded(child: widget.shell),
              ],
            ),
            if (_fabOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _fabOpen = false),
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: c.isDark ? 0.6 : 0.35,
                    ),
                  ),
                ),
              ),
            if (_fabOpen)
              Positioned(
                right: 12,
                bottom: 84 + MediaQuery.paddingOf(context).bottom,
                child: _FabMenu(
                  onScore: () => _menuAction(() => openScoreSheet(context)),
                  onUpcoming: () => _menuAction(
                    () => openScoreSheet(context, upcoming: true),
                  ),
                  onSubject: () => _menuAction(() => openSubjectSheet(context)),
                  onTerm: () => _menuAction(() => openTermSheet(context)),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _BottomNav(
                    current: _tab,
                    group: group,
                    fabOpen: _fabOpen,
                    showFab: showFab,
                    onTab: _go,
                    onSwitch: _switchGroup,
                    onFab: _fab,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.child,
    required this.onTap,
    required this.label,
    this.border,
    this.color,
  });
  final Widget child;
  final VoidCallback onTap;
  final String label;
  final Color? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color ?? c.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: border ?? c.hairline,
            width: border != null ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.tab,
    required this.gradebook,
    required this.onMenu,
    required this.onUpcoming,
  });
  final AppTab tab;
  final Gradebook? gradebook;
  final VoidCallback onMenu;
  final VoidCallback onUpcoming;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = gradebook;
    final term = gb?.currentTerm;
    final now = DateTime.now();
    final due = gb == null ? 0 : gb.dueSoonCount(now, termId: term?.id);
    final overdue = gb == null
        ? 0
        : gb
              .upcoming(termId: term?.id)
              .where((u) => dayOf(u.score.date).isBefore(dayOf(now)))
              .length;
    final profile = gb?.profile;

    return SizedBox(
      height: Gt.topBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _Circle(
              label: 'Open menu',
              onTap: onMenu,
              child: ClipOval(
                child: Image.asset(
                  'assets/brand/lcc_logo_512.png',
                  width: 30,
                  height: 30,
                  cacheWidth: 120,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: StadiumBorder(side: BorderSide(color: c.hairline)),
              ),
              alignment: Alignment.center,
              child: Text(tab.label, style: context.tt.titleSmall),
            ),
            Expanded(
              child: term == null
                  ? const SizedBox()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              term.kind.label,
                              style: context.tt.labelMedium!.copyWith(
                                color: c.muted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              term.ayLabel,
                              style: mono(9.5, color: c.faint),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Tooltip(
              message: '$due due in the next 7 days',
              child: _Circle(
                label: '$due assessments due in the next 7 days',
                onTap: onUpcoming,
                border: due > 0 ? c.amber : null,
                color: due > 0 ? c.amber.withValues(alpha: 0.10) : null,
                child: Num(
                  '$due',
                  size: 13,
                  weight: FontWeight.w700,
                  color: due > 0 ? c.amber : c.muted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Circle(
                  label: overdue > 0
                      ? 'Reminders, $overdue overdue'
                      : 'Reminders',
                  onTap: () => context.push('/reminders'),
                  child: Icon(Ph.bell, size: 19, color: c.text),
                ),
                if (overdue > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: c.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            _Circle(
              label: 'Profile menu',
              color: c.primary,
              border: c.primary,
              onTap: () => showProfilePanel(context),
              child: Text(
                profile?.initials ?? '?',
                style: context.tt.labelLarge!.copyWith(
                  color: c.onPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.group,
    required this.fabOpen,
    required this.showFab,
    required this.onTab,
    required this.onSwitch,
    required this.onFab,
  });

  final AppTab current;
  final int group;
  final bool fabOpen;
  final bool showFab;
  final ValueChanged<AppTab> onTab;
  final VoidCallback onSwitch;
  final VoidCallback onFab;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final dur = context.reduceMotion ? Duration.zero : Gt.med;
    final shadow = c.isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

    return Row(
      children: [
        // Group switch: inverted circle; icon turns 180° per toggle.
        AnimatedOpacity(
          duration: Gt.fast,
          opacity: fabOpen ? 0 : 1,
          child: IgnorePointer(
            ignoring: fabOpen,
            child: Semantics(
              button: true,
              label: group == 0 ? 'Show analysis tabs' : 'Show tracking tabs',
              child: Material(
                color: c.inverse,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSwitch,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: AnimatedRotation(
                      turns: group * 0.5,
                      duration: dur,
                      curve: Gt.curve,
                      child: Icon(
                        PhBold.arrowsLeftRight,
                        size: 20,
                        color: c.onInverse,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AnimatedOpacity(
            duration: Gt.fast,
            opacity: fabOpen ? 0 : 1,
            child: IgnorePointer(
              ignoring: fabOpen,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: StadiumBorder(side: BorderSide(color: c.hairline)),
                  shadows: shadow,
                ),
                child: Row(
                  children: [
                    _NavButton(
                      tab: AppTab.home,
                      active: current == AppTab.home,
                      onTap: onTab,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: c.hairline,
                    ),
                    for (final t in AppTab.ofGroup(group))
                      _NavButton(
                        key: ValueKey(t),
                        tab: t,
                        active: current == t,
                        onTap: onTab,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: dur,
          curve: Gt.curve,
          child: showFab || fabOpen
              ? Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Semantics(
                    button: true,
                    label: fabOpen ? 'Close menu' : _fabLabel(current),
                    child: Material(
                      color: fabOpen ? c.red : c.primary,
                      shape: const CircleBorder(),
                      elevation: 0,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onFab,
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: AnimatedRotation(
                            turns: fabOpen ? 0.125 : 0,
                            duration: dur,
                            curve: Gt.curve,
                            child: Icon(
                              PhBold.plus,
                              color: c.onPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(height: 56),
        ),
      ],
    );
  }

  static String _fabLabel(AppTab t) => switch (t) {
    AppTab.home => 'Add',
    AppTab.subjects => 'Add subject',
    AppTab.scores => 'Add score',
    AppTab.planner => 'Add upcoming assessment',
    AppTab.history => 'Add term',
    _ => 'Add',
  };
}

/// Pill slot: 44px circle; the active slot fills and expands to icon + label.
class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.tab,
    required this.active,
    required this.onTap,
  });
  final AppTab tab;
  final bool active;
  final ValueChanged<AppTab> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final dur = context.reduceMotion ? Duration.zero : Gt.med;
    final child = Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => onTap(tab),
        child: AnimatedContainer(
          duration: dur,
          curve: Gt.curve,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: active ? 12 : 0),
          decoration: ShapeDecoration(
            color: active ? c.primary : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? tab.activeIcon : tab.icon,
                size: 21,
                color: active ? c.onPrimary : c.muted,
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: dur,
                  curve: Gt.curve,
                  child: active
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            style: context.tt.labelMedium!.copyWith(
                              color: c.onPrimary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return active ? child : Expanded(child: child);
  }
}

class _FabMenu extends StatelessWidget {
  const _FabMenu({
    required this.onScore,
    required this.onUpcoming,
    required this.onSubject,
    required this.onTerm,
  });
  final VoidCallback onScore;
  final VoidCallback onUpcoming;
  final VoidCallback onSubject;
  final VoidCallback onTerm;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, VoidCallback onTap, int i) {
      final c = context.gt;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(
          milliseconds: context.reduceMotion ? 0 : 140 + i * 40,
        ),
        curve: Gt.curve,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: c.surface,
            shape: StadiumBorder(side: BorderSide(color: c.hairline)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: context.tt.labelLarge),
                    const SizedBox(width: 12),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.raised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: c.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        item(Ph.calendarPlus, 'Term', onTerm, 3),
        item(Ph.books, 'Subject', onSubject, 2),
        item(Ph.calendarDots, 'Upcoming assessment', onUpcoming, 1),
        item(Ph.notePencil, 'Score', onScore, 0),
      ],
    );
  }
}
