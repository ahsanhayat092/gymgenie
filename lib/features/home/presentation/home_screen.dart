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

  static String _weightChangeText(List<BodyWeightEntry> weights) {
    if (weights.length < 2) return '-- kg';
    final latest = weights.last;
    final first = weights.first;
    final diff = latest.weightKg - first.weightKg;
    final sign = diff >= 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final logs = ref.watch(workoutLogsProvider);
    final weights = ref.watch(bodyWeightsProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: profile.when(
          data: (userProfile) => logs.when(
            data: (logList) => weights.when(
              data: (weightsList) {
                final weeklyGoal =
                    (userProfile?.weeklyWorkoutGoal ?? 3).clamp(1, 14).toInt();
                final thisWeek = _logsThisWeek(logList);
                final streak = _dayStreak(logList);
                final recent = logList.take(5).toList();

                // Compute weekly stats
                double totalCardioMins = 0;
                double totalStrengthMins = 0;
                double totalCalories = 0;

                for (final log in thisWeek) {
                  double logCardioMins = 0;
                  double logCardioCalories = 0;

                  for (final ex in log.exercises) {
                    if (ex.exerciseName.toLowerCase().contains('cardio')) {
                      final mins = ex.durationMinutes ?? 0.0;
                      logCardioMins += mins;
                      logCardioCalories += ex.caloriesBurned ?? (mins * 8.0);
                    }
                  }

                  final logStrengthMins = log.durationMinutes.toDouble() - logCardioMins;
                  final logStrengthCalories = (logStrengthMins < 0 ? 0.0 : logStrengthMins) * 6.0;

                  totalCardioMins += logCardioMins;
                  totalStrengthMins += logStrengthMins < 0 ? 0.0 : logStrengthMins;
                  totalCalories += logStrengthCalories + logCardioCalories;
                }

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
                    Text('This week', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _WeeklySummaryDashboard(
                      strengthMins: totalStrengthMins,
                      cardioMins: totalCardioMins,
                      calories: totalCalories,
                      weightChange: _weightChangeText(weightsList),
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
                onRetry: () => ref.invalidate(bodyWeightsProvider),
              ),
            ),
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

class _WeeklySummaryDashboard extends StatelessWidget {
  const _WeeklySummaryDashboard({
    required this.strengthMins,
    required this.cardioMins,
    required this.calories,
    required this.weightChange,
  });

  final double strengthMins;
  final double cardioMins;
  final double calories;
  final String weightChange;

  String _formatHoursMins(double totalMins) {
    final hrs = totalMins ~/ 60;
    final mins = (totalMins % 60).round();
    if (hrs == 0) return '${mins}m';
    return '${hrs}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        _StatCard(
          icon: Icons.fitness_center,
          label: 'Strength',
          value: _formatHoursMins(strengthMins),
          color: theme.colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.directions_run,
          label: 'Cardio',
          value: _formatHoursMins(cardioMins),
          color: theme.colorScheme.tertiary,
        ),
        _StatCard(
          icon: Icons.local_fire_department,
          label: 'Est. Activity',
          value: '${calories.round()} kcal',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.scale,
          label: 'Weight Progress',
          value: weightChange,
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
      margin: EdgeInsets.zero,
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
      margin: EdgeInsets.zero,
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
