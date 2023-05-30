import 'dart:io';
import 'package:location/location.dart';

/// Function to check if the user granted permission to the location services.
Future<void> ensureLocationServiceEnabled(Location location) async {
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;

  // Check if the location service is enabled, and request it if not.
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      exit(0); // Close the app if location service is not enabled.

    }
  }

  // Check if the app has location permission, and request it if not.
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      exit(0); // Close the app if location permission is not granted.

    }
  }

  // Enable background mode for location updates.
  location.enableBackgroundMode(enable: true);
}
