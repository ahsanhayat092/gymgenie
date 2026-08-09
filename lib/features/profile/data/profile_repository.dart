import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/profile/domain/user_profile.dart';

/// Reads and writes the users/{uid} profile document (§5).
class ProfileRepository {
  ProfileRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _profileDoc =>
      _firestore.collection('users').doc(_uid);

  Stream<UserProfile?> watchProfile() {
    return _profileDoc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromMap(data, snapshot.id);
    });
  }

  Future<UserProfile?> getProfile() async {
    final snapshot = await _profileDoc.get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromMap(data, snapshot.id);
  }

  Future<void> saveProfile(UserProfile profile) {
    return _profileDoc.set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> updateGoals({required int weeklyWorkoutGoal}) {
    return _profileDoc
        .set(<String, dynamic>{'weeklyWorkoutGoal': weeklyWorkoutGoal},
            SetOptions(merge: true));
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile();
});
