import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/auth/presentation/login_screen.dart';
import 'package:gymgenie/features/auth/presentation/signup_screen.dart';
import 'package:gymgenie/features/challenges/presentation/challenges_screen.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:gymgenie/features/exercises/presentation/exercise_library_screen.dart';
import 'package:gymgenie/features/home/presentation/home_shell.dart';
import 'package:gymgenie/features/home/presentation/home_screen.dart';
import 'package:gymgenie/features/marketplace/presentation/marketplace_screen.dart';
import 'package:gymgenie/features/more/presentation/more_screen.dart';
import 'package:gymgenie/features/plans/presentation/plan_detail_screen.dart';
import 'package:gymgenie/features/plans/presentation/plan_editor_screen.dart';
import 'package:gymgenie/features/plans/presentation/plans_screen.dart';
import 'package:gymgenie/features/generator/presentation/generator_survey_screen.dart';
import 'package:gymgenie/features/profile/presentation/edit_profile_screen.dart';
import 'package:gymgenie/features/profile/presentation/goals_screen.dart';
import 'package:gymgenie/features/profile/presentation/profile_screen.dart';
import 'package:gymgenie/features/progress/presentation/progress_screen.dart';
import 'package:gymgenie/features/social/presentation/community_hub_screen.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';
import 'package:gymgenie/features/workout/presentation/active_workout_screen.dart';
import 'package:gymgenie/features/workout/presentation/workout_history_screen.dart';
import 'package:gymgenie/features/workout/presentation/workout_summary_screen.dart';

/// Root [GoRouter] with auth-based redirects and a bottom-navigation
/// [StatefulShellRoute] for the five main tabs:
///   Home | Exercises | Plans | Progress | More
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref
    ..onDispose(refreshNotifier.dispose)
    ..listen(authStateProvider, (previous, next) {
      refreshNotifier.value++;
    });

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/signup';

      if (user == null && !onAuthPage) return '/login';
      if (user != null && onAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // ── Bottom navigation shell — exactly 5 tabs ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 1 — Exercises
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (context, state) => const ExerciseLibraryScreen(),
              ),
            ],
          ),

          // Tab 2 — Plans
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plans',
                builder: (context, state) => const PlansScreen(),
              ),
            ],
          ),

          // Tab 3 — Progress
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),

          // Tab 4 — More  (hub for Profile, Community, Marketplace, History, Goals)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (push on top of shell) ───────────────────────

      // Exercises
      GoRoute(
        path: '/exercises/detail',
        builder: (context, state) =>
            ExerciseDetailScreen(exercise: state.extra as Exercise),
      ),

      // Plans
      GoRoute(
        path: '/plans/new',
        builder: (context, state) => const PlanEditorScreen(),
      ),
      GoRoute(
        path: '/plans/generate',
        builder: (context, state) => const GeneratorSurveyScreen(),
      ),
      GoRoute(
        path: '/plans/:id',
        builder: (context, state) =>
            PlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/plans/:id/edit',
        builder: (context, state) =>
            PlanEditorScreen(planId: state.pathParameters['id']!),
      ),

      // Workout
      GoRoute(
        path: '/workout/active',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/workout/summary',
        builder: (context, state) =>
            WorkoutSummaryScreen(log: state.extra as WorkoutLog),
      ),

      // Profile sub-screens (pushed from MoreScreen)
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/goals',
        builder: (context, state) => const GoalsScreen(),
      ),

      // History (pushed from MoreScreen or profile)
      GoRoute(
        path: '/history',
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),

      // Community (pushed from MoreScreen)
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityHubScreen(),
      ),

      // Marketplace (pushed from MoreScreen)
      GoRoute(
        path: '/marketplace',
        builder: (context, state) => const MarketplaceScreen(),
      ),

      // Challenges (pushed from MoreScreen)
      GoRoute(
        path: '/challenges',
        builder: (context, state) => const ChallengesScreen(),
      ),
    ],
  );
});
