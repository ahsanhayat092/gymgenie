import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';

/// Loads the exercise library from Firestore, falling back to the bundled 
/// `assets/exercises.json` catalog if offline or if Firestore is unavailable.
/// Seeds local exercises to Firestore on the first run if the collection is empty.
class ExerciseRepository {
  ExerciseRepository(this._firestore);

  final FirebaseFirestore _firestore;
  List<Exercise>? _cache;

  static const List<String> muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Legs',
    'Arms',
    'Core',
  ];

  /// Loads the bundled local exercise JSON catalog.
  Future<List<Exercise>> loadLocalExercises() async {
    final raw = await rootBundle.loadString('assets/exercises.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  /// Fetches exercises from Firestore with an automatic local fallback.
  Future<List<Exercise>> loadExercises() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final snapshot = await _firestore
          .collection('exercises')
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isEmpty) {
        // Firestore is empty — seed default exercises from local catalog
        final local = await loadLocalExercises();
        for (final e in local) {
          _firestore.collection('exercises').doc(e.id).set(e.toMap()).catchError((_) {});
        }
        _cache = local;
        return local;
      }

      final exercises = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id') || (data['id'] as String).isEmpty) {
          data['id'] = doc.id;
        }
        return Exercise.fromJson(data);
      }).toList();

      // Sort alphabetically by name
      exercises.sort((a, b) => a.name.compareTo(b.name));
      _cache = exercises;
      return exercises;
    } catch (e) {
      // Fallback to local offline catalog if Firestore is offline, permission is denied, or it times out
      final local = await loadLocalExercises();
      _cache = local;
      return local;
    }
  }

  /// Looks up a single exercise by its unique slug [id].
  Future<Exercise?> getExerciseById(String id) async {
    final exercises = await loadExercises();
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(firestoreProvider)),
);

final exerciseLibraryProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).loadExercises(),
);

final exerciseByIdProvider = FutureProvider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).getExerciseById(id),
);
