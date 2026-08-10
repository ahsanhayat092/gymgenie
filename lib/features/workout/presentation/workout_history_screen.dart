import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, WorkoutLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text(
          'Delete "${log.planName}" from ${formatDate(log.date)}? This cannot be undone.',
        ),
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
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(workoutLogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout History')),
      body: logs.when(
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.history,
              title: 'No workouts yet',
              subtitle: 'Finished workouts will show up here.',
              action: FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            );
          }

          final groups = <_DayGroup>[];
          for (final log in list) {
            final day = DateTime(log.date.year, log.date.month, log.date.day);
            if (groups.isEmpty || groups.last.day != day) {
              groups.add(_DayGroup(day, <WorkoutLog>[log]));
            } else {
              groups.last.logs.add(log);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: groups.fold<int>(
                0, (count, g) => count + 1 + g.logs.length),
            itemBuilder: (context, index) {
              var cursor = 0;
              for (final group in groups) {
                if (index == cursor) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Text(
                      formatDate(group.day),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                cursor++;
                if (index < cursor + group.logs.length) {
                  final log = group.logs[index - cursor];
                  return _HistoryTile(
                    log: log,
                    onConfirmDelete: () => _confirmDelete(context, log),
                  );
                }
                cursor += group.logs.length;
              }
              return const SizedBox.shrink();
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(workoutLogsProvider),
        ),
      ),
    );
  }
}

class _DayGroup {
  _DayGroup(this.day, this.logs);

  final DateTime day;
  final List<WorkoutLog> logs;
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.log, required this.onConfirmDelete});

  final WorkoutLog log;
  final Future<bool> Function() onConfirmDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPending = log.id.startsWith('pending_');

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) async {
        try {
          HapticFeedback.lightImpact();
          await ref.read(logRepositoryProvider).deleteLog(log.id);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.orange
                            : theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.orange.withValues(alpha: 0.15)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPending
                            ? Icons.cloud_off_outlined
                            : Icons.fitness_center_rounded,
                        color: isPending
                            ? Colors.orange
                            : theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  log.planName,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPending) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          Colors.orange.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    'Pending',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${log.durationMinutes} min • ${log.completedSets} sets • ${formatVolume(log.totalVolume)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
