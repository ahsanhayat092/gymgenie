import 'package:flutter/material.dart';
import 'package:gymgenie/features/challenges/presentation/challenges_screen.dart';
import 'package:gymgenie/features/social/presentation/social_feed_screen.dart';

class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: const TabBarView(
          children: [
            SocialFeedScreen(),
            ChallengesScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'Feed'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Challenges'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
      ),
    );
  }
}
