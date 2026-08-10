import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  _CelebrationIcon(),
                  const SizedBox(height: 24),
                  Text(
                    'Workout complete!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    log.planName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '${log.durationMinutes}',
                        unit: 'min',
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.check_circle_outline,
                        label: 'Sets',
                        value: '${log.completedSets}',
                        unit: '',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.fitness_center,
                        label: 'Volume',
                        value: log.totalVolume.toStringAsFixed(0),
                        unit: 'kg',
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.local_fire_department,
                        label: 'Calories',
                        value: '${log.totalCalories}',
                        unit: 'kcal',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Exercises',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final exercise in log.exercises)
                    _ExerciseSummaryTile(exercise: exercise),
                  if (log.notes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Notes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Text(
                        log.notes,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go('/home');
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationIcon extends StatefulWidget {
  @override
  State<_CelebrationIcon> createState() => _CelebrationIconState();
}

class _CelebrationIconState extends State<_CelebrationIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _scale,
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.25),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.emoji_events,
            size: 56,
            color: theme.colorScheme.primary,
          ),
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
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(height: 10),
            _AnimatedFigure(value: value),
            if (unit.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                unit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedFigure extends StatefulWidget {
  const _AnimatedFigure({required this.value});

  final String value;

  @override
  State<_AnimatedFigure> createState() => _AnimatedFigureState();
}

class _AnimatedFigureState extends State<_AnimatedFigure>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        widget.value,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExerciseSummaryTile extends StatelessWidget {
  const _ExerciseSummaryTile({required this.exercise});

  final ExerciseLog exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = exercise.sets.where((s) => s.completed).length;
    final total = exercise.sets.length;
    final allDone = completed == total && total > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allDone
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: allDone
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone ? Icons.check : Icons.fitness_center,
              size: 18,
              color: allDone ? Colors.black : theme.colorScheme.primary,
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
                  '$completed of $total sets completed'
                  '${exercise.exerciseCalories > 0 ? ' • ${exercise.exerciseCalories.round()} kcal' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatVolume(exercise.volume),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
