import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/social/data/social_repository.dart';

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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
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
          'Your active workout is not saved yet. Discard it and leave?',
        ),
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
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _FinishWorkoutSheet(),
    );

    if (result == null || !mounted) return;

    setState(() => _finishing = true);
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      final userWeightKg = profile != null && profile.weightKg > 0
          ? profile.weightKg
          : 70.0;

      final activeWorkout = ref.read(activeWorkoutProvider);
      final updateOriginal = result['updateOriginalPlan'] as bool? ?? false;

      if (updateOriginal && activeWorkout != null && activeWorkout.planId.isNotEmpty) {
        try {
          final planRepo = ref.read(planRepositoryProvider);
          final originalPlan = await planRepo.getPlan(activeWorkout.planId);
          if (originalPlan != null) {
            final List<PlannedExercise> updatedPlannedExercises = [];
            for (var i = 0; i < activeWorkout.exercises.length; i++) {
              final exLog = activeWorkout.exercises[i];
              final isCardio = exLog.sets.isEmpty;

              PlannedExercise? originalMatch;
              for (final pe in originalPlan.exercises) {
                if (pe.exerciseId == exLog.exerciseId) {
                  originalMatch = pe;
                  break;
                }
              }

              if (originalMatch != null) {
                updatedPlannedExercises.add(originalMatch.copyWith(order: i));
              } else {
                updatedPlannedExercises.add(PlannedExercise(
                  exerciseId: exLog.exerciseId,
                  exerciseName: exLog.exerciseName,
                  targetSets: isCardio ? 1 : (exLog.sets.isNotEmpty ? exLog.sets.length : 3),
                  targetReps: isCardio ? 1 : (exLog.sets.isNotEmpty ? exLog.sets[0].reps : 10),
                  targetWeight: isCardio ? 0.0 : (exLog.sets.isNotEmpty ? exLog.sets[0].weight : 0.0),
                  order: i,
                  isCardio: isCardio,
                  targetDurationMinutes: isCardio ? (exLog.durationMinutes?.round() ?? 20) : null,
                  targetResistanceLevel: isCardio ? (exLog.resistanceLevel ?? 5.0) : null,
                  cardioSegments: isCardio ? exLog.cardioSegments : null,
                ));
              }
            }

            await planRepo.updatePlan(originalPlan.copyWith(
              exercises: updatedPlannedExercises,
            ));
          }
        } catch (e) {
          debugPrint('Failed to update original plan template: $e');
        }
      }

      final savedLog = await ref.read(activeWorkoutProvider.notifier).finish(
            notes: result['notes'] as String,
            difficultyRating: result['difficulty'] as String,
            energyLevel: result['energy'] as int,
            painLevel: result['pain'] as String,
            userWeightKg: userWeightKg,
          );
      if (!mounted) return;

      try {
        await ref.read(socialRepositoryProvider).postToFeed(savedLog, profile);
      } catch (e) {
        debugPrint('Failed to post workout to social feed: $e');
      }

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
            HapticFeedback.lightImpact();
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
          title: const Text('Workout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            if (workout != null)
              TextButton(
                onPressed: _discardWorkout,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
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
                  _buildWorkoutBody(context, workout, restTimer.isActive),
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
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.scaffoldBackgroundColor.withValues(alpha: 0),
                        theme.scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                  child: FilledButton.icon(
                    onPressed: _finishing ? null : _finishWorkout,
                    style: FilledButton.styleFrom(
                      elevation: 8,
                      shadowColor:
                          theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    icon: _finishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Finish Workout'),
                  ),
                ),
              ),
      ),
    );
  }

  bool _isExerciseCompleted(ExerciseLog ex) {
    if (ex.sets.isEmpty) {
      return ex.isCardioCompleted;
    }
    return ex.sets.isNotEmpty && ex.sets.every((s) => s.completed);
  }

  Widget _buildWorkoutBody(
    BuildContext context,
    ActiveWorkoutState workout,
    bool restActive,
  ) {
    int activeIndex = 0;
    for (int i = 0; i < workout.exercises.length; i++) {
      if (!_isExerciseCompleted(workout.exercises[i])) {
        activeIndex = i;
        break;
      }
      if (i == workout.exercises.length - 1) {
        activeIndex = i;
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, restActive ? 160 : 24),
      children: [
        _WorkoutHeader(workout: workout),
        for (var i = 0; i <= activeIndex && i < workout.exercises.length; i++)
          _ExerciseCard(
            index: i,
            exercise: workout.exercises[i],
            isActive: i == activeIndex &&
                !_isExerciseCompleted(workout.exercises[i]),
            isCompleted: _isExerciseCompleted(workout.exercises[i]),
          ),
        const SizedBox(height: 8),
        _DashedActionButton(
          onPressed: _showExercisePicker,
          icon: Icons.add_rounded,
          label: 'Add Exercise',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _DashedActionButton extends StatelessWidget {
  const _DashedActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
        borderRadius: 16,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
  });

  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({required this.workout});

  final ActiveWorkoutState workout;

  String _formatElapsed() {
    final elapsed = DateTime.now().difference(workout.startedAt);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toStringAsFixed(0);
  }

  bool _isExerciseCompleted(ExerciseLog ex) {
    if (ex.sets.isEmpty) return ex.isCardioCompleted;
    return ex.sets.isNotEmpty && ex.sets.every((s) => s.completed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalExercises = workout.exercises.length;
    final doneExercises =
        workout.exercises.where(_isExerciseCompleted).length;
    final totalSets = workout.exercises
        .fold<int>(0, (sum, ex) => sum + ex.sets.length);
    final doneSets = workout.exercises.fold<int>(
        0, (sum, ex) => sum + ex.sets.where((s) => s.completed).length);
    final volume = workout.exercises.fold<double>(
      0,
      (sum, ex) =>
          sum +
          ex.sets
              .where((s) => s.completed)
              .fold<double>(0, (s, set) => s + set.weight * set.reps),
    );
    final progress = totalSets > 0
        ? doneSets / totalSets
        : (totalExercises > 0 ? doneExercises / totalExercises : 0.0);

    final planLabel =
        workout.planName.isEmpty ? 'Quick Workout' : workout.planName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.secondary
                                    .withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE SESSION',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatElapsed(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'ELAPSED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.fitness_center,
                label: '$doneExercises/$totalExercises exercises',
              ),
              _StatChip(
                icon: Icons.check_circle_outline,
                label: '$doneSets/$totalSets sets',
              ),
              _StatChip(
                icon: Icons.monitor_weight_outlined,
                label: '${_formatVolume(volume)} kg lifted',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerStatefulWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.isActive,
    required this.isCompleted,
  });

  final int index;
  final ExerciseLog exercise;
  final bool isActive;
  final bool isCompleted;

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.isCompleted;
  }

  void _showSubstitutionPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _SubstitutionSheet(
          exerciseLog: widget.exercise,
          onSelected: (Exercise newExercise) {
            HapticFeedback.lightImpact();
            ref
                .read(activeWorkoutProvider.notifier)
                .substituteExercise(widget.index, newExercise);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  void _viewExerciseDetail() async {
    final exercise = await ref.read(
      exerciseByIdProvider(widget.exercise.exerciseId).future,
    );
    if (!mounted) return;
    if (exercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise details not available.'),
        ),
      );
      return;
    }
    context.push('/exercises/detail', extra: exercise);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final isCardio = widget.exercise.sets.isEmpty;
    final completedSets =
        widget.exercise.sets.where((s) => s.completed).length;
    final totalSets = widget.exercise.sets.length;
    final setProgress = totalSets > 0 ? completedSets / totalSets : 0.0;

    final exerciseAsync = ref.watch(exerciseByIdProvider(widget.exercise.exerciseId));
    final gifUrl = exerciseAsync.valueOrNull?.gifUrl ?? '';

    final statusColor = widget.isCompleted
        ? theme.colorScheme.secondary
        : widget.isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: widget.isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : widget.isCompleted
                    ? theme.colorScheme.secondary.withValues(alpha: 0.25)
                    : theme.colorScheme.outline,
            width: widget.isActive ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.isCompleted
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isCompleted
                            ? Icons.check_circle
                            : (isCardio
                                ? Icons.directions_run
                                : Icons.fitness_center),
                        color: widget.isCompleted
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.exercise.exerciseName,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (widget.isActive && !widget.isCompleted) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'IN PROGRESS',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (!isCardio)
                            Row(
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: setProgress,
                                      minHeight: 4,
                                      backgroundColor: theme.colorScheme
                                          .surfaceContainerHighest,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        statusColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isCompleted
                                      ? 'Completed'
                                      : '$completedSets/$totalSets sets',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: widget.isCompleted
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: widget.isCompleted
                                        ? FontWeight.w700
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          if (isCardio)
                            Text(
                              widget.exercise.isCardioCompleted ? 'Completed' : 'Cardio in progress',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: widget.exercise.isCardioCompleted
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: widget.exercise.isCardioCompleted
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _PopupMenu(
                      onView: _viewExerciseDetail,
                      onSubstitute: _showSubstitutionPicker,
                      onRemove: () {
                        HapticFeedback.lightImpact();
                        notifier.removeExercise(widget.index);
                      },
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gifUrl.isNotEmpty) ...[
                      Container(
                        height: 180,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: gifUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    isCardio
                        ? _CardioMetrics(index: widget.index, exercise: widget.exercise)
                        : _StrengthSets(index: widget.index, exercise: widget.exercise),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _PopupMenu extends StatelessWidget {
  const _PopupMenu({
    required this.onView,
    required this.onSubstitute,
    required this.onRemove,
  });

  final VoidCallback onView;
  final VoidCallback onSubstitute;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          onTap: onView,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              const Text('View details'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'substitute',
          onTap: onSubstitute,
          child: Row(
            children: [
              Icon(Icons.swap_horiz, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              const Text('Substitute'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          onTap: onRemove,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Text(
                'Remove',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StrengthSets extends ConsumerWidget {
  const _StrengthSets({required this.index, required this.exercise});

  final int index;
  final ExerciseLog exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 0, 4),
          child: Row(
            children: [
              _HeaderCell('SET', flex: 1),
              _HeaderCell('REPS', flex: 2),
              _HeaderCell('KG', flex: 2),
              _HeaderCell('DONE', flex: 1),
              SizedBox(width: 44),
            ],
          ),
        ),
        for (var s = 0; s < exercise.sets.length; s++)
          _SetRow(
            exerciseIndex: index,
            setIndex: s,
            set: exercise.sets[s],
          ),
        const SizedBox(height: 10),
        _DashedActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            notifier.addSet(index);
          },
          icon: Icons.add_rounded,
          label: 'Add set',
        ),
      ],
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1.4,
              ),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: done
            ? Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.4),
              )
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '${set.setNumber}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: done
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _NumberField(
                key: ValueKey('reps-$exerciseIndex-$setIndex-${set.reps}'),
                value: set.reps,
                hint: '0',
                onChanged: (reps) {
                  final parsed = int.tryParse(reps ?? '');
                  if (parsed != null) {
                    notifier.updateSet(exerciseIndex, setIndex, reps: parsed);
                  }
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _NumberField(
                key: ValueKey('weight-$exerciseIndex-$setIndex'),
                value: set.weight == 0 ? null : set.weight.toString(),
                hint: '0.0',
                allowDecimal: true,
                onChanged: (value) {
                  final weight = double.tryParse(value ?? '');
                  if (weight != null) {
                    notifier.updateSet(exerciseIndex, setIndex, weight: weight);
                  }
                },
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final nextState = !done;
                  notifier.updateSet(
                    exerciseIndex,
                    setIndex,
                    completed: nextState,
                  );
                  if (nextState) {
                    final profile =
                        ref.read(userProfileProvider).valueOrNull;
                    if (profile != null && profile.restTimerEnabled) {
                      ref
                          .read(restTimerProvider.notifier)
                          .start(profile.restTimerDuration);
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.surfaceContainerHighest,
                    border: done
                        ? null
                        : Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 18,
                    color: done ? Colors.black : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              tooltip: 'Remove set',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => notifier.removeSet(exerciseIndex, setIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.allowDecimal = false,
  });

  final dynamic value;
  final String hint;
  final ValueChanged<String?> onChanged;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = value is int
        ? (value == 0 ? '' : '$value')
        : (value is String ? value : '');

    return TextFormField(
      initialValue: initial,
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surface,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _CardioMetrics extends ConsumerWidget {
  const _CardioMetrics({required this.index, required this.exercise});

  final int index;
  final ExerciseLog exercise;

  String? _formatValue(num? value) {
    if (value == null || value == 0) return null;
    return '$value';
  }

  String _inclineLabel() {
    if (exercise.exerciseName.contains('Bike') ||
        exercise.exerciseName.contains('Rowing')) {
      return 'Resistance';
    }
    return 'Incline %';
  }

  List<Widget> _buildSegmentsTimeline(ThemeData theme, List<CardioSegment> segments) {
    final widgets = <Widget>[];
    int currentMinutes = 0;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final start = currentMinutes;
      final end = currentMinutes + seg.durationMinutes;
      currentMinutes = end;

      final isLast = i == segments.length - 1;
      final isBikeOrRow = exercise.exerciseName.contains('Bike') || exercise.exerciseName.contains('Rowing');
      final forceLabel = isBikeOrRow ? 'Level ${seg.inclineOrResistance.toInt()}' : '${seg.inclineOrResistance.toInt()}% Incline';

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  '$start–$end min',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.circle,
                size: 6,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${seg.speedKmh} km/h  •  $forceLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricField(
                label: 'Duration',
                unit: 'min',
                value: _formatValue(exercise.durationMinutes?.round()),
                onChanged: (val) {
                  final parsed = double.tryParse(val ?? '');
                  notifier.updateCardio(
                    index,
                    durationMinutes: parsed ?? 0.0,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricField(
                label: 'Distance',
                unit: 'km',
                value: _formatValue(exercise.distanceKm),
                onChanged: (val) {
                  final parsed = double.tryParse(val ?? '');
                  notifier.updateCardio(index, distanceKm: parsed ?? 0.0);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricField(
                label: 'Speed',
                unit: 'km/h',
                value: _formatValue(exercise.speedKmh),
                onChanged: (val) {
                  final parsed = double.tryParse(val ?? '');
                  notifier.updateCardio(index, speedKmh: parsed ?? 0.0);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricField(
                label: _inclineLabel(),
                unit: '',
                value: _formatValue(
                    exercise.inclinePct ?? exercise.resistanceLevel),
                onChanged: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (exercise.exerciseName.contains('Bike') ||
                      exercise.exerciseName.contains('Rowing')) {
                    notifier.updateCardio(
                        index, resistanceLevel: parsed ?? 0.0);
                  } else {
                    notifier.updateCardio(index, inclinePct: parsed ?? 0.0);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricField(
          label: 'Estimated calories',
          unit: 'kcal',
          value: _formatValue(exercise.caloriesBurned?.round()),
          onChanged: (val) {
            final parsed = double.tryParse(val ?? '');
            notifier.updateCardio(index, caloriesBurned: parsed ?? 0.0);
          },
        ),
        if (exercise.cardioSegments != null && exercise.cardioSegments!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI CARDIO PRESCRIPTION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildSegmentsTimeline(theme, exercise.cardioSegments!),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: exercise.isCardioCompleted
                  ? Colors.green.withValues(alpha: 0.2)
                  : theme.colorScheme.primaryContainer,
              foregroundColor: exercise.isCardioCompleted
                  ? Colors.green
                  : theme.colorScheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              notifier.toggleCardioCompleted(index);
            },
            icon: Icon(
              exercise.isCardioCompleted ? Icons.check_circle : Icons.check_circle_outline,
            ),
            label: Text(
              exercise.isCardioCompleted ? 'Cardio Completed' : 'Mark Cardio as Complete',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                  onChanged: onChanged,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
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
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                          .where((e) =>
                              e.name.toLowerCase().contains(_query) ||
                              e.muscleGroup.toLowerCase().contains(_query) ||
                              e.equipment.toLowerCase().contains(_query))
                          .toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(
                      icon: Icons.search_off,
                      title: 'No exercises found',
                      subtitle: 'Try a different search term.',
                    );
                  }
                  return GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final exercise = filtered[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => widget.onSelected(exercise),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  color: const Color(0xFF1B1B1F),
                                  child: exercise.gifUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: exercise.gifUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (context, url) => const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          errorWidget: (context, url, error) => Center(
                                            child: Icon(
                                              Icons.fitness_center,
                                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Icon(
                                            Icons.fitness_center,
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${exercise.muscleGroup} • ${exercise.equipment}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor:
                          theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'REST',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 1.6,
                            ),
                          ),
                          Text(
                            _formatTime(state.remainingSeconds),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rest Period',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recover before your next set',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(restTimerProvider.notifier).addTime(30);
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('+30s'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(restTimerProvider.notifier).skip();
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubstitutionSheet extends ConsumerStatefulWidget {
  const _SubstitutionSheet({
    required this.exerciseLog,
    required this.onSelected,
  });

  final ExerciseLog exerciseLog;
  final ValueChanged<Exercise> onSelected;

  @override
  ConsumerState<_SubstitutionSheet> createState() =>
      _SubstitutionSheetState();
}

class _SubstitutionSheetState extends ConsumerState<_SubstitutionSheet> {
  String? _selectedReason;
  bool _showAlternatives = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  final List<String> _reasons = [
    'Equipment unavailable',
    'Too difficult',
    'Pain/discomfort',
    'Don\'t like this exercise',
    'Gym is crowded',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(exerciseLibraryProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        if (!_showAlternatives) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why substitute this exercise?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'GymGenie will use this reason to tailor alternative exercise suggestions.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _reasons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final reason = _reasons[idx];
                      final selected = _selectedReason == reason;
                      return _SelectableReasonTile(
                        reason: reason,
                        selected: selected,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedReason = reason;
                            _showAlternatives = true;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return libraryAsync.when(
          loading: () => const LoadingView(),
          error: (err, _) => ErrorView(message: 'Error loading exercises: $err'),
          data: (library) {
            final original = library.firstWhere(
              (ex) => ex.name == widget.exerciseLog.exerciseName,
              orElse: () => library.first,
            );

            final alternatives = library.where((ex) {
              if (ex.name == widget.exerciseLog.exerciseName) return false;
              if (ex.muscleGroup != original.muscleGroup) return false;

              if (_query.trim().isNotEmpty) {
                final q = _query.trim().toLowerCase();
                if (!ex.name.toLowerCase().contains(q) &&
                    !ex.muscleGroup.toLowerCase().contains(q) &&
                    !ex.equipment.toLowerCase().contains(q)) {
                  return false;
                }
              }
              return true;
            }).toList();

            if (_selectedReason == 'Equipment unavailable' ||
                _selectedReason == 'Gym is crowded') {
              alternatives.sort((a, b) {
                final aScore = (a.equipment.toLowerCase() == 'bodyweight' ||
                        a.equipment.toLowerCase() == 'dumbbell')
                    ? 1
                    : 0;
                final bScore = (b.equipment.toLowerCase() == 'bodyweight' ||
                        b.equipment.toLowerCase() == 'dumbbell')
                    ? 1
                    : 0;
                return bScore.compareTo(aScore);
              });
            } else if (_selectedReason == 'Too difficult' ||
                _selectedReason == 'Pain/discomfort') {
              alternatives.sort((a, b) {
                final aScore = a.difficulty.toLowerCase() == 'beginner'
                    ? 2
                    : (a.difficulty.toLowerCase() == 'intermediate' ? 1 : 0);
                final bScore = b.difficulty.toLowerCase() == 'beginner'
                    ? 2
                    : (b.difficulty.toLowerCase() == 'intermediate' ? 1 : 0);
                return bScore.compareTo(aScore);
              });
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Recommended Alternatives',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on: $_selectedReason',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search alternatives',
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: alternatives.isEmpty
                        ? const Center(child: Text('No alternatives found'))
                        : GridView.builder(
                            controller: scrollController,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: alternatives.length,
                            itemBuilder: (context, idx) {
                              final ex = alternatives[idx];
                              return Card(
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => widget.onSelected(ex),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          color: const Color(0xFF1B1B1F),
                                          child: ex.gifUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: ex.gifUrl,
                                                  fit: BoxFit.contain,
                                                  placeholder: (context, url) => const Center(
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                  errorWidget: (context, url, error) => Center(
                                                    child: Icon(
                                                      Icons.fitness_center,
                                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                )
                                              : Center(
                                                  child: Icon(
                                                    Icons.fitness_center,
                                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ex.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${ex.muscleGroup} • ${ex.equipment}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SelectableReasonTile extends StatelessWidget {
  const _SelectableReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final String reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _FinishWorkoutSheet extends ConsumerStatefulWidget {
  const _FinishWorkoutSheet();

  @override
  ConsumerState<_FinishWorkoutSheet> createState() => _FinishWorkoutSheetState();
}

class _FinishWorkoutSheetState extends ConsumerState<_FinishWorkoutSheet> {
  final _notesController = TextEditingController();
  String _difficulty = 'Moderate';
  int _energy = 3;
  String _pain = 'None';
  bool _updateOriginalPlan = false;

  final List<String> _difficulties = [
    'Very Easy',
    'Easy',
    'Moderate',
    'Hard',
    'Very Hard',
  ];

  final List<String> _pains = ['None', 'Mild', 'Moderate', 'Severe'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final hasPlan = activeWorkout != null && activeWorkout.planId.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Finish workout',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Log how the session felt. This helps GymGenie adapt future plans.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Text(
                        'Difficulty',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _difficulties.map((d) {
                          final selected = _difficulty == d;
                          return ChoiceChip(
                            label: Text(d),
                            selected: selected,
                            onSelected: (_) {
                              HapticFeedback.lightImpact();
                              setState(() => _difficulty = d);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Energy level',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          final value = index + 1;
                          final selected = _energy == value;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _energy = value);
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: selected
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      )
                                    : Border.all(
                                        color: theme.colorScheme.outline,
                                      ),
                              ),
                              child: Center(
                                child: Text(
                                  '$value',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Pain or discomfort',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pains.map((p) {
                          final selected = _pain == p;
                          return ChoiceChip(
                            label: Text(p),
                            selected: selected,
                            onSelected: (_) {
                              HapticFeedback.lightImpact();
                              setState(() => _pain = p);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Notes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'How did it go?',
                        ),
                      ),
                      if (hasPlan) ...[
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Update original plan template',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Save exercise substitutions or removals back to the plan.',
                            style: theme.textTheme.bodySmall,
                          ),
                          value: _updateOriginalPlan,
                          onChanged: (val) {
                            setState(() {
                              _updateOriginalPlan = val ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop({
                      'notes': _notesController.text.trim(),
                      'difficulty': _difficulty,
                      'energy': _energy,
                      'pain': _pain,
                      'updateOriginalPlan': _updateOriginalPlan,
                    });
                  },
                  child: const Text('Save Workout'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
