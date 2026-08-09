import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _updateGoal(BuildContext context, WidgetRef ref, int goal) async {
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateGoals(weeklyWorkoutGoal: goal);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your goal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
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
          final goal = profile.weeklyWorkoutGoal.clamp(1, 14).toInt();
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Weekly workout goal',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how many workouts you want to complete each week. '
                  'Your dashboard tracks your weekly progress against this '
                  'goal and shows your streak of consecutive weeks on target.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: goal > 1
                              ? () => _updateGoal(context, ref, goal - 1)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          children: [
                            Text(
                              '$goal',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              goal == 1 ? 'workout / week' : 'workouts / week',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        IconButton.filledTonal(
                          onPressed: goal < 14
                              ? () => _updateGoal(context, ref, goal + 1)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
