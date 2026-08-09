import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';

/// List of the user's workout plans with swipe-to-delete and a create FAB.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  Future<void> _confirmAndDelete(
      BuildContext context, WidgetRef ref, WorkoutPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text('This will permanently delete "${plan.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(planRepositoryProvider).deletePlan(plan.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var importing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Import Shared Plan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter the share code or paste the shared URL to import the workout plan.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    enabled: !importing,
                    decoration: const InputDecoration(
                      labelText: 'Share Code or Link',
                      hintText: 'e.g. 5xG8yK...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: importing ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: importing
                      ? null
                      : () async {
                          final value = controller.text.trim();
                          if (value.isEmpty) return;

                          setState(() => importing = true);
                          try {
                            await ref.read(planRepositoryProvider).importPlan(value);
                            if (!context.mounted) return;
                            ref.invalidate(plansProvider);
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Plan imported successfully!')),
                            );
                          } catch (e) {
                            setState(() => importing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  child: importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
        actions: [
          IconButton(
            tooltip: 'Import Shared Plan',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _showImportDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/plans/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: plans.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Failed to load plans',
          onRetry: () => ref.invalidate(plansProvider),
        ),
        data: (planList) {
          if (planList.isEmpty) {
            return EmptyView(
              icon: Icons.list_alt,
              title: 'No plans yet',
              subtitle:
                  'Create your first workout plan to get started.',
              action: FilledButton.icon(
                onPressed: () => context.push('/plans/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create Plan'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: planList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final plan = planList[index];
              return Dismissible(
                key: ValueKey(plan.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                // Deletion happens here and the stream rebuild removes the
                // tile, so the item is never actually dismissed.
                confirmDismiss: (_) async {
                  await _confirmAndDelete(context, ref, plan);
                  return false;
                },
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(plan.name),
                    subtitle: Text(
                      '${plan.exercises.length} exercises • Updated ${formatDate(plan.updatedAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/plans/${plan.id}'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
