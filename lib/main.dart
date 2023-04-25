import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'serivces/geofence.dart';
import 'package:updated_grad/serivces/geofence.dart';

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

  runApp(MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  BackgroundFetch.start();
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GeofenceMap(),
    );
  }
}