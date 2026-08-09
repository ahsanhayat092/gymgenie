import 'package:cloud_firestore/cloud_firestore.dart';

/// An exercise slot inside a [WorkoutPlan], with target set/rep/weight goals.
class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeight,
    required this.order,
  });

  final String exerciseId;
  final String exerciseName;

  /// >= 1.
  final int targetSets;

  /// >= 1.
  final int targetReps;

  /// kg, 0.0 = bodyweight/unspecified.
  final double targetWeight;

  /// 0-based position in the plan.
  final int order;

  PlannedExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    int? targetSets,
    int? targetReps,
    double? targetWeight,
    int? order,
  }) {
    return PlannedExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeight: targetWeight ?? this.targetWeight,
      order: order ?? this.order,
    );
  }

  factory PlannedExercise.fromMap(Map<String, dynamic> map) {
    return PlannedExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      targetSets: (map['targetSets'] as num?)?.toInt() ?? 1,
      targetReps: (map['targetReps'] as num?)?.toInt() ?? 1,
      targetWeight: (map['targetWeight'] as num?)?.toDouble() ?? 0.0,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'targetWeight': targetWeight,
      'order': order,
    };
  }
}

/// A reusable workout template stored under `users/{uid}/plans/{planId}`.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.exercises,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final List<PlannedExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutPlan copyWith({
    String? id,
    String? name,
    String? description,
    List<PlannedExercise>? exercises,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WorkoutPlan.fromMap(Map<String, dynamic> map, String id) {
    final rawExercises = map['exercises'] as List<dynamic>? ?? const [];
    return WorkoutPlan(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      exercises: rawExercises
          .map((e) =>
              PlannedExercise.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
