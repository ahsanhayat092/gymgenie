import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's profile, stored at users/{uid} (§4).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.heightCm,
    required this.weightKg,
    required this.weeklyWorkoutGoal,
    required this.createdAt,
    this.restTimerEnabled = false,
    this.restTimerDuration = 90,
  });

  final String uid;
  final String displayName;
  final String email;
  final double heightCm; // 0 = unset
  final double weightKg; // 0 = unset
  final int weeklyWorkoutGoal; // 1..14, default 3
  final DateTime createdAt;
  final bool restTimerEnabled;
  final int restTimerDuration; // in seconds

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      uid: id,
      displayName: (map['displayName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      weeklyWorkoutGoal: (map['weeklyWorkoutGoal'] as num?)?.toInt() ?? 3,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      restTimerEnabled: (map['restTimerEnabled'] as bool?) ?? false,
      restTimerDuration: (map['restTimerDuration'] as num?)?.toInt() ?? 90,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'displayName': displayName,
      'email': email,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'weeklyWorkoutGoal': weeklyWorkoutGoal,
      'createdAt': Timestamp.fromDate(createdAt),
      'restTimerEnabled': restTimerEnabled,
      'restTimerDuration': restTimerDuration,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    double? heightCm,
    double? weightKg,
    int? weeklyWorkoutGoal,
    DateTime? createdAt,
    bool? restTimerEnabled,
    int? restTimerDuration,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      weeklyWorkoutGoal: weeklyWorkoutGoal ?? this.weeklyWorkoutGoal,
      createdAt: createdAt ?? this.createdAt,
      restTimerEnabled: restTimerEnabled ?? this.restTimerEnabled,
      restTimerDuration: restTimerDuration ?? this.restTimerDuration,
    );
  }
}
