import 'package:flutter/material.dart';
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
            'Delete "${log.planName}" from ${formatDate(log.date)}? This cannot be undone.'),
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
          // Logs arrive newest-first; group them by calendar day.
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
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      formatDate(group.day),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
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
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) async {
        try {
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
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.fitness_center),
          title: Text(log.planName),
          subtitle: Text(
            '${log.durationMinutes} min • ${log.completedSets} sets',
          ),
          trailing: Text(formatVolume(log.totalVolume)),
        ),
      ),
    );
  }
}
