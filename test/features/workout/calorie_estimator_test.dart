import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenie/features/workout/application/calorie_estimator.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

void main() {
  const estimator = CalorieEstimator();

  test('estimates calories for a strength workout', () {
    final log = WorkoutLog(
      id: '',
      planId: 'plan-1',
      planName: 'Push Day',
      date: DateTime.now(),
      durationMinutes: 45,
      difficultyRating: 'Moderate',
      exercises: const [
        ExerciseLog(
          exerciseId: 'bench-press',
          exerciseName: 'Barbell Bench Press',
          sets: [
            SetLog(setNumber: 1, reps: 10, weight: 60, completed: true),
            SetLog(setNumber: 2, reps: 10, weight: 60, completed: true),
            SetLog(setNumber: 3, reps: 10, weight: 60, completed: true),
          ],
        ),
      ],
    );

    final estimated = estimator.estimate(log, userWeightKg: 75);

    expect(estimated.totalCalories, greaterThan(0));
    expect(estimated.exercises.first.exerciseCalories, greaterThan(0));
  });

  test('estimates calories for a cardio workout', () {
    final log = WorkoutLog(
      id: '',
      planId: 'plan-2',
      planName: 'Cardio Day',
      date: DateTime.now(),
      durationMinutes: 30,
      difficultyRating: 'Easy',
      exercises: const [
        ExerciseLog(
          exerciseId: 'treadmill',
          exerciseName: 'Treadmill Run',
          sets: const [],
          durationMinutes: 30,
        ),
      ],
    );

    final estimated = estimator.estimate(log, userWeightKg: 75);

    expect(estimated.totalCalories, greaterThan(0));
  });

  test('uses user-entered cardio calories when provided', () {
    final log = WorkoutLog(
      id: '',
      planId: 'plan-3',
      planName: 'Cardio Day',
      date: DateTime.now(),
      durationMinutes: 30,
      exercises: const [
        ExerciseLog(
          exerciseId: 'bike',
          exerciseName: 'Stationary Bike',
          sets: const [],
          durationMinutes: 30,
          caloriesBurned: 250,
        ),
      ],
    );

    final estimated = estimator.estimate(log, userWeightKg: 75);

    expect(estimated.totalCalories, 250);
  });
}
