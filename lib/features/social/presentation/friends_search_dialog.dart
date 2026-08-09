import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/features/social/data/social_repository.dart';

class FriendsSearchDialog extends ConsumerStatefulWidget {
  const FriendsSearchDialog({super.key});

  @override
  ConsumerState<FriendsSearchDialog> createState() => _FriendsSearchDialogState();
}

class _FriendsSearchDialogState extends ConsumerState<FriendsSearchDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final followingAsync = ref.watch(followingProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Find Friends'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading profiles: $err')),
                data: (profiles) {
                  final following = followingAsync.valueOrNull ?? const [];
                  final filtered = profiles.where((p) {
                    final name = p.displayName.toLowerCase();
                    final email = p.email.toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No users found.'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final isFollowing = following.contains(p.uid);

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            p.displayName.isNotEmpty
                                ? p.displayName.substring(0, 1).toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(p.displayName.isNotEmpty ? p.displayName : 'GymGenie Lifter'),
                        subtitle: Text(p.email),
                        trailing: isFollowing
                            ? OutlinedButton(
                                onPressed: () {
                                  ref.read(socialRepositoryProvider).unfollowUser(p.uid);
                                },
                                child: const Text('Unfollow'),
                              )
                            : FilledButton(
                                onPressed: () {
                                  ref.read(socialRepositoryProvider).followUser(p.uid, p.displayName);
                                },
                                child: const Text('Follow'),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
