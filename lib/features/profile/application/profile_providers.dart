import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/profile/data/profile_repository.dart';

/// Watches the current user's profile and emits whether onboarding is complete.
///
/// Returns `false` when the user is signed out or no profile exists, so the
/// router can safely redirect to the onboarding flow.
final onboardingCompleteProvider = StreamProvider<bool>((ref) {
  final profileStream = ref.watch(userProfileProvider.stream);
  return profileStream.map((profile) => profile?.onboardingComplete ?? false);
});
