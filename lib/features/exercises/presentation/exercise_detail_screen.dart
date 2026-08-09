import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/workout/application/active_workout_controller.dart';

/// Detail view for a single [Exercise], passed via go_router `extra`.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (exercise.gifUrl.isNotEmpty) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 20),
              color: Colors.white, // Match white background of raw GIF assets
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
              ),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: exercise.gifUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 40, color: theme.colorScheme.error),
                        const SizedBox(height: 8),
                        Text(
                          'Preview unavailable',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Text(exercise.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.fitness_center, size: 18),
                label: Text(exercise.muscleGroup),
              ),
              Chip(
                avatar: const Icon(Icons.handyman_outlined, size: 18),
                label: Text(exercise.equipment),
              ),
              Chip(
                avatar: const Icon(Icons.signal_cellular_alt, size: 18),
                label: Text(exercise.difficulty),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Instructions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(exercise.instructions, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 32),
          if (activeWorkout != null)
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(activeWorkoutProvider.notifier)
                    .addExercise(exercise);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to workout')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add to current workout'),
            ),
        ],
      ),
    );
  }
}
