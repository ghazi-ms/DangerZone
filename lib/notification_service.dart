import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  /// function to initialize the settings and the plugins of the notification.
  static Future initialize(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize =
        new AndroidInitializationSettings('mipmap/ic_launcher');

    var initializationsSettings =
        new InitializationSettings(android: androidInitialize);
    await flutterLocalNotificationsPlugin.initialize(initializationsSettings);
  }
  /// function that shows the notification takes [title] and [body] to show.
  static Future showBigTextNotification(
      {var id = 0,
      required String title,
      required String body,
      var payload,
      required FlutterLocalNotificationsPlugin fln}) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        new AndroidNotificationDetails(
      'you_can_name_it_whatever1',
      'channel_name',
      playSound: true,
      importance: Importance.max,
      priority: Priority.high,
    );

    var not = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, not);
  }
  ///function to check if the user granted the notification permission to the app.
  static Future<void> requestNotificationPermission(
      BuildContext context) async {
    final PermissionStatus status = await Permission.notification.request();

    if (status.isDenied ||
        status.isPermanentlyDenied ||
        status.isRestricted ||
        status.isLimited) {
      // User denied permission or permanently denied permission
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Notification Permission'),
          content:
              const Text('Please grant permission to receive notifications.'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                }),
          ],
        ),
      );
    }
  }
}
