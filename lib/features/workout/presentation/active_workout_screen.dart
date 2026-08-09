import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/exercises/data/exercise_repository.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/workout/application/active_workout_controller.dart';
import 'package:gymgenie/features/workout/application/rest_timer_controller.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _ticker;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Rebuild every 30s so the elapsed-time label stays fresh.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    final state = ref.read(activeWorkoutProvider);
    if (state == null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text(
            'Your active workout is not saved yet. Discard it and leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep training'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _finishWorkout() async {
    final notesController = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish workout'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'How did it go?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(notesController.text.trim()),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    notesController.dispose();
    if (notes == null || !mounted) return;

    setState(() => _finishing = true);
    try {
      final savedLog =
          await ref.read(activeWorkoutProvider.notifier).finish(notes: notes);
      if (!mounted) return;
      context.pushReplacement('/workout/summary', extra: savedLog);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _discardWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('This session will be lost and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).discard();
    context.pop();
  }

  void _showExercisePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ExercisePickerSheet(
          onSelected: (Exercise exercise) {
            ref.read(activeWorkoutProvider.notifier).addExercise(exercise);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(activeWorkoutProvider);
    final theme = Theme.of(context);
    final restTimer = ref.watch(restTimerProvider);

    return PopScope(
      canPop: workout == null,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && context.mounted) {
          ref.read(activeWorkoutProvider.notifier).discard();
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(workout?.planName ?? 'Workout'),
          actions: [
            if (workout != null)
              TextButton(
                onPressed: _discardWorkout,
                child: const Text('Discard'),
              ),
          ],
        ),
        body: workout == null
            ? EmptyView(
                icon: Icons.fitness_center,
                title: 'No active workout',
                subtitle: 'Start a workout from a plan or the home screen.',
                action: FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              )
            : Stack(
                children: [
                  _buildWorkoutBody(context, workout, theme, restTimer.isActive),
                  if (restTimer.isActive)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _RestTimerOverlay(state: restTimer),
                    ),
                ],
              ),
        bottomNavigationBar: workout == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _finishing ? null : _finishWorkout,
                    icon: _finishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Finish Workout'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWorkoutBody(
      BuildContext context, ActiveWorkoutState workout, ThemeData theme, bool restActive) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, restActive ? 140 : 24),
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '${workout.elapsedMinutes} min elapsed',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < workout.exercises.length; i++)
          _ExerciseCard(
            index: i,
            exercise: workout.exercises[i],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showExercisePicker,
          icon: const Icon(Icons.add),
          label: const Text('Add Exercise'),
        ),
      ],
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.index, required this.exercise});

  final int index;
  final ExerciseLog exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.removeExercise(index),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _HeaderCell('SET', flex: 1),
                _HeaderCell('REPS', flex: 2),
                _HeaderCell('KG', flex: 2),
                _HeaderCell('DONE', flex: 1),
                const SizedBox(width: 40),
              ],
            ),
            for (var s = 0; s < exercise.sets.length; s++)
              _SetRow(
                exerciseIndex: index,
                setIndex: s,
                set: exercise.sets[s],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => notifier.addSet(index),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _SetRow extends ConsumerWidget {
  const _SetRow({
    required this.exerciseIndex,
    required this.setIndex,
    required this.set,
  });

  final int exerciseIndex;
  final int setIndex;
  final SetLog set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final done = set.completed;

    return Opacity(
      opacity: done ? 0.65 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: done
              ? theme.colorScheme.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${set.setNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: done ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextFormField(
                  key: ValueKey('reps-$exerciseIndex-$setIndex-${set.reps}'),
                  initialValue: set.reps == 0 ? '' : '${set.reps}',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '0',
                  ),
                  onChanged: (value) {
                    final reps = int.tryParse(value.trim());
                    if (reps != null) {
                      notifier.updateSet(exerciseIndex, setIndex, reps: reps);
                    }
                  },
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextFormField(
                  key: ValueKey('weight-$exerciseIndex-$setIndex'),
                  initialValue: set.weight == 0 ? '' : '${set.weight}',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '0.0',
                  ),
                  onChanged: (value) {
                    final weight = double.tryParse(value.trim());
                    if (weight != null) {
                      notifier.updateSet(exerciseIndex, setIndex,
                          weight: weight);
                    }
                  },
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: IconButton(
                  tooltip: done ? 'Mark as not done' : 'Mark as done',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    color: done ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () {
                    final nextState = !done;
                    notifier.updateSet(exerciseIndex, setIndex, completed: nextState);
                    if (nextState) {
                      final profile = ref.read(userProfileProvider).valueOrNull;
                      if (profile != null && profile.restTimerEnabled) {
                        ref.read(restTimerProvider.notifier).start(profile.restTimerDuration);
                      }
                    }
                  },
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: IconButton(
                tooltip: 'Remove set',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    notifier.removeSet(exerciseIndex, setIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet({required this.onSelected});

  final ValueChanged<Exercise> onSelected;

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search exercises',
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: library.when(
                data: (exercises) {
                  final filtered = _query.isEmpty
                      ? exercises
                      : exercises
                          .where(
                              (e) => e.name.toLowerCase().contains(_query))
                          .toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No exercises found'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final exercise = filtered[i];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(
                            '${exercise.muscleGroup} • ${exercise.equipment}'),
                        onTap: () => widget.onSelected(exercise),
                      );
                    },
                  );
                },
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(message: error.toString()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RestTimerOverlay extends ConsumerWidget {
  const _RestTimerOverlay({required this.state});

  final RestTimerState state;

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = state.totalSeconds > 0
        ? state.remainingSeconds / state.totalSeconds
        : 0.0;

    return Card(
      elevation: 6,
      shadowColor: Colors.black45,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.snooze,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rest Period',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(state.remainingSeconds),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    ref.read(restTimerProvider.notifier).addTime(30);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+30s'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(restTimerProvider.notifier).skip();
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Skip'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
