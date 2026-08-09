import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/social/data/social_repository.dart';
import 'package:gymgenie/features/social/presentation/friends_search_dialog.dart';

class SocialFeedScreen extends ConsumerWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final followingAsync = ref.watch(followingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        actions: [
          IconButton(
            tooltip: 'Find Friends',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => const FriendsSearchDialog(),
              );
            },
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => EmptyView(
          icon: Icons.people_outline,
          title: 'Community feed is quiet',
          subtitle: 'No posts yet. Finish a workout to share your progress and follow friends to see theirs!',
          action: FilledButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => const FriendsSearchDialog(),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Find Friends'),
          ),
        ),
        data: (feedItems) {
          final followingUids = followingAsync.valueOrNull ?? const [];
          final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

          // Show feed items from people you follow, plus your own!
          final filteredItems = feedItems.where((item) {
            return item.uid == myUid || followingUids.contains(item.uid);
          }).toList();

          if (filteredItems.isEmpty) {
            return EmptyView(
              icon: Icons.people_outline,
              title: 'Feed is empty',
              subtitle: 'Follow friends or log your first workout to see updates here!',
              action: FilledButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => const FriendsSearchDialog(),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Find Friends'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return _FeedItemCard(item: item, myUid: myUid);
            },
          );
        },
      ),
    );
  }
}

class _FeedItemCard extends ConsumerStatefulWidget {
  const _FeedItemCard({required this.item, required this.myUid});

  final SocialFeedItem item;
  final String myUid;

  @override
  ConsumerState<_FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends ConsumerState<_FeedItemCard> {
  bool _showComments = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    final name = profile?.displayName ?? 'Athlete';

    ref.read(socialRepositoryProvider).addComment(
          widget.item.id,
          widget.item.comments,
          name,
          text,
        );

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKudos = widget.item.kudosUids.contains(widget.myUid);

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
            // User Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    widget.item.displayName.isNotEmpty
                        ? widget.item.displayName.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formatDate(widget.item.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Workout details
            Text(
              widget.item.planName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Stats Row
            Row(
              children: [
                _StatCell(
                  label: 'Duration',
                  value: '${widget.item.durationMinutes}m',
                ),
                const SizedBox(width: 24),
                _StatCell(
                  label: 'Sets Completed',
                  value: '${widget.item.completedSets}',
                ),
                if (widget.item.totalVolume > 0) ...[
                  const SizedBox(width: 24),
                  _StatCell(
                    label: 'Volume',
                    value: formatVolume(widget.item.totalVolume),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Actions
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    hasKudos ? Icons.favorite : Icons.favorite_border,
                    color: hasKudos ? Colors.red : null,
                  ),
                  onPressed: () {
                    ref.read(socialRepositoryProvider).toggleKudos(
                          widget.item.id,
                          widget.item.kudosUids,
                        );
                  },
                ),
                Text(
                  '${widget.item.kudosUids.length} Kudos',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () {
                    setState(() => _showComments = !_showComments);
                  },
                ),
                Text(
                  '${widget.item.comments.length} Comments',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            if (_showComments) ...[
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Comment items list
              if (widget.item.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No comments yet. Be the first to cheer them on!'),
                )
              else
                for (final c in widget.item.comments) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: '${c['name'] ?? 'Lifter'}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: c['text'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                ],
              const SizedBox(height: 12),
              // Add comment input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
