import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/features/exercises/data/exercise_repository.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';

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
  WorkoutGenerator(this._planRepo, this._exerciseRepo, this._logRepo);

  final PlanRepository _planRepo;
  final ExerciseRepository _exerciseRepo;
  final LogRepository _logRepo;

  static const Map<String, String> _cardioNames = {
    'Treadmill': 'Treadmill Cardio',
    'Bike': 'Cycling Cardio',
    'Elliptical': 'Elliptical Cardio',
    'Rowing': 'Rowing Machine Cardio',
    'Stair climber': 'Stair Climber Cardio',
  };

  /// Monday-aligned start of the week containing [date].
  DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Returns the Monday on which the next AI program should start.
  ///
  /// - First program ever → current week's Monday (Week 1).
  /// - Subsequent programs → Monday after the latest existing week.
  DateTime _nextProgramStartDate(List<WorkoutPlan> existingPlans) {
    if (existingPlans.isEmpty) return _weekStart(DateTime.now());

    final sorted = [...existingPlans]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestWeekStart = _weekStart(sorted.first.createdAt);
    return latestWeekStart.add(const Duration(days: 7));
  }

  /// True when the latest existing week is finished.
  ///
  /// A week is finished if:
  /// - it is in the past (its Monday is before the current Monday), or
  /// - every plan in that week has at least one logged workout.
  ///
  /// Partial progress counts: a single log for a plan means the user
  /// attempted that day.
  Future<bool> isLatestWeekFinished(List<WorkoutPlan> existingPlans) async {
    if (existingPlans.isEmpty) return true;

    final sorted = [...existingPlans]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestWeekStart = _weekStart(sorted.first.createdAt);
    final currentWeekStart = _weekStart(DateTime.now());

    if (latestWeekStart.isBefore(currentWeekStart)) return true;

    final logs = await _logRepo.watchLogs().first;
    final attemptedPlanIds = logs.map((l) => l.planId).toSet();

    final latestWeekPlans = existingPlans.where(
      (p) => _weekStart(p.createdAt) == latestWeekStart,
    );
    return latestWeekPlans.every((p) => attemptedPlanIds.contains(p.id));
  }

  /// Human-readable list of day names in the latest week that have not been
  /// attempted yet.
  Future<List<String>> unattemptedDaysInLatestWeek(
    List<WorkoutPlan> existingPlans,
  ) async {
    if (existingPlans.isEmpty) return const <String>[];

    final sorted = [...existingPlans]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestWeekStart = _weekStart(sorted.first.createdAt);
    final logs = await _logRepo.watchLogs().first;
    final attemptedPlanIds = logs.map((l) => l.planId).toSet();

    return existingPlans
        .where((p) => _weekStart(p.createdAt) == latestWeekStart)
        .where((p) => !attemptedPlanIds.contains(p.id))
        .map((p) => p.name)
        .toList();
  }

  /// Generates a set of plans based on survey data and saves them to Firestore.
  Future<void> generateAndSaveProgram(SurveyData survey) async {
    // Load existing plans and enforce the "finish current week" rule.
    final existingPlans = await _planRepo.watchPlans().first;
    final canGenerate = await isLatestWeekFinished(existingPlans);
    if (!canGenerate) {
      final unattempted = await unattemptedDaysInLatestWeek(existingPlans);
      final days = unattempted.map((n) => '• $n').join('\n');
      throw StateError(
        'Finish your current week before generating the next one.\n\n'
        'These days still need a workout:\n$days',
      );
    }

    final programStart = _nextProgramStartDate(existingPlans);
    final exercises = await _exerciseRepo.loadExercises();

    // Load logs to evaluate adaptive feedback
    final logs = await _logRepo.watchLogs().first;
    double factor = 1.0;
    String? adaptationMessage;

    if (logs.isNotEmpty) {
      final lastLog = logs.first;
      final diffRating = lastLog.difficultyRating;
      final pain = lastLog.painLevel;
      final energy = lastLog.energyLevel;

      final isHardDifficulty = diffRating == 'Hard' || diffRating == 'Very Hard';
      final isSeverePain = pain == 'Moderate' || pain == 'Severe';
      final isLowEnergy = energy != null && energy <= 2;

      if (isHardDifficulty || isSeverePain || isLowEnergy) {
        factor = 0.85;
        adaptationMessage = "Your last session was harder than expected. Today's workout has been reduced by approximately 15%.";
      } else if (logs.length >= 3) {
        bool comfortable = true;
        for (var i = 0; i < 3; i++) {
          final log = logs[i];
          final d = log.difficultyRating;
          final p = log.painLevel;
          final e = log.energyLevel;

          final isComfortableDifficulty = d == 'Easy' || d == 'Very Easy' || d == 'Moderate';
          final isComfortablePain = p == 'None' || p == 'Mild';
          final isHighEnergy = e == null || e >= 4;

          int totalLoggedSets = 0;
          int completedLoggedSets = 0;
          for (final exLog in log.exercises) {
            totalLoggedSets += exLog.sets.length;
            completedLoggedSets += exLog.sets.where((s) => s.completed).length;
          }
          final completionRate = totalLoggedSets > 0 ? (completedLoggedSets / totalLoggedSets) : 0.0;

          if (!isComfortableDifficulty || !isComfortablePain || !isHighEnergy || completionRate < 0.90) {
            comfortable = false;
            break;
          }
        }

        if (comfortable) {
          factor = 1.10;
          adaptationMessage = "You completed your last three sessions comfortably. GymZish has increased the training stimulus slightly.";
        }
      }
    }

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
        var targetSets = _determineSets(survey.level);
        var targetReps = _determineReps(survey.goal);
        var targetWeight = survey.experience == 'Beginner' ? 0.0 : 10.0;

        if (factor < 1.0) {
          targetSets = max(2, targetSets - 1);
          targetReps = max(5, (targetReps * factor).round());
          if (targetWeight > 0) {
            targetWeight = (targetWeight * factor).roundToDouble();
          }
        } else if (factor > 1.0) {
          targetSets = min(5, targetSets + 1);
          targetReps = min(20, (targetReps * factor).round());
          if (targetWeight > 0) {
            targetWeight = (targetWeight * factor).roundToDouble();
          }
        }

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
        var cardioDuration = _determineCardioDuration(survey.goal, survey.durationMinutes);
        var cardioResistance = _determineCardioResistance(survey.level);

        if (factor != 1.0) {
          cardioDuration = max(10, (cardioDuration * factor).round());
          cardioResistance = max(1.0, (cardioResistance * factor).roundToDouble());
        }

        plannedExercises.add(PlannedExercise(
          exerciseId: chosenCardio.toLowerCase().replaceAll(' ', '-'),
          exerciseName: cardioName,
          targetSets: 1,
          targetReps: 1,
          targetWeight: 0.0,
          order: orderIdx++,
          isCardio: true,
          targetDurationMinutes: cardioDuration,
          targetResistanceLevel: cardioResistance,
        ));
      }

      // 5. Create and save the WorkoutPlan
      final plan = WorkoutPlan(
        id: '',
        name: '${survey.goal} - Day ${d + 1} ($dayName)',
        description: 'AI Generated plan for ${survey.experience} level based on a ${survey.daysPerWeek}-day split.',
        exercises: plannedExercises,
        createdAt: programStart,
        updatedAt: programStart,
        adaptationMessage: adaptationMessage,
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

  double _determineCardioResistance(String level) {
    switch (level.toLowerCase()) {
      case 'easy':
        return 3.0;
      case 'hard':
        return 8.0;
      default:
        return 5.0; // Moderate
    }
  }
}

final workoutGeneratorProvider = Provider<WorkoutGenerator>((ref) {
  return WorkoutGenerator(
    ref.watch(planRepositoryProvider),
    ref.watch(exerciseRepositoryProvider),
    ref.watch(logRepositoryProvider),
  );
});
