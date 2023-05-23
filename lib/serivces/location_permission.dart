import 'package:geolocator/geolocator.dart';

Future<Position> allowLocationService() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue

    return Future.error('Location services are disabled.');
  }

  try {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition();
    return position;
  } catch (e) {
    // Handle any errors that may occur while getting location data
    return Future.error('Failed to get location data: ${e.toString()}');
  }
}

Future<void> getLocation() async {
  try {
    Position position = await allowLocationService();
  } catch (e) {
    throw e.toString();
  }
}
