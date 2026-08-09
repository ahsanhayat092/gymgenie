import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _searchQuery = '';
  final Map<String, bool> _importingIds = {};

  Future<void> _importPlan(String sharedPlanId, String planName) async {
    setState(() => _importingIds[sharedPlanId] = true);
    try {
      await ref.read(planRepositoryProvider).importPlan(sharedPlanId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$planName" imported successfully! Check your plans.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _importingIds[sharedPlanId] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharedPlansAsync = ref.watch(sharedPlansProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Marketplace'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search trending plans or splits...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: sharedPlansAsync.when(
              loading: () => const LoadingView(),
              error: (err, _) => EmptyView(
                icon: Icons.store_mall_directory_outlined,
                title: 'Marketplace is empty',
                subtitle: 'No shared plans yet. Share your first plan from your library to inspire others.',
              ),
              data: (plansList) {
                final filtered = plansList.where((plan) {
                  final name = (plan['name'] as String? ?? '').toLowerCase();
                  final desc = (plan['description'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) || desc.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Marketplace is empty',
                    subtitle: 'No shared plans yet. Share your first plan from your library to inspire others.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = filtered[index];
                    final planId = plan['id'] as String;
                    final name = plan['name'] as String? ?? 'Workout';
                    final desc = plan['description'] as String? ?? '';
                    final exercisesCount = (plan['exercises'] as List<dynamic>?)?.length ?? 0;
                    final isImporting = _importingIds[planId] ?? false;

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
                                Expanded(
                                  child: Text(
                                    name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$exercisesCount Ex',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                desc,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: isImporting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    )
                                  : FilledButton.icon(
                                      onPressed: () => _importPlan(planId, name),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Import Split'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
