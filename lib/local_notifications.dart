import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void initialize() {
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: AndroidInitializationSettings("@mipmap/ic_launcher"));
    _notificationsPlugin.initialize(initializationSettings);

  }
  static Future<void> requestNotificationPermission(BuildContext context) async {
    final PermissionStatus status = await Permission.notification.request();

   if (status.isDenied || status.isPermanentlyDenied) {
      // User denied permission or permanently denied permission
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Notification Permission'),
          content: const Text('Please grant permission to receive notifications.'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () => openAppSettings(),
            ),
          ],
        ),
      );
    }
  }
  static void showNotificationOnForeground(RemoteMessage message) {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        "com.example.firebase_push_notification",
        "firebase_push_notification",
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    _notificationsPlugin.show(
      DateTime.now().microsecond,
      message.notification!.title,
      message.notification!.body,
      notificationDetails,
      payload: message.data["message"],
    );
  }
}
