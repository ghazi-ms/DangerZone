import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:updated_grad/local_notifications.dart';
import 'package:updated_grad/serivces/geofence.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:background_fetch/background_fetch.dart';

Future<void> backgroundHandler(RemoteMessage message) async {
  print("This is message form background");
  print(message.notification?.title);
  print(message.notification?.body);
}

void backgroundFetchHeadlessTask() async {
  // Your code to run in the background goes here
  print("This works fine");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);

  runApp(GeofenceMap());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  BackgroundFetch.start();
}
