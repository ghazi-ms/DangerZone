import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:updated_grad/testing/geofence.dart';
import 'package:firebase_core/firebase_core.dart';
import 'customIcons/dangericon_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MyApp());
}

///main class builder contains [AnimatedSplashScreen] that shows the app icon.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منطقة الخطر',
      home: AnimatedSplashScreen(
        splashIconSize: 300,
        duration: 3000,
        splash: Dangericon.logobackground,
        nextScreen: Geofence(),
        splashTransition: SplashTransition.fadeTransition,
        pageTransitionType: PageTransitionType.bottomToTop,
        backgroundColor: Colors.red.shade900,
        centered: true,
      ),
    );
  }
}
