import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';

/// A single logged set inside an [ExerciseLog].
class SetLog {
  const SetLog({
    required this.setNumber,
    required this.reps,
    required this.weight,
    this.completed = false,
  });

  /// 1-based position within the exercise.
  final int setNumber;
  final int reps;

  /// Load in kg.
  final double weight;
  final bool completed;

  SetLog copyWith({
    int? setNumber,
    int? reps,
    double? weight,
    bool? completed,
  }) {
    return SetLog(
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      completed: completed ?? this.completed,
    );
  }

  factory SetLog.fromMap(Map<String, dynamic> map) {
    return SetLog(
      setNumber: (map['setNumber'] as num?)?.toInt() ?? 0,
      reps: (map['reps'] as num?)?.toInt() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      completed: map['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'setNumber': setNumber,
      'reps': reps,
      'weight': weight,
      'completed': completed,
    };
  }
}

/// All logged sets for one exercise in a workout session.
class ExerciseLog {
  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.durationMinutes,
    this.distanceKm,
    this.speedKmh,
    this.inclinePct,
    this.resistanceLevel,
    this.caloriesBurned,
    this.cardioSegments,
  });

  final String exerciseId;
  final String exerciseName;
  final List<SetLog> sets;
  final double? durationMinutes;
  final double? distanceKm;
  final double? speedKmh;
  final double? inclinePct;
  final double? resistanceLevel;
  final double? caloriesBurned;
  final List<CardioSegment>? cardioSegments;

  double get volume => sets
      .where((s) => s.completed)
      .fold(0.0, (sum, s) => sum + s.reps * s.weight);

  double get exerciseCalories => caloriesBurned ?? 0;

  ExerciseLog copyWith({
    String? exerciseId,
    String? exerciseName,
    List<SetLog>? sets,
    double? durationMinutes,
    double? distanceKm,
    double? speedKmh,
    double? inclinePct,
    double? resistanceLevel,
    double? caloriesBurned,
    List<CardioSegment>? cardioSegments,
  }) {
    return ExerciseLog(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      speedKmh: speedKmh ?? this.speedKmh,
      inclinePct: inclinePct ?? this.inclinePct,
      resistanceLevel: resistanceLevel ?? this.resistanceLevel,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      cardioSegments: cardioSegments ?? this.cardioSegments,
    );
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map) {
    final rawSets = (map['sets'] as List<dynamic>?) ?? const <dynamic>[];
    final rawSegments = map['cardioSegments'] as List<dynamic>?;
    return ExerciseLog(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      sets: rawSets
          .map((e) => SetLog.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      durationMinutes: (map['durationMinutes'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      speedKmh: (map['speedKmh'] as num?)?.toDouble(),
      inclinePct: (map['inclinePct'] as num?)?.toDouble(),
      resistanceLevel: (map['resistanceLevel'] as num?)?.toDouble(),
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble(),
      cardioSegments: rawSegments
          ?.map((e) => CardioSegment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'sets': sets.map((s) => s.toMap()).toList(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (speedKmh != null) 'speedKmh': speedKmh,
      if (inclinePct != null) 'inclinePct': inclinePct,
      if (resistanceLevel != null) 'resistanceLevel': resistanceLevel,
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      if (cardioSegments != null)
        'cardioSegments': cardioSegments!.map((s) => s.toMap()).toList(),
    };
  }
}

/// A completed workout session, persisted under users/{uid}/logs.
class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.planId,
    required this.planName,
    required this.date,
    required this.durationMinutes,
    required this.exercises,
    this.notes = '',
    this.difficultyRating,
    this.energyLevel,
    this.painLevel,
    this.totalCaloriesBurned,
  });

  final String id;
  final String planId;
  final String planName;
  final DateTime date;
  final int durationMinutes;
  final List<ExerciseLog> exercises;
  final String notes;
  final String? difficultyRating;
  final int? energyLevel;
  final String? painLevel;

  /// Cached total calories burned for the whole session.
  final int? totalCaloriesBurned;

  double get totalVolume => exercises.fold(0.0, (s, e) => s + e.volume);

  int get totalCalories =>
      totalCaloriesBurned ??
      exercises.fold<int>(0, (sum, e) => sum + e.exerciseCalories.round());

  int get completedSets => exercises.fold(
      0, (s, e) => s + e.sets.where((st) => st.completed).length);

  factory WorkoutLog.fromMap(Map<String, dynamic> map, String id) {
    final rawExercises =
        (map['exercises'] as List<dynamic>?) ?? const <dynamic>[];
    return WorkoutLog(
      id: id,
      planId: map['planId'] as String? ?? '',
      planName: map['planName'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      exercises: rawExercises
          .map((e) => ExerciseLog.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      notes: map['notes'] as String? ?? '',
      difficultyRating: map['difficultyRating'] as String?,
      energyLevel: (map['energyLevel'] as num?)?.toInt(),
      painLevel: map['painLevel'] as String?,
      totalCaloriesBurned: (map['totalCaloriesBurned'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'planId': planId,
      'planName': planName,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'notes': notes,
      if (difficultyRating != null) 'difficultyRating': difficultyRating,
      if (energyLevel != null) 'energyLevel': energyLevel,
      if (painLevel != null) 'painLevel': painLevel,
      if (totalCaloriesBurned != null) 'totalCaloriesBurned': totalCaloriesBurned,
    };
  }
}

/// A body weight measurement, persisted under users/{uid}/bodyWeights.
class BodyWeightEntry {
  const BodyWeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
  });

  final String id;
  final DateTime date;
  final double weightKg;

  factory BodyWeightEntry.fromMap(Map<String, dynamic> map, String id) {
    return BodyWeightEntry(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': Timestamp.fromDate(date),
      'weightKg': weightKg,
    };
  }
}
