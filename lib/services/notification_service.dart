import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      // Initialize timezone database
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(settings: initializationSettings);
      debugPrint('NotificationService initialized successfully in timezone $timeZoneName');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      bool? granted = false;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        granted = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        granted = await androidPlugin?.requestNotificationsPermission();
        
        try {
          final exactGranted = await androidPlugin?.requestExactAlarmsPermission();
          debugPrint('Exact alarm permission status: $exactGranted');
        } catch (e) {
          debugPrint('Error requesting exact alarm permission: $e');
        }
      }
      
      debugPrint('Notification permissions granted: $granted');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  static Future<void> scheduleDailyReminder(int hour, int minute, {int? pendingCount}) async {
    try {
      // Cancel existing reminder first to prevent multiple duplicates
      await cancelDailyReminder();

      final scheduledTime = _nextInstanceOfTime(hour, minute);

      String body;
      if (pendingCount != null && pendingCount > 0) {
        body = "$pendingCount Students log pending";
      } else {
        body = "Time to log today's lessons! Tap here to check if any students are pending.";
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          id: 0,
          title: 'Student Logging Reminder',
          body: body,
          scheduledDate: scheduledTime,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_log_reminders',
              'Daily Log Reminders',
              channelDescription: 'Reminders for teachers to log student progress',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time, // Daily recurring
        );
        debugPrint('Daily reminder scheduled with exactAllowWhileIdle for $hour:${minute.toString().padLeft(2, '0')} (First occurrence: $scheduledTime, pendingCount: $pendingCount)');
      } catch (e) {
        await _notificationsPlugin.zonedSchedule(
          id: 0,
          title: 'Student Logging Reminder',
          body: body,
          scheduledDate: scheduledTime,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_log_reminders',
              'Daily Log Reminders',
              channelDescription: 'Reminders for teachers to log student progress',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
          // Reverted to one-shot inexact notification to bypass exact alarm permission checks
        );
        debugPrint('Daily reminder scheduled with inexact ONE-SHOT fallback (exact alarm permission denied/error: $e) for $hour:${minute.toString().padLeft(2, '0')} (First occurrence: $scheduledTime, pendingCount: $pendingCount)');
      }
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  static Future<void> cancelDailyReminder() async {
    try {
      await _notificationsPlugin.cancel(id: 0);
      debugPrint('Daily reminder cancelled successfully');
    } catch (e) {
      debugPrint('Error cancelling daily reminder: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

}
