import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/features/exercises/data/exercise_repository.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';

class SurveyData {
  SurveyData({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.experience,
    required this.goal,
    required this.daysPerWeek,
    required this.durationMinutes,
    required this.level,
    required this.equipment,
    required this.cardioAvailable,
  });

  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final String experience; // Beginner, Intermediate, Advanced
  final String goal; // Lose weight, Build muscle, Strength, Fat loss + muscle retention, General fitness, Improve endurance
  final int daysPerWeek; // 2..6
  final int durationMinutes; // 30, 45, 60, 90
  final String level; // Easy, Moderate, Hard
  final List<String> equipment; // e.g. ["Barbell", "Dumbbell", "Cable", "Bodyweight", "Machine"]
  final List<String> cardioAvailable; // e.g. ["Treadmill", "Bike", "Elliptical", "Rowing", "Stair climber"]
}

class WorkoutGenerator {
  WorkoutGenerator(this._planRepo, this._exerciseRepo);

  final PlanRepository _planRepo;
  final ExerciseRepository _exerciseRepo;

  static const Map<String, String> _cardioNames = {
    'Treadmill': 'Treadmill Cardio',
    'Bike': 'Cycling Cardio',
    'Elliptical': 'Elliptical Cardio',
    'Rowing': 'Rowing Machine Cardio',
    'Stair climber': 'Stair Climber Cardio',
  };

