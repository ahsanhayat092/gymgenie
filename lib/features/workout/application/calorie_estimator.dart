import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/workout/domain/workout_log.dart';

/// Approximates calories burned for a completed workout.
///
/// Uses a deterministic model based on MET values, exercise volume,
/// session duration, user body weight, and the self-reported difficulty
/// rating. The result is reasonable for fitness tracking while staying
/// fully offline and private.
class CalorieEstimator {
  const CalorieEstimator();

  static const double _defaultWeightKg = 70.0;

  /// Difficulty multipliers applied to the whole workout.
  static const Map<String, double> _difficultyFactors = {
    'Very Easy': 0.85,
    'Easy': 0.92,
    'Moderate': 1.0,
    'Hard': 1.1,
    'Very Hard': 1.2,
  };

  /// Estimates cardio MET from the exercise name.
  double _cardioMet(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('run') || name.contains('sprint')) return 9.8;
    if (name.contains('treadmill')) return 9.0;
    if (name.contains('elliptical')) return 8.3;
    if (name.contains('row') || name.contains('rowing')) return 7.0;
    if (name.contains('bike') || name.contains('cycling')) return 7.5;
    if (name.contains('swim')) return 7.0;
    if (name.contains('walk')) return 3.8;
    if (name.contains('stair')) return 8.0;
    return 7.0; // Generic cardio
  }

  /// Returns a new [WorkoutLog] with per-exercise and total calorie estimates.
  WorkoutLog estimate(WorkoutLog log, {double userWeightKg = _defaultWeightKg}) {
    final weight = userWeightKg > 0 ? userWeightKg : _defaultWeightKg;
    final difficultyFactor = _difficultyFactors[log.difficultyRating] ?? 1.0;

    // Total completed sets across strength exercises to allocate duration.
    final totalStrengthSets = log.exercises
        .where((e) => e.sets.isNotEmpty)
        .fold<int>(0, (sum, e) => sum + e.sets.where((s) => s.completed).length);

    final estimatedExercises = <ExerciseLog>[];
    var rawTotal = 0.0;

    for (final exercise in log.exercises) {
      if (exercise.sets.isEmpty) {
        // Cardio path.
        final kcal = _estimateCardio(exercise, weight);
        rawTotal += kcal;
        estimatedExercises.add(
          exercise.copyWith(caloriesBurned: kcal.roundToDouble()),
        );
      } else {
        // Strength path.
        final completedSets = exercise.sets.where((s) => s.completed).length;
        final kcal = _estimateStrength(
          exercise,
          weight: weight,
          workoutDurationMinutes: log.durationMinutes,
          completedSets: completedSets,
          totalStrengthSets: totalStrengthSets,
        );
        rawTotal += kcal;
        estimatedExercises.add(
          exercise.copyWith(caloriesBurned: kcal.roundToDouble()),
        );
      }
    }

    final totalCalories = (rawTotal * difficultyFactor).round();

    return WorkoutLog(
      id: log.id,
      planId: log.planId,
      planName: log.planName,
      date: log.date,
      durationMinutes: log.durationMinutes,
      exercises: estimatedExercises,
      notes: log.notes,
      difficultyRating: log.difficultyRating,
      energyLevel: log.energyLevel,
      painLevel: log.painLevel,
      totalCaloriesBurned: totalCalories,
    );
  }

  double _estimateCardio(ExerciseLog exercise, double weightKg) {
    // Respect user-entered calorie value if provided.
    if (exercise.caloriesBurned != null && exercise.caloriesBurned! > 0) {
      return exercise.caloriesBurned!;
    }

    final durationMinutes = exercise.durationMinutes ?? 0;
    if (durationMinutes <= 0) return 0;

    final met = _cardioMet(exercise.exerciseName);
    final hours = durationMinutes / 60.0;
    return met * weightKg * hours * 1.05;
  }

  double _estimateStrength(
    ExerciseLog exercise, {
    required double weight,
    required int workoutDurationMinutes,
    required int completedSets,
    required int totalStrengthSets,
  }) {
    if (completedSets == 0) return 0;

    // Base energy cost of resistance training: MET ~4.
    final shareOfDuration = totalStrengthSets > 0
        ? completedSets / totalStrengthSets
        : 1.0 / (workoutDurationMinutes > 0 ? 1 : 1);
    final exerciseMinutes = workoutDurationMinutes * shareOfDuration;
    final baseKcal = 4.0 * weight * (exerciseMinutes / 60.0) * 1.05;

    // Volume bonus: heavier work burns more.
    final volume = exercise.volume;
    final volumeBonus = volume * 0.05;

    return baseKcal + volumeBonus;
  }
}

final calorieEstimatorProvider = Provider<CalorieEstimator>(
  (ref) => const CalorieEstimator(),
);
