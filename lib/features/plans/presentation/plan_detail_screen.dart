import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/workout/application/active_workout_controller.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

/// Loads a single plan by id.
final planDetailProvider =
    FutureProvider.family<WorkoutPlan?, String>((ref, planId) {
  return ref.watch(planRepositoryProvider).getPlan(planId);
});

/// Shows a plan's exercises and offers Start / Edit / Delete actions.
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

  Future<void> _sharePlan(BuildContext context, WidgetRef ref, WorkoutPlan plan) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating share link...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final code = await ref.read(planRepositoryProvider).sharePlan(plan);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog

      final shareUrl = 'https://gymgenie.app/share?code=$code';

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: const Text('Share Workout Plan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Let other GymGenie users scan this QR code or use the share code below to import your plan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: QrImageView(
                      data: shareUrl,
                      version: QrVersions.auto,
                      size: 180,
                      gapless: false,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Share Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(
                    code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied link to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Share Link'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share plan: $e')),
      );
    }
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
              onPressed: () => _sharePlan(context, ref, planAsync.valueOrNull!),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/plans/$planId/edit'),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  _confirmAndDelete(context, ref, planAsync.valueOrNull!),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(plan.name, style: theme.textTheme.headlineSmall),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Exercises', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < exercises.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(exercises[i].exerciseName),
                    subtitle: Text(_exerciseSummary(exercises[i])),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
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
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Workout'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/plans/${plan.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmAndDelete(context, ref, plan),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }
}
