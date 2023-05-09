import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'serivces/geofence.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GeofenceMap(),
    );
  }
}
