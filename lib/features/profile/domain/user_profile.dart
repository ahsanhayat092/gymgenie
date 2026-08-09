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
    // ── Generator / survey fields ──────────────────────────────────────────
    this.age = 0,
    this.gender = '',
    this.experience = '',
    this.fitnessGoal = '',
    this.sessionDurationMinutes = 45,
    this.intensityLevel = '',
    this.equipment = const [],
    this.cardioEquipment = const [],
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

  // ── Generator / survey fields ────────────────────────────────────────────
  final int age;                        // 0 = unset
  final String gender;                  // 'Male' | 'Female' | 'Other' | ''
  final String experience;              // 'Beginner' | 'Intermediate' | 'Advanced' | ''
  final String fitnessGoal;             // e.g. 'Build muscle'
  final int sessionDurationMinutes;     // 30 | 45 | 60 | 90
  final String intensityLevel;          // 'Easy' | 'Moderate' | 'Hard' | ''
  final List<String> equipment;         // ['Barbell', 'Dumbbell', ...]
  final List<String> cardioEquipment;   // ['Treadmill', 'Bike', ...]

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
      age: (map['age'] as num?)?.toInt() ?? 0,
      gender: (map['gender'] as String?) ?? '',
      experience: (map['experience'] as String?) ?? '',
      fitnessGoal: (map['fitnessGoal'] as String?) ?? '',
      sessionDurationMinutes: (map['sessionDurationMinutes'] as num?)?.toInt() ?? 45,
      intensityLevel: (map['intensityLevel'] as String?) ?? '',
      equipment: List<String>.from(map['equipment'] as List? ?? const []),
      cardioEquipment: List<String>.from(map['cardioEquipment'] as List? ?? const []),
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
      // ── Generator / survey fields ────────────────────────────────────────────
      if (age > 0) 'age': age,
      if (gender.isNotEmpty) 'gender': gender,
      if (experience.isNotEmpty) 'experience': experience,
      if (fitnessGoal.isNotEmpty) 'fitnessGoal': fitnessGoal,
      'sessionDurationMinutes': sessionDurationMinutes,
      if (intensityLevel.isNotEmpty) 'intensityLevel': intensityLevel,
      if (equipment.isNotEmpty) 'equipment': equipment,
      if (cardioEquipment.isNotEmpty) 'cardioEquipment': cardioEquipment,
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
    int? age,
    String? gender,
    String? experience,
    String? fitnessGoal,
    int? sessionDurationMinutes,
    String? intensityLevel,
    List<String>? equipment,
    List<String>? cardioEquipment,
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
      age: age ?? this.age,
      gender: gender ?? this.gender,
      experience: experience ?? this.experience,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      sessionDurationMinutes: sessionDurationMinutes ?? this.sessionDurationMinutes,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      equipment: equipment ?? this.equipment,
      cardioEquipment: cardioEquipment ?? this.cardioEquipment,
    );
  }
}
