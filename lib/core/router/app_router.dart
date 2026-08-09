import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/auth/presentation/login_screen.dart';
import 'package:gymgenie/features/auth/presentation/signup_screen.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:gymgenie/features/exercises/presentation/exercise_library_screen.dart';
import 'package:gymgenie/features/home/presentation/home_shell.dart';
import 'package:gymgenie/features/home/presentation/home_screen.dart';
import 'package:gymgenie/features/plans/presentation/plan_detail_screen.dart';
import 'package:gymgenie/features/plans/presentation/plan_editor_screen.dart';
import 'package:gymgenie/features/plans/presentation/plans_screen.dart';
import 'package:gymgenie/features/generator/presentation/generator_survey_screen.dart';
import 'package:gymgenie/features/profile/presentation/edit_profile_screen.dart';
import 'package:gymgenie/features/profile/presentation/goals_screen.dart';
import 'package:gymgenie/features/profile/presentation/profile_screen.dart';
import 'package:gymgenie/features/progress/presentation/progress_screen.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';
import 'package:gymgenie/features/workout/presentation/active_workout_screen.dart';
import 'package:gymgenie/features/workout/presentation/workout_history_screen.dart';
import 'package:gymgenie/features/workout/presentation/workout_summary_screen.dart';

/// Root [GoRouter] with auth-based redirects and a bottom-navigation
/// [StatefulShellRoute] for the five main tabs.
final routerProvider = Provider<GoRouter>((ref) {
  // Refresh the router whenever the auth state changes so the redirect
  // logic re-evaluates (login / logout).
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
      // While the first auth event has not arrived yet, keep the current
      // route to avoid bouncing an already signed-in user to /login.
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

      // Main tab shell (bottom navigation).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (context, state) => const ExerciseLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plans',
                builder: (context, state) => const PlansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes outside the shell.
      GoRoute(
        path: '/exercises/detail',
        builder: (context, state) =>
            ExerciseDetailScreen(exercise: state.extra as Exercise),
      ),
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
      GoRoute(
        path: '/workout/active',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/workout/summary',
        builder: (context, state) =>
            WorkoutSummaryScreen(log: state.extra as WorkoutLog),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),
    ],
  );
});