  /// Generates a set of plans based on survey data and saves them to Firestore.
  Future<void> generateAndSaveProgram(SurveyData survey) async {
    final exercises = await _exerciseRepo.loadExercises();

    // 1. Filter exercises by equipment selection.
    // Bodyweight is always available.
    final allowedEquipment = survey.equipment.map((e) => e.toLowerCase()).toSet();
    final filteredExercises = exercises.where((ex) {
      final eq = ex.equipment.toLowerCase();
      return eq == 'bodyweight' || allowedEquipment.contains(eq);
    }).toList();

    // 2. Define splits based on days per week.
    final splitDays = _determineSplits(survey.daysPerWeek);

    // 3. Generate daily plans
    final random = Random();
    for (var d = 0; d < splitDays.length; d++) {
      final daySplit = splitDays[d];
      final targetMuscles = daySplit['muscles'] as List<String>;
      final dayName = daySplit['name'] as String;

      // Filter exercises targeting this day's muscles
      final pool = filteredExercises
          .where((ex) => targetMuscles.contains(ex.muscleGroup))
          .toList();

      // Sort by difficulty matching experience
      pool.sort((a, b) {
        final diffA = _difficultyWeight(a.difficulty, survey.experience);
        final diffB = _difficultyWeight(b.difficulty, survey.experience);
        return diffB.compareTo(diffA); // higher weight first
      });

      // Select N strength exercises
      final strengthCount = _determineStrengthCount(survey.durationMinutes);
      final selectedStrength = <Exercise>[];
      final seenIds = <String>{};

      for (final ex in pool) {
        if (selectedStrength.length >= strengthCount) break;
        if (!seenIds.contains(ex.id)) {
          selectedStrength.add(ex);
          seenIds.add(ex.id);
        }
      }

      // If pool is small, backfill with bodyweight exercises
      if (selectedStrength.length < strengthCount) {
        final bodyweightBackfill = exercises
            .where((ex) => targetMuscles.contains(ex.muscleGroup) && ex.equipment.toLowerCase() == 'bodyweight')
            .toList();
        for (final ex in bodyweightBackfill) {
          if (selectedStrength.length >= strengthCount) break;
          if (!seenIds.contains(ex.id)) {
            selectedStrength.add(ex);
            seenIds.add(ex.id);
          }
        }
      }

      // Map to PlannedExercise objects
      final List<PlannedExercise> plannedExercises = [];
      var orderIdx = 0;

      for (final ex in selectedStrength) {
        final targetSets = _determineSets(survey.level);
        final targetReps = _determineReps(survey.goal);
        final targetWeight = survey.experience == 'Beginner' ? 0.0 : 10.0;

        plannedExercises.add(PlannedExercise(
          exerciseId: ex.id,
          exerciseName: ex.name,
          targetSets: targetSets,
          targetReps: targetReps,
          targetWeight: targetWeight,
          order: orderIdx++,
        ));
      }

      // 4. Append cardio segment if applicable
      final needsCardio = _shouldIncludeCardio(survey.goal);
      if (needsCardio && survey.cardioAvailable.isNotEmpty) {
        final chosenCardio = survey.cardioAvailable[random.nextInt(survey.cardioAvailable.length)];
        final cardioName = _cardioNames[chosenCardio] ?? 'General Cardio';
        
        // Target Sets = 1, Target Reps = 1 (representing a single cardio block duration)
        plannedExercises.add(PlannedExercise(
          exerciseId: chosenCardio.toLowerCase().replaceAll(' ', '-'),
          exerciseName: cardioName,
          targetSets: 1,
          targetReps: _determineCardioDuration(survey.goal, survey.durationMinutes),
          targetWeight: 0.0, // weight is 0 for cardio
          order: orderIdx++,
        ));
      }

      // 5. Create and save the WorkoutPlan
      final plan = WorkoutPlan(
        id: '',
        name: '${survey.goal} - Day ${d + 1} ($dayName)',
        description: 'AI Generated plan for ${survey.experience} level based on a ${survey.daysPerWeek}-day split.',
        exercises: plannedExercises,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _planRepo.createPlan(plan);
    }
  }

  List<Map<String, dynamic>> _determineSplits(int days) {
    if (days <= 2) {
      return [
        {'name': 'Upper Focus', 'muscles': ['Chest', 'Back', 'Shoulders', 'Arms']},
        {'name': 'Lower & Core', 'muscles': ['Legs', 'Core']},
      ];
    } else if (days == 3) {
      return [
        {'name': 'Push (Chest/Shoulders/Triceps)', 'muscles': ['Chest', 'Shoulders', 'Arms']},
        {'name': 'Pull (Back/Biceps)', 'muscles': ['Back', 'Arms']},
        {'name': 'Legs & Core', 'muscles': ['Legs', 'Core']},
      ];
    } else if (days == 4) {
      return [
        {'name': 'Upper Body A', 'muscles': ['Chest', 'Back', 'Arms']},
        {'name': 'Lower Body A', 'muscles': ['Legs', 'Core']},
        {'name': 'Upper Body B', 'muscles': ['Chest', 'Shoulders', 'Arms']},
        {'name': 'Lower Body B', 'muscles': ['Legs', 'Core']},
      ];
    } else if (days == 5) {
      return [
        {'name': 'Chest & Shoulders', 'muscles': ['Chest', 'Shoulders']},
        {'name': 'Back & Biceps', 'muscles': ['Back', 'Arms']},
        {'name': 'Legs Focus', 'muscles': ['Legs']},
        {'name': 'Arms & Core', 'muscles': ['Arms', 'Core']},
        {'name': 'Active Recovery & Core', 'muscles': ['Core']},
      ];
    } else {
      return [
        {'name': 'Push A', 'muscles': ['Chest', 'Shoulders', 'Arms']},
        {'name': 'Pull A', 'muscles': ['Back', 'Arms']},
        {'name': 'Legs A', 'muscles': ['Legs', 'Core']},
        {'name': 'Push B', 'muscles': ['Chest', 'Shoulders', 'Arms']},
        {'name': 'Pull B', 'muscles': ['Back', 'Arms']},
        {'name': 'Legs B', 'muscles': ['Legs', 'Core']},
      ];
    }
  }

  int _difficultyWeight(String diff, String experience) {
    final d = diff.toLowerCase();
    final exp = experience.toLowerCase();
    if (exp == 'beginner') {
      if (d == 'beginner') return 3;
      if (d == 'intermediate') return 2;
      return 0; // avoid advanced
    } else if (exp == 'advanced') {
      if (d == 'advanced') return 3;
      if (d == 'intermediate') return 2;
      return 1;
    } else {
      if (d == 'intermediate') return 3;
      if (d == 'beginner') return 2;
      return 1;
    }
  }

  int _determineStrengthCount(int duration) {
    if (duration <= 30) return 3;
    if (duration <= 45) return 4;
    if (duration <= 60) return 5;
    return 6;
  }

  int _determineSets(String level) {
    final l = level.toLowerCase();
    if (l == 'easy') return 2;
    if (l == 'hard') return 4;
    return 3; // moderate
  }

  int _determineReps(String goal) {
    final g = goal.toLowerCase();
    if (g.contains('strength')) return 6; // low reps strength
    if (g.contains('muscle') || g.contains('hypertrophy')) return 10; // hypertrophy
    return 12; // endurance / fat loss
  }

  bool _shouldIncludeCardio(String goal) {
    final g = goal.toLowerCase();
    return g.contains('weight') || g.contains('fat') || g.contains('endurance') || g.contains('fitness');
  }

  int _determineCardioDuration(String goal, int totalMinutes) {
    final g = goal.toLowerCase();
    var pct = 0.20; // default 20%
    if (g.contains('weight') || g.contains('fat')) {
      pct = 0.35; // 35% time is cardio
    } else if (g.contains('endurance')) {
      pct = 0.50; // 50% time is cardio
    }
    return (totalMinutes * pct).round();
  }
}

final workoutGeneratorProvider = Provider<WorkoutGenerator>((ref) {
  return WorkoutGenerator(
    ref.watch(planRepositoryProvider),
    ref.watch(exerciseRepositoryProvider),
  );
});
