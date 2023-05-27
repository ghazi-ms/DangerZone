import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:updated_grad/firebase_notification.dart';
import 'package:updated_grad/testing/test.dart';
import 'serivces/geofence.dart';
import 'package:firebase_core/firebase_core.dart';
import 'customIcons/dangericon_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'منطقة الخطر',
        home: AnimatedSplashScreen(
          splashIconSize: 300,
          duration: 3000,
          splash: Dangericon.logobackground,
          nextScreen: Test(),
          splashTransition: SplashTransition.fadeTransition,
          pageTransitionType: PageTransitionType.bottomToTop,
          backgroundColor: Colors.red.shade900,
          centered: true,
        ));
  }
}
