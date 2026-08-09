import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';

/// Firestore access for workout plans, scoped to the signed-in user at
/// `users/{uid}/plans`. This is the ONLY place plan Firestore data is touched.
class PlanRepository {
  PlanRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.collection('users').doc(_uid).collection('plans');

  /// Newest-updated first.
  Stream<List<WorkoutPlan>> watchPlans() {
    return _plans
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutPlan.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<WorkoutPlan?> getPlan(String id) async {
    try {
      final doc = await _plans.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return WorkoutPlan.fromMap(data, doc.id);
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to load plan');
    }
  }

  /// Creates a new plan doc; returns the new doc id.
  /// Stamps createdAt/updatedAt with the current time.
  Future<String> createPlan(WorkoutPlan plan) async {
    try {
      final doc = _plans.doc();
      final now = DateTime.now();
      final stamped =
          plan.copyWith(id: doc.id, createdAt: now, updatedAt: now);
      await doc.set(stamped.toMap());
      return doc.id;
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to create plan');
    }
  }

  /// Overwrites an existing plan; stamps updatedAt with the current time.
  Future<void> updatePlan(WorkoutPlan plan) async {
    try {
      final stamped = plan.copyWith(updatedAt: DateTime.now());
      await _plans.doc(plan.id).set(stamped.toMap());
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to update plan');
    }
  }

  Future<void> deletePlan(String id) async {
    try {
      await _plans.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to delete plan');
    }
  }

  /// Uploads a copy of the plan to the global `/shared_plans` collection.
  /// Returns the global shared plan document ID.
  Future<String> sharePlan(WorkoutPlan plan) async {
    try {
      final doc = _firestore.collection('shared_plans').doc();
      final now = DateTime.now();
      await doc.set({
        'name': plan.name,
        'description': plan.description,
        'exercises': plan.exercises.map((e) => e.toMap()).toList(),
        'sharedBy': _uid,
        'sharedAt': Timestamp.fromDate(now),
      });
      return doc.id;
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to share plan');
    }
  }

  /// Fetches a shared plan from the global `/shared_plans` collection and imports it
  /// as a new local plan for the current user.
  Future<void> importPlan(String sharedPlanId) async {
    try {
      var cleanCode = sharedPlanId.trim();
      if (cleanCode.contains('code=')) {
        cleanCode = cleanCode.split('code=').last.split('&').first.trim();
      }
      if (cleanCode.isEmpty) {
        throw StateError('Invalid sharing code or link.');
      }
      final doc = await _firestore.collection('shared_plans').doc(cleanCode).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        throw StateError('Shared plan not found.');
      }
      final name = data['name'] as String? ?? 'Imported Plan';
      final description = data['description'] as String? ?? '';
      final rawExercises = data['exercises'] as List<dynamic>? ?? const [];
      final exercises = rawExercises
          .map((e) => PlannedExercise.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      final newPlan = WorkoutPlan(
        id: '',
        name: name,
        description: description,
        exercises: exercises,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await createPlan(newPlan);
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to import plan');
    }
  }
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

/// All plans of the signed-in user; empty stream when signed out.
final plansProvider = StreamProvider<List<WorkoutPlan>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(const <WorkoutPlan>[]);
  return ref.watch(planRepositoryProvider).watchPlans();
});
