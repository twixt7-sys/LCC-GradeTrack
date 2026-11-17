import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/lock/lock_screen.dart';
import 'router.dart';

class GradeTrackApp extends ConsumerStatefulWidget {
  const GradeTrackApp({super.key});

  @override
  ConsumerState<GradeTrackApp> createState() => _GradeTrackAppState();
}

class _GradeTrackAppState extends ConsumerState<GradeTrackApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;
  bool _checkedInitialLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      final profile = ref.read(gradebookProvider).value?.profile;
      if (at == null || profile == null || !profile.hasPin) return;
      final away = DateTime.now().difference(at).inSeconds;
      if (away >= ref.read(prefsProvider).lockDelay) {
        ref.read(lockProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final locked = ref.watch(lockProvider);

    // Lock on cold start when a PIN exists.
    ref.listen(gradebookProvider, (prev, next) {
      if (_checkedInitialLock) return;
      final gb = next.value;
      if (gb == null) return;
      _checkedInitialLock = true;
      if (gb.profile?.hasPin ?? false) ref.read(lockProvider.notifier).lock();
    });

    return MaterialApp.router(
      title: 'LCC GradeTrack',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(GtColors.light),
      darkTheme: buildTheme(GtColors.dark),
      themeMode: mode,
      routerConfig: router,
      locale: const Locale('en', 'PH'),
      supportedLocales: const [Locale('en', 'PH'), Locale('en', 'US')],
      // Moves to material_ui with the rest of Material; see lib/ui.dart.
      // ignore: deprecated_member_use
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final c = context.gt;
        // Keep text readable at large font sizes without breaking dense layouts.
        final mq = MediaQuery.of(context);
        final scaler = mq.textScaler.clamp(maxScaleFactor: 1.3);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              (c.isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarContrastEnforced: false,
                  ),
          child: MediaQuery(
            data: mq.copyWith(textScaler: scaler),
            child: Stack(
              children: [
                child ?? const SizedBox(),
                if (locked) const Positioned.fill(child: LockScreen()),
              ],
            ),
          ),
        );
      },
    );
  }
}
