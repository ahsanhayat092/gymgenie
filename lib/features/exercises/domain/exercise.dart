/// An exercise from the bundled exercise library (assets/exercises.json).
///
/// Loaded from a local asset, NOT from Firestore — hence `fromJson` only.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.difficulty,
    required this.instructions,
    required this.gifUrl,
  });

  /// Slug, e.g. 'barbell-bench-press'.
  final String id;

  /// Display name, e.g. 'Barbell Bench Press'.
  final String name;

  /// One of: Chest, Back, Shoulders, Legs, Arms, Core.
  final String muscleGroup;

  /// Barbell | Dumbbell | Machine | Cable | Bodyweight | Kettlebell | Other.
  final String equipment;

  /// Beginner | Intermediate | Advanced.
  final String difficulty;

  /// 2-4 sentences of guidance.
  final String instructions;

  /// URL of the animated demonstration GIF.
  final String gifUrl;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      gifUrl: json['gifUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'difficulty': difficulty,
      'instructions': instructions,
      'gifUrl': gifUrl,
    };
  }
}
