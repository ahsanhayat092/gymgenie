import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/workout/data/local_log_store.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

/// User-scoped repository for workout logs and body weight entries.
/// This is the ONLY place Firestore is touched for these collections.
class LogRepository {
  LogRepository(this._firestore, this._auth, this._localStore);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocalLogStore _localStore;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection('users').doc(_uid).collection('logs');

  CollectionReference<Map<String, dynamic>> get _bodyWeights =>
      _firestore.collection('users').doc(_uid).collection('bodyWeights');

  /// Newest first.
  Stream<List<WorkoutLog>> watchLogs() {
    try {
      return _logs.orderBy('date', descending: true).snapshots().map(
            (snap) => snap.docs
                .map((doc) => WorkoutLog.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } on FirebaseException catch (e) {
      throw StateError('Could not load workout logs: ${e.message ?? e.code}');
    }
  }

  Future<String> addLog(WorkoutLog log) async {
    try {
      final doc = await _logs.add(log.toMap());
      return doc.id;
    } on FirebaseException catch (e) {
      throw StateError('Could not save workout: ${e.message ?? e.code}');
    }
  }

  /// Retries any logs stored locally because the device was offline.
  /// Successful logs are marked synced and cleaned up.
  Future<void> syncPendingLogs() async {
    if (_auth.currentUser == null) return;
    final pending = await _localStore.pendingLogs();
    for (final entry in pending) {
      try {
        final firestoreId = await addLog(entry.log);
        await _localStore.markSynced(entry.localId, firestoreId);
      } catch (_) {
        // Still offline or Firestore error; leave it for the next retry.
      }
    }
    await _localStore.deleteSynced();
  }

  Future<void> deleteLog(String id) async {
    if (id.startsWith('pending_')) {
      final localId = int.tryParse(id.replaceFirst('pending_', ''));
      if (localId != null) {
        await _localStore.deletePendingLog(localId);
      }
      return;
    }
    try {
      await _logs.doc(id).delete();
    } on FirebaseException catch (e) {
      throw StateError('Could not delete workout: ${e.message ?? e.code}');
    }
  }

  /// Oldest first.
  Stream<List<BodyWeightEntry>> watchBodyWeights() {
    try {
      return _bodyWeights.orderBy('date', descending: false).snapshots().map(
            (snap) => snap.docs
                .map((doc) => BodyWeightEntry.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } on FirebaseException catch (e) {
      throw StateError('Could not load body weights: ${e.message ?? e.code}');
    }
  }

  Future<void> addBodyWeight(double weightKg, DateTime date) async {
    try {
      final entry = BodyWeightEntry(id: '', date: date, weightKg: weightKg);
      await _bodyWeights.add(entry.toMap());
    } on FirebaseException catch (e) {
      throw StateError('Could not save body weight: ${e.message ?? e.code}');
    }
  }

  Future<void> deleteBodyWeight(String id) async {
    try {
      await _bodyWeights.doc(id).delete();
    } on FirebaseException catch (e) {
      throw StateError('Could not delete body weight: ${e.message ?? e.code}');
    }
  }
}

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
    ref.watch(localLogStoreProvider),
  );
});

/// Merges Firestore logs with any locally queued offline logs.
final workoutLogsProvider = StreamProvider<List<WorkoutLog>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(const <WorkoutLog>[]);

  final localStore = ref.watch(localLogStoreProvider);
  final firestoreLogs = ref.watch(logRepositoryProvider).watchLogs();

  return firestoreLogs.asyncMap((logs) async {
    final pending = await localStore.pendingLogs();
    final combined = [...pending.map((e) => e.log), ...logs];
    combined.sort((a, b) => b.date.compareTo(a.date));
    return combined;
  });
});

final bodyWeightsProvider = StreamProvider<List<BodyWeightEntry>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(const <BodyWeightEntry>[]);
  return ref.watch(logRepositoryProvider).watchBodyWeights();
});
