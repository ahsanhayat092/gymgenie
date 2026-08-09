import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

enum StrengthMetric { oneRepMax, heaviestSet, volume }
enum CardioMetric { duration, distance, resistance }

class ExerciseProgressionChart extends ConsumerStatefulWidget {
  const ExerciseProgressionChart({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<ExerciseProgressionChart> createState() =>
      _ExerciseProgressionChartState();
}

class _ExerciseProgressionChartState
    extends ConsumerState<ExerciseProgressionChart> {
  StrengthMetric _strengthMetric = StrengthMetric.oneRepMax;
  CardioMetric _cardioMetric = CardioMetric.duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(workoutLogsProvider);

    final isCardio = widget.exercise.muscleGroup.toLowerCase() == 'cardio';

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
                  'Progression',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.show_chart,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 12),
            logsAsync.when(
              data: (logs) {
                // Find all exercise logs matching this exercise, sorted chronologically (oldest first).
                final points = <_DataPoint>[];
                for (final log in logs) {
                  final exerciseLog = log.exercises.firstWhere(
                    (e) => e.exerciseId == widget.exercise.id,
                    orElse: () => const ExerciseLog(
                      exerciseId: '',
                      exerciseName: '',
                      sets: [],
                    ),
                  );

                  if (exerciseLog.exerciseId.isNotEmpty) {
                    double value = 0.0;
                    if (isCardio) {
                      switch (_cardioMetric) {
                        case CardioMetric.duration:
                          value = exerciseLog.durationMinutes ?? 0.0;
                          break;
                        case CardioMetric.distance:
                          value = exerciseLog.distanceKm ?? 0.0;
                          break;
                        case CardioMetric.resistance:
                          value = exerciseLog.resistanceLevel ?? 0.0;
                          break;
                      }
                    } else {
                      switch (_strengthMetric) {
                        case StrengthMetric.oneRepMax:
                          value = exerciseLog.sets.fold<double>(0.0, (max, set) {
                            if (set.reps <= 0) return max;
                            final oneRM = set.weight * (1 + set.reps / 30.0);
                            return oneRM > max ? oneRM : max;
                          });
                          break;
                        case StrengthMetric.heaviestSet:
                          value = exerciseLog.sets.fold<double>(
                            0.0,
                            (max, set) => set.weight > max ? set.weight : max,
                          );
                          break;
                        case StrengthMetric.volume:
                          value = exerciseLog.sets.fold<double>(
                            0.0,
                            (sum, set) => sum + (set.reps * set.weight),
                          );
                          break;
                      }
                    }
                    points.add(_DataPoint(date: log.date, value: value));
                  }
                }

                // Reverse to make it chronological (oldest to newest)
                final sortedPoints = points.reversed.toList();

                if (sortedPoints.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.insights_outlined,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No completed sessions logged yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log workouts containing this exercise to see progress.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Metric Switcher
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: isCardio
                            ? CardioMetric.values.map((metric) {
                                final isSelected = _cardioMetric == metric;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(_getCardioLabel(metric)),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _cardioMetric = metric);
                                      }
                                    },
                                  ),
                                );
                              }).toList()
                            : StrengthMetric.values.map((metric) {
                                final isSelected = _strengthMetric == metric;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(_getStrengthLabel(metric)),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _strengthMetric = metric);
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Line Chart container
                    SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < sortedPoints.length) {
                                    // Show date for first, middle and last elements to avoid clutter
                                    if (sortedPoints.length <= 4 ||
                                        idx == 0 ||
                                        idx == sortedPoints.length - 1 ||
                                        idx == (sortedPoints.length / 2).floor()) {
                                      final dateStr = DateFormat('d MMM')
                                          .format(sortedPoints[idx].date);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          dateStr,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 9,
                                            color: theme.colorScheme.onSurfaceVariant
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) =>
                                  theme.colorScheme.surfaceContainerHighest,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final idx = spot.x.toInt();
                                  final value = spot.y;
                                  final unit = isCardio
                                      ? _getCardioUnit(_cardioMetric)
                                      : 'kg';
                                  final title = isCardio
                                      ? _getCardioLabel(_cardioMetric)
                                      : _getStrengthLabel(_strengthMetric);

                                  return LineTooltipItem(
                                    '$title: ${value.toStringAsFixed(1)} $unit\n',
                                    theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ) ??
                                        const TextStyle(),
                                    children: [
                                      TextSpan(
                                        text: DateFormat('dd MMM yyyy')
                                            .format(sortedPoints[idx].date),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(sortedPoints.length, (i) {
                                return FlSpot(i.toDouble(), sortedPoints[i].value);
                              }),
                              isCurved: true,
                              barWidth: 3,
                              color: theme.colorScheme.primary,
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withOpacity(0.15),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: theme.colorScheme.secondary,
                                    strokeWidth: 2,
                                    strokeColor: theme.colorScheme.primary,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Could not load progress charts.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStrengthLabel(StrengthMetric metric) {
    switch (metric) {
      case StrengthMetric.oneRepMax:
        return 'Est. 1RM';
      case StrengthMetric.heaviestSet:
        return 'Heaviest Set';
      case StrengthMetric.volume:
        return 'Total Volume';
    }
  }

  String _getCardioLabel(CardioMetric metric) {
    switch (metric) {
      case CardioMetric.duration:
        return 'Duration';
      case CardioMetric.distance:
        return 'Distance';
      case CardioMetric.resistance:
        return 'Resistance';
    }
  }

  String _getCardioUnit(CardioMetric metric) {
    switch (metric) {
      case CardioMetric.duration:
        return 'min';
      case CardioMetric.distance:
        return 'km';
      case CardioMetric.resistance:
        return 'lvl';
    }
  }
}

class _DataPoint {
  _DataPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}
