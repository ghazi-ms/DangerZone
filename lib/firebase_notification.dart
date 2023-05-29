import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseNotifications {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  /// Initializes the FlutterLocalNotificationsPlugin with the appropriate settings.
  static void initialize() {
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: AndroidInitializationSettings("@mipmap/ic_launcher"));
    _notificationsPlugin.initialize(initializationSettings);
  }
  /// Shows a notification using the provided [message].
  ///
  /// Args:
  ///   - [message]: The RemoteMessage containing the notification details.
  static void showNotification(RemoteMessage message) {
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
