import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/exercises/data/exercise_repository.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/plans/presentation/share_plan_dialog.dart';
import 'package:gymgenie/features/workout/application/active_workout_controller.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

final planDetailProvider =
    FutureProvider.family<WorkoutPlan?, String>((ref, planId) {
  return ref.watch(planRepositoryProvider).getPlan(planId);
});

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  String _formatWeight(double weight) =>
      weight == weight.roundToDouble() ? '${weight.toInt()}' : '$weight';

  String _exerciseSummary(PlannedExercise exercise) {
    final base = '${exercise.targetSets} × ${exercise.targetReps}';
    if (exercise.targetWeight <= 0) return base;
    return '$base @ ${_formatWeight(exercise.targetWeight)} kg';
  }

  Future<void> _confirmAndDelete(
      BuildContext context, WidgetRef ref, WorkoutPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text('This will permanently delete "${plan.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(planRepositoryProvider).deletePlan(plan.id);
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _startWorkout(BuildContext context, WidgetRef ref, WorkoutPlan plan) {
    HapticFeedback.lightImpact();
    final logs = ref.read(workoutLogsProvider).valueOrNull ?? [];
    WorkoutLog? lastLog;
    for (final log in logs) {
      if (log.planId == plan.id) {
        lastLog = log;
        break;
      }
    }
    ref
        .read(activeWorkoutProvider.notifier)
        .startFromPlan(plan, lastLog: lastLog);
    context.push('/workout/active');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planDetailProvider(planId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          if (planAsync.valueOrNull != null) ...[
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => showSharePlanDialog(
                context,
                ref,
                planAsync.valueOrNull!,
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/plans/$planId/edit'),
            ),
          ],
        ],
      ),
      body: planAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Failed to load plan',
          onRetry: () => ref.invalidate(planDetailProvider(planId)),
        ),
        data: (plan) {
          if (plan == null) {
            return ErrorView(
              message: 'Plan not found',
              onRetry: () => ref.invalidate(planDetailProvider(planId)),
            );
          }
          final exercises = [...plan.exercises]
            ..sort((a, b) => a.order.compareTo(b.order));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (plan.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          plan.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${exercises.length} exercises',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    return _ExerciseTile(
                      index: i,
                      exercise: exercises[i],
                      summary: _exerciseSummary(exercises[i]),
                      onTap: () async {
                        final exercise = await ref.read(
                          exerciseByIdProvider(exercises[i].exerciseId).future,
                        );
                        if (!context.mounted) return;
                        if (exercise == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Exercise details not available.'),
                            ),
                          );
                          return;
                        }
                        context.push('/exercises/detail', extra: exercise);
                      },
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      bottomNavigationBar: planAsync.valueOrNull == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: () =>
                            _startWorkout(context, ref, planAsync.valueOrNull!),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Workout'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => showSharePlanDialog(
                          context,
                          ref,
                          planAsync.valueOrNull!,
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.index,
    required this.exercise,
    required this.summary,
    required this.onTap,
  });

  final int index;
  final PlannedExercise exercise;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
