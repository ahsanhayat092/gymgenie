import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/services/notification_service.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/profile/domain/user_profile.dart';
import 'package:gymgenie/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _initials(UserProfile profile) {
    final name = profile.displayName.trim();
    if (name.isEmpty) {
      final email = profile.email.trim();
      return email.isEmpty ? '?' : email.substring(0, 1).toUpperCase();
    }
    final parts = name.split(RegExp(r'\s+'));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.substring(0, 1).toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
      // The router redirect handles navigation after sign-out.
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(ref.read(authRepositoryProvider).describeAuthError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load your profile.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return ErrorView(
              message: 'No profile found for this account.',
              onRetry: () => ref.invalidate(userProfileProvider),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _initials(profile),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  profile.displayName.isEmpty
                      ? 'GymGenie user'
                      : profile.displayName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  profile.email,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Weekly goal: ${profile.weeklyWorkoutGoal} workouts',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/edit'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Goals'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/goals'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Workout History'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/history'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'WORKOUT SETTINGS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.timer_outlined),
                        title: Text(l.restTimerTitle),
                        subtitle: Text(l.restTimerDesc),
                        value: profile.restTimerEnabled,
                        onChanged: (val) {
                          ref.read(profileRepositoryProvider).saveProfile(
                            profile.copyWith(restTimerEnabled: val),
                          );
                        },
                      ),
                      if (profile.restTimerEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.snooze_outlined),
                          title: Text(l.restTimerDuration),
                          trailing: DropdownButton<int>(
                            value: profile.restTimerDuration,
                            underline: const SizedBox(),
                            dropdownColor: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(value: 30, child: Text('30 sec')),
                              DropdownMenuItem(value: 45, child: Text('45 sec')),
                              DropdownMenuItem(value: 60, child: Text('1 min')),
                              DropdownMenuItem(value: 90, child: Text('1:30 min')),
                              DropdownMenuItem(value: 120, child: Text('2 min')),
                              DropdownMenuItem(value: 180, child: Text('3 min')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(profileRepositoryProvider).saveProfile(
                                  profile.copyWith(restTimerDuration: val),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_outlined),
                        title: const Text('Workout Reminders'),
                        subtitle: const Text('Get a daily reminder to stay on track'),
                        value: profile.workoutReminderEnabled,
                        onChanged: (val) async {
                          final updated = profile.copyWith(workoutReminderEnabled: val);
                          await ref.read(profileRepositoryProvider).saveProfile(updated);
                          
                          if (val) {
                            await ref.read(notificationServiceProvider).scheduleWorkoutReminder(
                              hour: profile.workoutReminderHour,
                              minute: profile.workoutReminderMinute,
                            );
                          } else {
                            await ref.read(notificationServiceProvider).cancelWorkoutReminder();
                          }
                        },
                      ),
                      if (profile.workoutReminderEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.access_time_outlined),
                          title: const Text('Reminder Time'),
                          trailing: Text(
                            '${profile.workoutReminderHour.toString().padLeft(2, '0')}:${profile.workoutReminderMinute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: profile.workoutReminderHour,
                                minute: profile.workoutReminderMinute,
                              ),
                            );
                            if (picked != null) {
                              final updated = profile.copyWith(
                                workoutReminderHour: picked.hour,
                                workoutReminderMinute: picked.minute,
                              );
                              await ref.read(profileRepositoryProvider).saveProfile(updated);
                              await ref.read(notificationServiceProvider).scheduleWorkoutReminder(
                                hour: picked.hour,
                                minute: picked.minute,
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context, ref),
                icon: const Icon(Icons.logout),
                label: Text(l.logoutButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
