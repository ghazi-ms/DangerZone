# Geofence App

The Geofence App is a Flutter application that allows users to receive notifications when entering or exiting predefined geofence areas. It uses Google Maps, Firebase, and device geolocation to track and notify users about danger zones.

## Features

- **Geofence Monitoring:** The app monitors the user's location and alerts them when they enter or exit predefined geofence areas.
- **Firebase Integration:** It integrates with Firebase to store and retrieve geofence data and user history.
- **Customizable Update Interval:** Users can configure the frequency of data updates and notifications.
- **Visual Alerts:** The app provides visual alerts on the map when a user is inside a geofence.


## Getting Started

To run the Geofence App on your local machine, follow these steps:

1. Clone this repository.
2. Make sure you have Flutter and Dart installed.
2. run the app either on local machine or as an APK on a android device.
3. open the app after installation and allow the usage of notifications services and location services
4. leave the app in the back ground while the app will do the work by it self ! .

## Dependencies

The Geofence App uses the following dependencies:

- `flutter`: The core Flutter framework.

- `geolocator`: A Flutter plugin for accessing location information.

- `dart:convert`: For JSON encoding and decoding.

- `http`: For making HTTP requests

- `flutter_local_notifications`: A Flutter plugin for displaying local notifications.

- `firebase_core` and `firebase_messaging`: Firebase plugins for cloud messaging.

- `cloud_firestore`: The Flutter plugin for accessing Firebase Firestore.

- `google_maps_flutter`: For working with Google Maps and geographic data.

- `intl`: For date and time formatting.

- `platform_device_id`: To obtain the unique device ID.

- `shared_preferences`: A plugin for reading and writing simple key-value pairs.



## Configuration

You can customize the following settings in the app:

- **Update Interval:** Change the frequency of data updates and notifications by modifying the `minutes` variable in the code or inside the app after running.
- **Firebase Integration:** To use your Firebase backend, update the Firebase configuration in the code.
