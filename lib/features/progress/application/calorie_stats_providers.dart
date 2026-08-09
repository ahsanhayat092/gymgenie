import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymgenie/features/workout/data/log_repository.dart';
import 'package:gymgenie/features/workout/domain/workout_log.dart';

/// Total calories burned on a specific calendar day.
final dailyCaloriesProvider = Provider.family<int, DateTime>((ref, date) {
  final logs = ref.watch(workoutLogsProvider).valueOrNull ?? const <WorkoutLog>[];
  final day = DateTime(date.year, date.month, date.day);
  return logs.where((log) {
    final logDay = DateTime(log.date.year, log.date.month, log.date.day);
    return logDay == day;
  }).fold<int>(0, (sum, log) => sum + log.totalCalories);
});

/// Total calories burned in a specific calendar month.
final monthlyCaloriesProvider = Provider.family<int, DateTime>((ref, month) {
  final logs = ref.watch(workoutLogsProvider).valueOrNull ?? const <WorkoutLog>[];
  return logs.where((log) {
    return log.date.year == month.year && log.date.month == month.month;
  }).fold<int>(0, (sum, log) => sum + log.totalCalories);
});

/// All-time total calories burned.
final overallCaloriesProvider = Provider<int>((ref) {
  final logs = ref.watch(workoutLogsProvider).valueOrNull ?? const <WorkoutLog>[];
  return logs.fold<int>(0, (sum, log) => sum + log.totalCalories);
});

/// Daily calorie totals for the last [days] days, oldest first.
final recentDailyCaloriesProvider = Provider.family<List<DailyCalories>, int>((ref, days) {
  final logs = ref.watch(workoutLogsProvider).valueOrNull ?? const <WorkoutLog>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final result = <DailyCalories>[];
  for (var i = days - 1; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dayLogs = logs.where((log) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      return logDay == day;
    });
    final calories = dayLogs.fold<int>(0, (sum, log) => sum + log.totalCalories);
    result.add(DailyCalories(day, calories));
  }
  return result;
});

class DailyCalories {
  const DailyCalories(this.date, this.calories);
  final DateTime date;
  final int calories;
}
