import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/workout/application/calorie_estimator.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

/// In-progress workout session state.
class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.planId,
    required this.planName,
    required this.startedAt,
    required this.exercises,
  });

  /// Empty string for ad-hoc sessions.
  final String planId;
  final String planName;
  final DateTime startedAt;

  /// Mutable-copy workflow: controller methods replace this list.
  final List<ExerciseLog> exercises;

  int get elapsedMinutes => DateTime.now().difference(startedAt).inMinutes;
}

class ActiveWorkoutController extends StateNotifier<ActiveWorkoutState?> {
  ActiveWorkoutController(this._logRepo, this._calorieEstimator) : super(null);

  final LogRepository _logRepo;
  final CalorieEstimator _calorieEstimator;

  /// Starts a session from a plan. Each planned exercise gets
  /// `targetSets` empty sets (completed = false) prefilled with the
  /// plan's target reps/weight.
  void startFromPlan(WorkoutPlan plan, {WorkoutLog? lastLog}) {
    final exercises = plan.exercises.map((pe) {
      // ── Cardio exercises: no sets — pre-seed duration & resistance ──────────
      if (pe.isCardio) {
        return ExerciseLog(
          exerciseId: pe.exerciseId,
          exerciseName: pe.exerciseName,
          sets: const [],
          durationMinutes: (pe.targetDurationMinutes ?? 20).toDouble(),
          resistanceLevel: pe.targetResistanceLevel ?? 5.0,
        );
      }

      // ── Strength exercises: build sets with adaptive progression ────────────
      var targetSets = pe.targetSets;
      var targetReps = pe.targetReps;
      var targetWeight = pe.targetWeight;

      if (lastLog != null) {
        final diff = lastLog.difficultyRating?.toLowerCase();
        final pain = lastLog.painLevel?.toLowerCase();

        if (diff == 'very easy' || diff == 'easy') {
          targetWeight += 2.5;
        } else if (diff == 'very hard' || pain == 'moderate' || pain == 'severe') {
          targetSets = (targetSets * 0.85).round().clamp(2, 6);
          targetReps = (targetReps * 0.85).round().clamp(1, 30);
        }
      }

      final sets = List<SetLog>.generate(
        targetSets,
        (i) => SetLog(
          setNumber: i + 1,
          reps: targetReps,
          weight: targetWeight,
          completed: false,
        ),
      );
      return ExerciseLog(
        exerciseId: pe.exerciseId,
        exerciseName: pe.exerciseName,
        sets: sets,
      );
    }).toList();

    state = ActiveWorkoutState(
      planId: plan.id,
      planName: plan.name,
      startedAt: DateTime.now(),
      exercises: exercises,
    );
  }

  /// Starts an ad-hoc session with no exercises.
  void startEmpty(String name) {
    state = ActiveWorkoutState(
      planId: '',
      planName: name,
      startedAt: DateTime.now(),
      exercises: const <ExerciseLog>[],
    );
  }

  void addExercise(Exercise exercise) {
    final current = state;
    if (current == null) return;
    final updated = List<ExerciseLog>.of(current.exercises)
      ..add(ExerciseLog(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        sets: const <SetLog>[
          SetLog(setNumber: 1, reps: 0, weight: 0.0, completed: false),
        ],
      ));
    state = ActiveWorkoutState(
      planId: current.planId,
      planName: current.planName,
      startedAt: current.startedAt,
      exercises: updated,
    );
  }

  void updateSet(int exerciseIndex, int setIndex,
      {int? reps, double? weight, bool? completed}) {
    final current = state;
    if (current == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= current.exercises.length) return;
    final exercise = current.exercises[exerciseIndex];
    if (setIndex < 0 || setIndex >= exercise.sets.length) return;

    final newSets = List<SetLog>.of(exercise.sets);
    newSets[setIndex] = newSets[setIndex].copyWith(
      reps: reps,
      weight: weight,
      completed: completed,
    );
    _replaceExercise(
        current, exerciseIndex, _copyExercise(exercise, sets: newSets));
  }

  void addSet(int exerciseIndex) {
    final current = state;
    if (current == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= current.exercises.length) return;
    final exercise = current.exercises[exerciseIndex];
    final newSets = List<SetLog>.of(exercise.sets);
    final template = newSets.isNotEmpty ? newSets.last : null;
    newSets.add(SetLog(
      setNumber: newSets.length + 1,
      reps: template?.reps ?? 0,
      weight: template?.weight ?? 0.0,
      completed: false,
    ));
    _replaceExercise(
        current, exerciseIndex, _copyExercise(exercise, sets: newSets));
  }

  /// Removes the set and renumbers the remaining sets (1-based).
  void removeSet(int exerciseIndex, int setIndex) {
    final current = state;
    if (current == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= current.exercises.length) return;
    final exercise = current.exercises[exerciseIndex];
    if (setIndex < 0 || setIndex >= exercise.sets.length) return;

    final newSets = List<SetLog>.of(exercise.sets)..removeAt(setIndex);
    final renumbered = <SetLog>[
      for (var i = 0; i < newSets.length; i++)
        newSets[i].copyWith(setNumber: i + 1),
    ];
    _replaceExercise(
        current, exerciseIndex, _copyExercise(exercise, sets: renumbered));
  }

