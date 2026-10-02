import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Windows: instant toast while the app is running (local_notifier).
/// Android: one scheduled notification for the start of next week, which
/// still fires when the app is closed (flutter_local_notifications).
class AppNotifier {
  static bool _windowsReady = false;
  static bool _androidReady = false;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _weekEndId = 1;
  static const int _studyTimerId = 2;

  static Future<void> init() async {
    if (Platform.isWindows) {
      try {
        await localNotifier.setup(
          appName: 'Weekly Task',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        _windowsReady = true;
      } catch (_) {
        _windowsReady = false;
      }
    } else if (Platform.isAndroid) {
      try {
        tzdata.initializeTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        _androidReady = true;
      } catch (_) {
        _androidReady = false;
      }
    }
  }

  /// Instant notification. Windows only (Android uses [scheduleWeekEnd]).
  static Future<void> show(String title, String body) async {
    if (!_windowsReady) return;
    try {
      await LocalNotification(title: title, body: body).show();
    } catch (_) {}
  }

  /// Android only: (re)schedules the single "new week" notification.
  static Future<void> scheduleWeekEnd({
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!_androidReady) return;
    try {
      await _plugin.cancel(id: _weekEndId);
      if (!when.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: _weekEndId,
        title: title,
        body: body,
        // Same instant as [when]; expressed in UTC so no timezone lookup is needed.
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_task_channel',
            'Weekly Task',
            channelDescription: 'Reminders when a new week starts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> cancelStudyTimer() async {
    if (!_androidReady) return;
    try {
      await _plugin.cancel(id: _studyTimerId);
    } catch (_) {}
  }

  static Future<void> scheduleStudyTimer({
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (Platform.isWindows) {
      if (when.isAfter(DateTime.now())) return;
      await show(title, body);
      return;
    }
    if (!_androidReady) return;
    try {
      await _plugin.cancel(id: _studyTimerId);
      if (!when.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: _studyTimerId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_task_study_timer',
            'Study timer',
            channelDescription: 'Notifications when a study phase ends',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }
}
