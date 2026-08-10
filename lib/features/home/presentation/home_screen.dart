import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
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
    if (weights.length < 2) return '--';
    final latest = weights.last;
    final first = weights.first;
    final diff = latest.weightKg - first.weightKg;
    final sign = diff >= 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)}';
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

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${userProfile?.displayName ?? 'Athlete'}',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(now),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: _WeeklySummaryDashboard(
                          strengthMins: totalStrengthMins,
                          cardioMins: totalCardioMins,
                          calories: totalCalories,
                          weightChange: _weightChangeText(weightsList),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: _WeeklyStatusCard(
                          done: thisWeek.length,
                          goal: weeklyGoal,
                          streakDays: streak,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick actions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      ref
                                          .read(activeWorkoutProvider.notifier)
                                          .startEmpty('Quick Workout');
                                      context.push('/workout/active');
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Start Workout'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton.tonal(
                                    onPressed: () => context.go('/plans'),
                                    child: const Text('Plans'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'Recent activity',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (recent.isEmpty)
                      const SliverToBoxAdapter(
                        child: _EmptyRecentActivity(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        sliver: SliverList.separated(
                          itemCount: recent.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = recent[index];
                            return _ActivityCard(
                              log: log,
                              index: index,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
              loading: () => const _HomeSkeleton(),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(bodyWeightsProvider),
              ),
            ),
            loading: () => const _HomeSkeleton(),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(workoutLogsProvider),
            ),
          ),
          loading: () => const _HomeSkeleton(),
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard.large(
                icon: Icons.fitness_center_rounded,
                label: 'Strength',
                value: _formatHoursMins(strengthMins),
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard.large(
                icon: Icons.directions_run_rounded,
                label: 'Cardio',
                value: _formatHoursMins(cardioMins),
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard.small(
                icon: Icons.local_fire_department_rounded,
                label: 'Burned',
                value: '${calories.round()}',
                unit: 'kcal',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard.small(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                value: weightChange,
                unit: 'kg',
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard.large({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  })  : unit = null,
        _size = _StatSize.large;

  const _StatCard.small({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.unit,
  }) : _size = _StatSize.small;

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final _StatSize _size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLarge = _size == _StatSize.large;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: isLarge ? 5 : 4,
              color: color,
            ),
            Padding(
              padding: EdgeInsets.all(isLarge ? 16 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: isLarge ? 22 : 18),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: isLarge
                              ? theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                )
                              : theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          unit!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
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

enum _StatSize { large, small }

class _WeeklyStatusCard extends StatelessWidget {
  const _WeeklyStatusCard({
    required this.done,
    required this.goal,
    required this.streakDays,
  });

  final int done;
  final int goal;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (done / goal).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$done',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '/ $goal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly goal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$done of $goal workouts completed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 18,
                        color: streakDays > 0
                            ? Colors.orange
                            : theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        streakDays == 0
                            ? 'Start a streak today'
                            : '$streakDays day${streakDays == 1 ? '' : 's'} in a row',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.log, required this.index});

  final WorkoutLog log;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/history'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.planName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDate(log.date)} • ${log.completedSets} sets',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatVolume(log.totalVolume),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecentActivity extends StatelessWidget {
  const _EmptyRecentActivity();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No workouts yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Start your first workout to see it here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 200,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _SkeletonBox(height: 140, radius: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SkeletonBox(height: 140, radius: 20),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _SkeletonBox(height: 100, radius: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SkeletonBox(height: 100, radius: 20),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: _SkeletonBox(height: 96, radius: 20),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
