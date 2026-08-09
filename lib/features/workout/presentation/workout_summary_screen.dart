import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(Icons.emoji_events,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Workout complete!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              log.planName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                _StatCard(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: '${log.durationMinutes} min',
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Sets',
                  value: '${log.completedSets}',
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.fitness_center,
                  label: 'Volume',
                  value: formatVolume(log.totalVolume),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Exercises', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final exercise in log.exercises)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(exercise.exerciseName),
                  subtitle: Text(
                    '${exercise.sets.where((s) => s.completed).length} of '
                    '${exercise.sets.length} sets completed',
                  ),
                  trailing: Text(formatVolume(exercise.volume)),
                ),
              ),
            if (log.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Notes', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(log.notes, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
