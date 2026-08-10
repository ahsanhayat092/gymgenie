import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
    );
  }

  Future<void> requestPermissions() async {
    // Android 13+ requires explicit POST_NOTIFICATIONS permission
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    final iosImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// REST TIMER: Show notification after [seconds]
  Future<void> scheduleRestTimerNotification(int seconds) async {
    await cancelRestTimerNotification();
    if (seconds <= 0) return;

    const androidDetails = AndroidNotificationDetails(
      'rest_timer_channel',
      'Rest Timer Reminders',
      channelDescription: 'Alerts when your rest timer is complete',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    await _notificationsPlugin.zonedSchedule(
      1001,
      'Rest Done!',
      'Your rest timer is done. Time for the next set!',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelRestTimerNotification() async {
    await _notificationsPlugin.cancel(1001);
  }

  /// INACTIVITY REMINDER: Scheduled 3 days from now
  Future<void> scheduleInactivityReminder() async {
    await cancelInactivityReminder();

    const androidDetails = AndroidNotificationDetails(
      'inactivity_channel',
      'Inactivity Reminders',
      channelDescription: 'Alerts when you have not worked out for a few days',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(days: 3));

    await _notificationsPlugin.zonedSchedule(
      1002,
      'Missed Gym?',
      "You haven't trained in 3 days. Let's get back to it!",
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelInactivityReminder() async {
    await _notificationsPlugin.cancel(1002);
  }

  /// WORKOUT REMINDER: Daily reminder
  Future<void> scheduleWorkoutReminder({required int hour, required int minute}) async {
    await cancelWorkoutReminder();

    const androidDetails = AndroidNotificationDetails(
      'workout_reminder_channel',
      'Workout Reminders',
      channelDescription: 'Daily reminders for scheduled workouts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time is in the past, set it for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      1003,
      'Gym Time! 🏋️',
      "Time for your scheduled workout. Let's make some gains!",
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily
    );
  }

  Future<void> cancelWorkoutReminder() async {
    await _notificationsPlugin.cancel(1003);
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
