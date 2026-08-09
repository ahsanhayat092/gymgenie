import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/exercises/data/exercise_repository.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';

enum BalanceMetric { sets, volume }

class MuscleGroupBalanceChart extends ConsumerStatefulWidget {
  const MuscleGroupBalanceChart({super.key});

  @override
  ConsumerState<MuscleGroupBalanceChart> createState() =>
      _MuscleGroupBalanceChartState();
}

class _MuscleGroupBalanceChartState
    extends ConsumerState<MuscleGroupBalanceChart> {
  BalanceMetric _metric = BalanceMetric.sets;
  int _touchedIndex = -1;

  final Map<String, Color> _muscleGroupColors = const {
    'Chest': Color(0xFFE57373),
    'Back': Color(0xFF64B5F6),
    'Legs': Color(0xFFFFB74D),
    'Shoulders': Color(0xFFBA68C8),
    'Arms': Color(0xFF81C784),
    'Core': Color(0xFF4DB6AC),
    'Cardio': Color(0xFFF06292),
    'Other': Color(0xFFA0A0A0),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(workoutLogsProvider);
    final exercisesAsync = ref.watch(exerciseLibraryProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Muscle Group Balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.donut_large_outlined,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Weekly training distribution across target muscle groups.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Toggle buttons
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Sets Completed'),
                  selected: _metric == BalanceMetric.sets,
                  onSelected: (selected) {
                    if (selected) setState(() => _metric = BalanceMetric.sets);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Weight Volume (kg)'),
                  selected: _metric == BalanceMetric.volume,
                  onSelected: (selected) {
                    if (selected) setState(() => _metric = BalanceMetric.volume);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            logsAsync.when(
              data: (logs) => exercisesAsync.when(
                data: (exercises) {
                  // Map of exerciseId -> muscleGroup
                  final exerciseToMuscleGroup = {
                    for (final e in exercises) e.id: e.muscleGroup
                  };

                  // Filter logs from the last 7 days
                  final now = DateTime.now();
                  final sevenDaysAgo = now.subtract(const Duration(days: 7));
                  final recentLogs = logs.where((log) => log.date.isAfter(sevenDaysAgo)).toList();

                  // Aggregate values per muscle group
                  final data = <String, double>{};
                  double total = 0;

                  for (final log in recentLogs) {
                    for (final exerciseLog in log.exercises) {
                      final group = exerciseToMuscleGroup[exerciseLog.exerciseId] ?? 'Other';
                      
                      double val = 0.0;
                      if (_metric == BalanceMetric.sets) {
                        val = exerciseLog.sets.where((s) => s.completed).length.toDouble();
                      } else {
                        val = exerciseLog.volume;
                      }

                      if (val > 0) {
                        data[group] = (data[group] ?? 0.0) + val;
                        total += val;
                      }
                    }
                  }

                  if (data.isEmpty || total == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.pie_chart_outline_outlined,
                              size: 40,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No workouts logged in the last 7 days.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Complete sessions to view muscle group distribution.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final sections = <PieChartSectionData>[];
                  final items = data.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  for (var i = 0; i < items.length; i++) {
                    final entry = items[i];
                    final isTouched = i == _touchedIndex;
                    final pct = (entry.value / total) * 100;
                    final color = _muscleGroupColors[entry.key] ??
                        _muscleGroupColors['Other']!;

                    sections.add(
                      PieChartSectionData(
                        color: color,
                        value: entry.value,
                        title: isTouched
                            ? '${entry.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)'
                            : '${pct.toStringAsFixed(0)}%',
                        radius: isTouched ? 55 : 45,
                        titleStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: isTouched ? 12 : 10,
                        ),
                        badgeWidget: isTouched
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  entry.key,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        badgePositionPercentageOffset: 1.1,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (event, touchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      touchResponse == null ||
                                      touchResponse.touchedSection == null) {
                                    _touchedIndex = -1;
                                    return;
                                  }
                                  _touchedIndex = touchResponse
                                      .touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            sections: sections,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Custom Legend wrap
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: items.map((entry) {
                          final color = _muscleGroupColors[entry.key] ??
                              _muscleGroupColors['Other']!;
                          final valStr = _metric == BalanceMetric.sets
                              ? '${entry.value.toStringAsFixed(0)} sets'
                              : '${entry.value.toStringAsFixed(0)} kg';
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${entry.key}: $valStr',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ],
        ),
      ),
    );
  }
}
