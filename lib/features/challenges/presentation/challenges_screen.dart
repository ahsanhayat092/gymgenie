import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class ChallengeModel {
  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.unit,
    required this.progressCalculator,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final double target;
  final String unit;
  final double Function(List<WorkoutLog> logs) progressCalculator;
}

final challengesList = [
  ChallengeModel(
    id: 'pushup-30',
    title: '30-Day Push-Up Challenge',
    description: 'Log 30 workouts containing any Push-Up variations to build chest and core strength.',
    icon: Icons.fitness_center,
    target: 30,
    unit: 'workouts',
    progressCalculator: (logs) {
      return logs.where((l) {
        return l.exercises.any((e) => e.exerciseName.toLowerCase().contains('push-up') || e.exerciseName.toLowerCase().contains('pushup'));
      }).length.toDouble();
    },
  ),
  ChallengeModel(
    id: 'cardio-100k',
    title: '100km Cardio Streak',
    description: 'Accumulate 100 kilometers of cardio distance across treadmill, cycling, or rowing.',
    icon: Icons.directions_run,
    target: 100,
    unit: 'km',
    progressCalculator: (logs) {
      double total = 0;
      for (final l in logs) {
        for (final ex in l.exercises) {
          if (ex.exerciseName.toLowerCase().contains('cardio')) {
            total += ex.distanceKm ?? 0.0;
          }
        }
      }
      return total;
    },
  ),
  ChallengeModel(
    id: 'sets-1000',
    title: '1000 Sets Club',
    description: 'Complete 1000 total working sets across all resistance training sessions.',
    icon: Icons.emoji_events,
    target: 1000,
    unit: 'sets',
    progressCalculator: (logs) {
      return logs.fold(0, (sum, l) => sum + l.completedSets).toDouble();
    },
  ),
];

final joinedChallengesProvider = StreamProvider<List<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
  if (uid.isEmpty) return Stream.value([]);

  return firestore.collection('users').doc(uid).collection('challenges').snapshots().map(
        (snap) => snap.docs.map((doc) => doc.id).toList(),
      );
});

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  Future<void> _joinChallenge(BuildContext context, WidgetRef ref, String challengeId) async {
    final firestore = ref.read(firestoreProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    await firestore.collection('users').doc(uid).collection('challenges').doc(challengeId).set({
      'joinedAt': Timestamp.now(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined challenge successfully! Start logging workouts.')),
      );
    }
  }

  Future<void> _leaveChallenge(BuildContext context, WidgetRef ref, String challengeId) async {
    final firestore = ref.read(firestoreProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    await firestore.collection('users').doc(uid).collection('challenges').doc(challengeId).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left challenge.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(workoutLogsProvider);
    final joinedAsync = ref.watch(joinedChallengesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Challenges'),
      ),
      body: logsAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          message: 'Failed to load challenges data.',
          onRetry: () => ref.invalidate(workoutLogsProvider),
        ),
        data: (logs) {
          return joinedAsync.when(
            loading: () => const LoadingView(),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (joinedIds) {
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: challengesList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final challenge = challengesList[index];
                  final isJoined = joinedIds.contains(challenge.id);
                  final currentVal = challenge.progressCalculator(logs);
                  final progress = (currentVal / challenge.target).clamp(0.0, 1.0);

                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(challenge.icon, color: theme.colorScheme.primary, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  challenge.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            challenge.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (isJoined) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress: ${currentVal.toStringAsFixed(currentVal == currentVal.round() ? 0 : 1)} / ${challenge.target.round()} ${challenge.unit}',
                                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isJoined)
                                OutlinedButton(
                                  onPressed: () => _leaveChallenge(context, ref, challenge.id),
                                  child: const Text('Leave'),
                                )
                              else
                                FilledButton(
                                  onPressed: () => _joinChallenge(context, ref, challenge.id),
                                  child: const Text('Join Challenge'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
