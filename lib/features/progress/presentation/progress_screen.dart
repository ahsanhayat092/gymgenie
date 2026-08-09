import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:gymgenie/core/utils/formatters.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Total volume per ISO week for the last [count] weeks, oldest first.
  static List<_WeekVolume> _weeklyVolumes(
      List<WorkoutLog> logs, int count) {
    final now = DateTime.now();
    final currentStart = _weekStart(now);
    final weeks = <_WeekVolume>[
      for (var i = count - 1; i >= 0; i--)
        _WeekVolume(currentStart.subtract(Duration(days: 7 * i)), 0.0),
    ];
    final oldest = weeks.first.start;
    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (day.isBefore(oldest)) continue;
      final index = day.difference(oldest).inDays ~/ 7;
      if (index >= 0 && index < weeks.length) {
        weeks[index] = _WeekVolume(
            weeks[index].start, weeks[index].volume + log.totalVolume);
      }
    }
    return weeks;
  }

  /// Top [limit] heaviest completed sets, one record per exercise name.
  static List<_PersonalRecord> _personalRecords(List<WorkoutLog> logs,
      {int limit = 5}) {
    final bestByName = <String, _PersonalRecord>{};
    for (final log in logs) {
      for (final exercise in log.exercises) {
        for (final set in exercise.sets) {
          if (!set.completed) continue;
          final current = bestByName[exercise.exerciseName];
          if (current == null || set.weight > current.weight) {
            bestByName[exercise.exerciseName] = _PersonalRecord(
              exerciseName: exercise.exerciseName,
              weight: set.weight,
              reps: set.reps,
              date: log.date,
            );
          }
        }
      }
    }
    final records = bestByName.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return records.take(limit).toList();
  }

  Future<void> _showLogWeightDialog(
      BuildContext context, WidgetRef ref) async {
    final weightController = TextEditingController();
    // Capture the repository BEFORE entering the dialog's async gaps.
    final logRepository = ref.read(logRepositoryProvider);
    var selectedDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Log body weight'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'e.g. 75.5',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDate(selectedDate),
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Change date'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final weight =
                        double.tryParse(weightController.text.trim());
                    if (weight == null || weight <= 0) return;
                    try {
                      await logRepository.addBodyWeight(
                          weight, selectedDate);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    weightController.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body weight saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(workoutLogsProvider);
    final bodyWeights = ref.watch(bodyWeightsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: SafeArea(
        child: logs.when(
          data: (logList) => bodyWeights.when(
            data: (weightEntries) {
              final thisWeekStart = _weekStart(DateTime.now());
              final thisWeekLogs = logList.where((log) {
                final day =
                    DateTime(log.date.year, log.date.month, log.date.day);
                return !day.isBefore(thisWeekStart);
              }).toList();
              final weekVolume = thisWeekLogs.fold<double>(
                  0.0, (sum, log) => sum + log.totalVolume);
              final weekSets = thisWeekLogs.fold<int>(
                  0, (sum, log) => sum + log.completedSets);
              final weeklyVolumes = _weeklyVolumes(logList, 8);
              final records = _personalRecords(logList);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This week', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatTile(
                          label: 'Workouts',
                          value: '${thisWeekLogs.length}',
                        ),
                        const SizedBox(width: 12),
                        _StatTile(
                          label: 'Volume',
                          value: formatVolume(weekVolume),
                        ),
                        const SizedBox(width: 12),
                        _StatTile(label: 'Sets', value: '$weekSets'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Weekly volume (last 8 weeks)',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
                        child: SizedBox(
                          height: 200,
                          child: _WeeklyVolumeChart(weeks: weeklyVolumes),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Body weight',
                              style: theme.textTheme.titleMedium),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _showLogWeightDialog(context, ref),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 8),
                              Text('Log weight'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
                        child: weightEntries.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 24),
                                child: Center(
                                  child: Text(
                                      'No body weight entries yet. Log your first one!'),
                                ),
                              )
                            : SizedBox(
                                height: 180,
                                child: _BodyWeightChart(
                                    entries: weightEntries),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Personal records',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (records.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Complete sets during workouts to set records.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < records.length; i++)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${i + 1}'),
                            ),
                            title: Text(records[i].exerciseName),
                            subtitle: Text(
                              '${records[i].weight} kg × ${records[i].reps} reps '
                              '• ${formatDate(records[i].date)}',
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(bodyWeightsProvider),
            ),
          ),
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(workoutLogsProvider),
          ),
        ),
      ),
    );
  }
}

class _WeekVolume {
  const _WeekVolume(this.start, this.volume);

  final DateTime start;
  final double volume;
}

class _PersonalRecord {
  const _PersonalRecord({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
  });

  final String exerciseName;
  final double weight;
  final int reps;
  final DateTime date;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.weeks});

  final List<_WeekVolume> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVolume =
        weeks.fold<double>(0.0, (m, w) => w.volume > m ? w.volume : m);

    return BarChart(
      BarChartData(
        maxY: maxVolume == 0 ? 1 : maxVolume * 1.15,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= weeks.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(weeks[index].start),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weeks.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weeks[i].volume,
                  color: theme.colorScheme.primary,
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  const _BodyWeightChart({required this.entries});

  final List<BodyWeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<BodyWeightEntry>.of(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final weights = sorted.map((e) => e.weightKg);
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final span = (maxWeight - minWeight).abs();
    final padding = span == 0 ? 1.0 : span * 0.25;

    final spots = <FlSpot>[
      for (var i = 0; i < sorted.length; i++)
        FlSpot(i.toDouble(), sorted[i].weightKg),
    ];

    return LineChart(
      LineChartData(
        minY: minWeight - padding,
        maxY: maxWeight + padding,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                final showEvery =
                    (sorted.length / 4).ceil().clamp(1, sorted.length).toInt();
                if (index < 0 ||
                    index >= sorted.length ||
                    index % showEvery != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(sorted[index].date),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.secondary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.secondary.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
