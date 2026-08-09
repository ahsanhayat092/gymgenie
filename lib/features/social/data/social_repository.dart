import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/profile/domain/user_profile.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class SocialFeedItem {
  SocialFeedItem({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.planName,
    required this.date,
    required this.durationMinutes,
    required this.completedSets,
    required this.totalVolume,
    required this.kudosUids,
    required this.comments,
  });

  final String id;
  final String uid;
  final String displayName;
  final String planName;
  final DateTime date;
  final int durationMinutes;
  final int completedSets;
  final double totalVolume;
  final List<String> kudosUids;
  final List<Map<String, dynamic>> comments; // {uid, name, text, date}

  factory SocialFeedItem.fromMap(Map<String, dynamic> map, String id) {
    return SocialFeedItem(
      id: id,
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Athlete',
      planName: map['planName'] as String? ?? 'Workout',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      completedSets: (map['completedSets'] as num?)?.toInt() ?? 0,
      totalVolume: (map['totalVolume'] as num?)?.toDouble() ?? 0.0,
      kudosUids: List<String>.from(map['kudosUids'] ?? const []),
      comments: List<Map<String, dynamic>>.from(
        (map['comments'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'planName': planName,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'completedSets': completedSets,
      'totalVolume': totalVolume,
      'kudosUids': kudosUids,
      'comments': comments,
    };
  }
}

class SocialRepository {
  SocialRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _feed => _firestore.collection('social_feed');
  CollectionReference<Map<String, dynamic>> get _following =>
      _firestore.collection('users').doc(_uid).collection('following');

  /// Follow a friend
  Future<void> followUser(String targetUid, String targetName) async {
    await _following.doc(targetUid).set({
      'uid': targetUid,
      'displayName': targetName,
      'followedAt': Timestamp.now(),
    });
  }

  /// Unfollow a friend
  Future<void> unfollowUser(String targetUid) async {
    await _following.doc(targetUid).delete();
  }

  /// Watch following uids
  Stream<List<String>> watchFollowingUids() {
    return _following.snapshots().map(
          (snap) => snap.docs.map((doc) => doc.id).toList(),
        );
  }

  /// Watch all public profiles for friends search
  Stream<List<UserProfile>> watchAllProfiles() {
    return _firestore.collection('users').snapshots().map(
          (snap) => snap.docs
              .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
              .where((profile) => profile.uid != _uid)
              .toList(),
        );
  }

  /// Post a completed workout log to the global/friends feed
  Future<void> postToFeed(WorkoutLog log, UserProfile? profile) async {
    final item = SocialFeedItem(
      id: '',
      uid: _uid,
      displayName: profile?.displayName ?? 'Athlete',
      planName: log.planName,
      date: log.date,
      durationMinutes: log.durationMinutes,
      completedSets: log.completedSets,
      totalVolume: log.totalVolume,
      kudosUids: const [],
      comments: const [],
    );
    await _feed.add(item.toMap());
  }

  /// Watch workouts feed items
  Stream<List<SocialFeedItem>> watchFeed() {
    return _feed.orderBy('date', descending: true).snapshots().map(
          (snap) => snap.docs.map((doc) => SocialFeedItem.fromMap(doc.data(), doc.id)).toList(),
        );
  }

  /// Give/remove Kudos
  Future<void> toggleKudos(String feedId, List<String> currentKudos) async {
    final list = List<String>.of(currentKudos);
    if (list.contains(_uid)) {
      list.remove(_uid);
    } else {
      list.add(_uid);
    }
    await _feed.doc(feedId).update({'kudosUids': list});
  }

  /// Add comment
  Future<void> addComment(String feedId, List<Map<String, dynamic>> currentComments, String name, String text) async {
    final list = List<Map<String, dynamic>>.of(currentComments);
    list.add({
      'uid': _uid,
      'name': name,
      'text': text,
      'date': Timestamp.now().toDate().toIso8601String(),
    });
    await _feed.doc(feedId).update({'comments': list});
  }
}

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final followingProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(socialRepositoryProvider).watchFollowingUids();
});

final feedProvider = StreamProvider<List<SocialFeedItem>>((ref) {
  return ref.watch(socialRepositoryProvider).watchFeed();
});

final allProfilesProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(socialRepositoryProvider).watchAllProfiles();
});
