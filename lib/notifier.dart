import 'dart:io' show Platform;

import 'package:local_notifier/local_notifier.dart';

/// Windows toast notifications. Does nothing on other platforms.
class AppNotifier {
  static bool _ready = false;

  static Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      await localNotifier.setup(
        appName: 'Weekly Task',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      await LocalNotification(title: title, body: body).show();
    } catch (_) {}
  }
}