  void removeExercise(int exerciseIndex) {
    final current = state;
    if (current == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= current.exercises.length) return;
    final updated = List<ExerciseLog>.of(current.exercises)
      ..removeAt(exerciseIndex);
    state = ActiveWorkoutState(
      planId: current.planId,
      planName: current.planName,
      startedAt: current.startedAt,
      exercises: updated,
    );
  }

  /// Builds the [WorkoutLog] (duration = elapsed minutes, minimum 1),
  /// saves it via [LogRepository.addLog], clears the state and returns
  /// the saved log (with its Firestore id).
  Future<WorkoutLog> finish({
    String notes = '',
    String? difficultyRating,
    int? energyLevel,
    String? painLevel,
    double userWeightKg = 70.0,
  }) async {
    final current = state;
    if (current == null) {
      throw StateError('No active workout to finish');
    }
    final elapsed = current.elapsedMinutes;
    final log = WorkoutLog(
      id: '',
      planId: current.planId,
      planName: current.planName,
      date: DateTime.now(),
      durationMinutes: elapsed < 1 ? 1 : elapsed,
      exercises: current.exercises,
      notes: notes,
      difficultyRating: difficultyRating,
      energyLevel: energyLevel,
      painLevel: painLevel,
    );

    final estimatedLog = _calorieEstimator.estimate(log, userWeightKg: userWeightKg);
    final id = await _logRepo.addLog(estimatedLog);
    final saved = WorkoutLog(
      id: id,
      planId: estimatedLog.planId,
      planName: estimatedLog.planName,
      date: estimatedLog.date,
      durationMinutes: estimatedLog.durationMinutes,
      exercises: estimatedLog.exercises,
      notes: estimatedLog.notes,
      difficultyRating: estimatedLog.difficultyRating,
      energyLevel: estimatedLog.energyLevel,
      painLevel: estimatedLog.painLevel,
      totalCaloriesBurned: estimatedLog.totalCaloriesBurned,
    );
    state = null;
    return saved;
  }

  void discard() {
    state = null;
  }

  void updateCardio(
    int exerciseIndex, {
    double? durationMinutes,
    double? distanceKm,
    double? speedKmh,
    double? inclinePct,
    double? resistanceLevel,
    double? caloriesBurned,
  }) {
    final current = state;
    if (current == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= current.exercises.length) return;
    final exercise = current.exercises[exerciseIndex];

    final updated = ExerciseLog(
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.exerciseName,
      sets: exercise.sets,
      durationMinutes: durationMinutes ?? exercise.durationMinutes,
      distanceKm: distanceKm ?? exercise.distanceKm,
      speedKmh: speedKmh ?? exercise.speedKmh,
      inclinePct: inclinePct ?? exercise.inclinePct,
      resistanceLevel: resistanceLevel ?? exercise.resistanceLevel,
      caloriesBurned: caloriesBurned ?? exercise.caloriesBurned,
    );
    _replaceExercise(current, exerciseIndex, updated);
  }

  void substituteExercise(int index, Exercise newExercise) {
    final current = state;
    if (current == null) return;
    if (index < 0 || index >= current.exercises.length) return;
    final exercise = current.exercises[index];

    final updated = ExerciseLog(
      exerciseId: newExercise.id,
      exerciseName: newExercise.name,
      sets: exercise.sets,
      durationMinutes: exercise.durationMinutes,
      distanceKm: exercise.distanceKm,
      speedKmh: exercise.speedKmh,
      inclinePct: exercise.inclinePct,
      resistanceLevel: exercise.resistanceLevel,
      caloriesBurned: exercise.caloriesBurned,
    );
    _replaceExercise(current, index, updated);
  }

  ExerciseLog _copyExercise(ExerciseLog exercise, {List<SetLog>? sets}) {
    return ExerciseLog(
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.exerciseName,
      sets: sets ?? exercise.sets,
      durationMinutes: exercise.durationMinutes,
      distanceKm: exercise.distanceKm,
      speedKmh: exercise.speedKmh,
      inclinePct: exercise.inclinePct,
      resistanceLevel: exercise.resistanceLevel,
      caloriesBurned: exercise.caloriesBurned,
    );
  }

  void _replaceExercise(
      ActiveWorkoutState current, int index, ExerciseLog replacement) {
    final updated = List<ExerciseLog>.of(current.exercises);
    updated[index] = replacement;
    state = ActiveWorkoutState(
      planId: current.planId,
      planName: current.planName,
      startedAt: current.startedAt,
      exercises: updated,
    );
  }
}

final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutController, ActiveWorkoutState?>(
  (ref) => ActiveWorkoutController(
    ref.watch(logRepositoryProvider),
    ref.watch(calorieEstimatorProvider),
  ),
);
