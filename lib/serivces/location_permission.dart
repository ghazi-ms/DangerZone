import 'package:location/location.dart';

Future<void> ensureLocationServiceEnabled(Location location) async {
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;

  // Check if the location service is enabled, and request it if not.
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      return;
    }
  }

  // Check if the app has location permission, and request it if not.
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      return;
    }
  }

  // Enable background mode for location updates.
  location.enableBackgroundMode(enable: true);
}