import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/core/router/app_router.dart';
import 'package:gymgenie/core/theme/app_theme.dart';
import 'package:gymgenie/core/services/notification_service.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/l10n/app_localizations.dart';

class GymGenieApp extends ConsumerStatefulWidget {
  const GymGenieApp({super.key});

  @override
  ConsumerState<GymGenieApp> createState() => _GymGenieAppState();
}

class _GymGenieAppState extends ConsumerState<GymGenieApp>
    with WidgetsBindingObserver {
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
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Retry any offline logs when the app comes back to the foreground.
      ref.read(logRepositoryProvider).syncPendingLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep daily workout notifications synced with profile settings
    ref.listen<AsyncValue<dynamic>>(userProfileProvider, (previous, next) {
      final profile = next.valueOrNull;
      if (profile != null) {
        if (profile.workoutReminderEnabled) {
          ref.read(notificationServiceProvider).scheduleWorkoutReminder(
            hour: profile.workoutReminderHour,
            minute: profile.workoutReminderMinute,
          );
        } else {
          ref.read(notificationServiceProvider).cancelWorkoutReminder();
        }
      }
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GymGenie',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
