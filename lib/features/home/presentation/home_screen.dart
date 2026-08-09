import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/workout/application/active_workout_controller.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Logs whose date falls inside the current Monday–Sunday week.
  static List<WorkoutLog> _logsThisWeek(List<WorkoutLog> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return logs.where((log) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      return !day.isBefore(weekStart) && day.isBefore(weekEnd);
    }).toList();
  }

  /// Consecutive days with at least one log, ending today or yesterday.
  static int _dayStreak(List<WorkoutLog> logs) {
    final days = logs
        .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
        .toSet();
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime cursor;
    if (days.contains(today)) {
      cursor = today;
    } else if (days.contains(today.subtract(const Duration(days: 1)))) {
      cursor = today.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final logs = ref.watch(workoutLogsProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: profile.when(
          data: (userProfile) => logs.when(
            data: (logList) {
              final weeklyGoal =
                  (userProfile?.weeklyWorkoutGoal ?? 3).clamp(1, 14).toInt();
              final thisWeek = _logsThisWeek(logList);
              final streak = _dayStreak(logList);
              final recent = logList.take(5).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    'Hi, ${userProfile?.displayName ?? 'Athlete'}',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDate(now),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _WeeklyGoalCard(
                    done: thisWeek.length,
                    goal: weeklyGoal,
                  ),
                  const SizedBox(height: 12),
                  _StreakCard(streakDays: streak),
                  const SizedBox(height: 24),
                  Text('Quick actions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ref
                                .read(activeWorkoutProvider.notifier)
                                .startEmpty('Quick Workout');
                            context.push('/workout/active');
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Empty Workout'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => context.go('/plans'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.list_alt, size: 18),
                              SizedBox(width: 8),
                              Flexible(child: Text('Browse Plans')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Recent activity', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (recent.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No workouts yet — start your first one!',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final log in recent)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.fitness_center),
                          title: Text(log.planName),
                          subtitle: Text(
                            '${formatDate(log.date)} • '
                            '${log.completedSets} sets',
                          ),
                          trailing: Text(formatVolume(log.totalVolume)),
                          onTap: () => context.push('/history'),
                        ),
                      ),
                ],
              );
            },
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(workoutLogsProvider),
            ),
          ),
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(userProfileProvider),
          ),
        ),
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.done, required this.goal});

  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (done / goal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Weekly goal', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '$done of $goal workouts',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department,
                size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day streak', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    streakDays == 0
                        ? 'Work out today to start a streak'
                        : '$streakDays day${streakDays == 1 ? '' : 's'} in a row',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
