import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:gymgenie/features/profile/domain/user_profile.dart';

/// Handles Firebase Auth and the users/{uid} profile document (§5).
class AuthRepository {
  AuthRepository(this._auth, this._firestore, this._googleSignIn);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates the account, sets the FirebaseAuth displayName and creates the
  /// users/{uid} profile document per the UserProfile model.
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    final user = credential.user;
    if (user != null) {
      final profile = UserProfile(
        uid: user.uid,
        displayName: displayName,
        email: email,
        heightCm: 0,
        weightKg: 0,
        weeklyWorkoutGoal: 3,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    }
    return credential;
  }

  /// Google sign-in flow (google_sign_in ^6.2.1). Creates the users/{uid}
  /// profile document when it does not exist yet.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      final doc = _firestore.collection('users').doc(user.uid);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        final profile = UserProfile(
          uid: user.uid,
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          heightCm: 0,
          weightKg: 0,
          weeklyWorkoutGoal: 3,
          createdAt: DateTime.now(),
        );
        await doc.set(profile.toMap());
      }
    }
    return userCredential;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Maps FirebaseAuthException codes (and common errors) to friendly
  /// English messages.
  String describeAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for that email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists for that email address.';
        case 'weak-password':
          return 'That password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'invalid-credential':
          return 'Invalid credentials. Check your email and password.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
    if (e is StateError) {
      return e.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
