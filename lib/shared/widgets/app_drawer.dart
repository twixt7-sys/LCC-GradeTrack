import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import 'app_tabs.dart';
import 'primitives.dart';

/// Left drawer (theria Sidebar): brand, theme, term switcher, links.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    final mode = ref.watch(themeModeProvider);
    final current = gb?.currentTerm;

    void close() => Navigator.of(context).pop();
    void push(String path) {
      close();
      context.push(path);
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/brand/lcc_logo_512.png',
                  width: 52,
                  height: 52,
                  cacheWidth: 200,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LCC GradeTrack',
                        style: context.tt.titleMedium!.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Legacy College of Compostela',
                        style: context.tt.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CapsuleSelector<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.dark, ThemeMode.light],
              selected: mode,
              labelOf: (m) => switch (m) {
                ThemeMode.system => 'System',
                ThemeMode.dark => 'Dark',
                ThemeMode.light => 'Light',
              },
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
            ),
            SectionLabel(
              'Term',
              trailing: 'Manage',
              onTrailing: () {
                close();
                context.go(AppTab.history.path);
              },
            ),
            if (gb == null || gb.terms.isEmpty)
              Text('No terms yet.', style: context.tt.bodySmall)
            else
              GtCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, t) in gb.terms.reversed.indexed) ...[
                      if (i > 0) const Divider(),
                      _TermRow(
                        label: t.kind.label,
                        sub: t.ayLong,
                        gwa: gb.termGwa(t.id!).gwa,
                        selected: t.id == current?.id,
                        onTap: () async {
                          await ref
                              .read(gradebookProvider.notifier)
                              .mutate((r) => r.setCurrentTerm(t.id!));
                          if (context.mounted) close();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            const SectionLabel('App'),
            _Link(
              icon: PhosphorIconsRegular.ruler,
              label: 'Grade scale',
              onTap: () => push('/settings/scale'),
            ),
            _Link(
              icon: PhosphorIconsRegular.gearSix,
              label: 'Settings',
              onTap: () => push('/settings'),
            ),
            _Link(
              icon: PhosphorIconsRegular.database,
              label: 'Backup & export',
              onTap: () => push('/settings/data'),
            ),
            _Link(
              icon: PhosphorIconsRegular.info,
              label: 'About',
              onTap: () => push('/about'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.deviceMobile,
                  size: 14,
                  color: c.faint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your data stays on this phone.',
                    style: context.tt.bodySmall!.copyWith(color: c.faint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.label,
    required this.sub,
    required this.gwa,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String sub;
  final double? gwa;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? PhosphorIconsFill.radioButton
                  : PhosphorIconsRegular.circle,
              size: 18,
              color: selected ? c.primaryText : c.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.tt.titleSmall),
                  Text(sub, style: context.tt.bodySmall),
                ],
              ),
            ),
            Num(
              fmtGrade(gwa),
              size: 13,
              weight: FontWeight.w700,
              color: gwa == null ? c.faint : c.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Gt.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.muted),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: context.tt.titleSmall)),
            Icon(PhosphorIconsRegular.caretRight, size: 14, color: c.faint),
          ],
        ),
      ),
    );
  }
}

/// Dropdown from the avatar (theria ProfileMenuPanel).
Future<void> showProfilePanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: context.reduceMotion ? Duration.zero : Gt.fast,
    pageBuilder: (ctx, _, _) => const _ProfilePanel(),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -0.03),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    ),
  );
}

class _ProfilePanel extends ConsumerWidget {
  const _ProfilePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    final p = gb?.profile;
    void go(String path) {
      Navigator.of(context).pop();
      context.push(path);
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 12, 0),
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Gt.radius + 4),
              side: BorderSide(color: c.hairline),
            ),
            child: SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: c.primary,
                          child: Text(
                            p?.initials ?? '?',
                            style: context.tt.titleSmall!.copyWith(
                              color: c.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p?.name ?? 'Student',
                                style: context.tt.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                [
                                  if (p?.program.isNotEmpty ?? false)
                                    '${p!.program} ${p.yearLevel}',
                                  if (p?.studentNo.isNotEmpty ?? false)
                                    p!.studentNo,
                                ].join(' · '),
                                style: context.tt.bodySmall,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Mini(
                          label: 'Cum. GWA',
                          value: fmtGrade(gb?.cumulativeGwa.gwa),
                        ),
                        const SizedBox(width: 8),
                        _Mini(
                          label: 'Units earned',
                          value: fmtNum(gb?.unitsEarned ?? 0),
                        ),
                        const SizedBox(width: 8),
                        _Mini(
                          label: 'Terms',
                          value: '${gb?.terms.length ?? 0}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PanelRow(
                      icon: PhosphorIconsRegular.userCircle,
                      label: 'Profile',
                      onTap: () => go('/profile'),
                    ),
                    _PanelRow(
                      icon: PhosphorIconsRegular.gearSix,
                      label: 'Settings',
                      onTap: () => go('/settings'),
                    ),
                    if (p?.hasPin ?? false)
                      _PanelRow(
                        icon: PhosphorIconsRegular.lockSimple,
                        label: 'Lock now',
                        onTap: () {
                          Navigator.of(context).pop();
                          ref.read(lockProvider.notifier).lock();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(Gt.radiusSm),
        ),
        child: Column(
          children: [
            Num(value, size: 16, weight: FontWeight.w700),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.tt.bodySmall!.copyWith(fontSize: 10.5),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Gt.radiusSm),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.gt.muted),
          const SizedBox(width: 12),
          Text(label, style: context.tt.titleSmall),
        ],
      ),
    ),
  );
}
