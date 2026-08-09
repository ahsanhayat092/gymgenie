import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/exercises/domain/exercise.dart';

/// Loads the bundled exercise library from `assets/exercises.json`.
/// The decoded list is cached in memory after the first load.
class ExerciseRepository {
  List<Exercise>? _cache;

  static const List<String> muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Legs',
    'Arms',
    'Core',
  ];

  Future<List<Exercise>> loadExercises() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/exercises.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final exercises = decoded
        .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
    _cache = exercises;
    return exercises;
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(),
);

final exerciseLibraryProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).loadExercises(),
);
