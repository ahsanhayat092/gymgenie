import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gymgenie/features/auth/application/auth_providers.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider);

    final displayName = profileAsync.valueOrNull?.displayName ?? '';
    final email = profileAsync.valueOrNull?.email ?? '';
    final initials = _initials(displayName, email);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Profile header card ──────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16, top: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/profile'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        initials,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty ? 'GymGenie User' : displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),

          // ── Account ──────────────────────────────────────────────────────
          _SectionHeader(label: 'ACCOUNT'),
          _MenuTile(
            icon: Icons.person_outline,
            label: 'Profile & Account',
            subtitle: 'Edit name, height, weight, email',
            onTap: () => context.push('/profile'),
          ),
          _MenuTile(
            icon: Icons.flag_outlined,
            label: 'Goals',
            subtitle: 'Set weekly workout targets',
            onTap: () => context.push('/profile/goals'),
          ),
          _MenuTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            subtitle: 'Update personal details',
            onTap: () => context.push('/profile/edit'),
          ),

          const SizedBox(height: 8),

          // ── Activity ─────────────────────────────────────────────────────
          _SectionHeader(label: 'ACTIVITY'),
          _MenuTile(
            icon: Icons.history,
            label: 'Workout History',
            subtitle: 'Browse all past sessions',
            onTap: () => context.push('/history'),
          ),

          const SizedBox(height: 8),

          // ── Community ─────────────────────────────────────────────────────
          _SectionHeader(label: 'COMMUNITY'),
          _MenuTile(
            icon: Icons.people_outline,
            label: 'Community Feed',
            subtitle: 'Follow friends and see their workouts',
            onTap: () => context.push('/community'),
          ),
          _MenuTile(
            icon: Icons.store_mall_directory_outlined,
            label: 'Plan Marketplace',
            subtitle: 'Discover and import shared workout plans',
            onTap: () => context.push('/marketplace'),
          ),
          _MenuTile(
            icon: Icons.emoji_events_outlined,
            label: 'Challenges',
            subtitle: 'Join community fitness challenges',
            onTap: () => context.push('/challenges'),
          ),

          const SizedBox(height: 8),

          // ── Settings ──────────────────────────────────────────────────────
          _SectionHeader(label: 'SETTINGS'),
          _MenuTile(
            icon: Icons.timer_outlined,
            label: 'Rest Timer',
            subtitle: 'Configure active workout rest timer',
            onTap: () => context.push('/profile'),
          ),

          const SizedBox(height: 24),

          // ── Sign Out ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _initials(String name, String email) {
    if (name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts
          .where((p) => p.isNotEmpty)
          .take(2)
          .map((p) => p[0].toUpperCase())
          .join();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
