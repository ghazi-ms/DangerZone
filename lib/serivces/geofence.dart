import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:location/location.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform_device_id/platform_device_id.dart';
import 'package:updated_grad/firebase_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../notification_service.dart';
import '../widgets/cards.dart';
import 'package:number_selection/number_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class GeofenceMap extends StatefulWidget {
  const GeofenceMap({super.key});

  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

class _GeofenceMapState extends State<GeofenceMap> with WidgetsBindingObserver {
  List<Map<String, String>> historyList = [];
  List<dynamic> dangerGeofences = [''];
  final List<dynamic> dangerZonesData = [];
  late CollectionReference dangerZonesRef;
  late String notificationBody;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late LatLng center;
  String? deviceId;
  bool _isInsideGeofence = false;
  final distanceFilter = 50;
  static const int tolerance = 100;
  late int minutes;
  late Timer _timerServer;
  late Timer _timerList;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};

  @override
  void initState() {
    super.initState();

    // Initialize references and services.
    dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');

    NotificationService.requestNotificationPermission(context);
    NotificationService.initialize(flutterLocalNotificationsPlugin);

    // Load the initial value of 'minutes' and start the timers.
    loadMinutes().then((_) {
      startTimerList();
      startTimerServer();
    });

    // Retrieve device information.
    deviceInfo();

    // Handle foreground and background notification messages.
    FirebaseMessaging.onMessage.listen((event) {
      FirebaseNotifications.showNotification(event);
    });

    // Fetch location and initiate data fetching and loading after the UI has finished rendering.
    fetchingLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchDangerZones();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        // Load existing data from the Firebase collection
        loadDataToListFromBase();
      });
    });
  }

  Future<void> fetchDangerZones() async {

    // Show a snack bar notification indicating the retrieval of new danger zones
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text(
          'استرجاع مناطق الخطر الجديدة',
          textAlign: TextAlign.right,
        ),
      ),
    );

    const apiEndpoint = "https://backendgradproject-z9mv-master-gtgu5kzprq-wl.a.run.app";

    try {
      // Send a GET request to the API endpoint to fetch new danger zones
      final response =
          await get(Uri.parse(apiEndpoint)).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('!تم استرجاع مناطق الخطر الجديدة',
                textAlign: TextAlign.right),
          ),
        );

        // Extract the data from the response
        List<Map<String, dynamic>> data =
            json.decode(response.body).cast<Map<String, dynamic>>();

        // Add the new data to dangerZonesData if the ID doesn't already exist
        data.forEach((Map<String, dynamic> newData) {
          int id = newData['id'];
          // Check if the ID already exists in dangerZonesData
          bool idExists =
              dangerZonesData.any((existingData) => existingData['id'] == id);

          if (!idExists) {
            dangerZonesData.add(newData);
          }
        });

        final polygonsTemp = <Polygon>{};

        for (final item in dangerZonesData) {
          final coordinates = item['Coordinates'];
          final points = <LatLng>[];

          if (coordinates.length > 2) {
            // Create LatLng points for polygon coordinates
            for (final co in coordinates) {
              final lat = double.parse(co[0].toString());
              final lng = double.parse(co[1].toString());
              points.add(LatLng(lat, lng));
            }

            if (polygons.isEmpty) {
              setState(() {
                // Add the polygon to the polygons list
                polygons.add(Polygon(
                  polygonId: PolygonId(item['id'].toString()),
                  points: points.toList(),
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                ));
              });
            } else {
              for (final polygon in polygons) {
                if (polygon.polygonId.value != item['id']) {
                  // Add the polygon to the temporary polygons list
                  setState(() {
                    polygonsTemp.add(Polygon(
                      polygonId: PolygonId(item['id'].toString()),
                      points: points.toList(),
                      fillColor: Colors.blue.withOpacity(0.5),
                      strokeColor: Colors.blue,
                    ));
                  });
                }
              }
              polygons.addAll(polygonsTemp);
            }

            points.clear();
          } else {
            setState(() {
              // Add the circle to the circles list
              circles.add(Circle(
                circleId: CircleId(item['id'].toString()),
                center: LatLng(
                  double.parse(coordinates.first[0].toString()),
                  double.parse(coordinates.first[1].toString()),
                ),
                radius: 100,
                fillColor: Colors.blue.withOpacity(0.5),
                strokeColor: Colors.blue,
              ));
            });
          }
        }
      } else {
        throw 'Problem with the GET request';
      }
    } catch (e) {
      if (e.toString() == 'Connection closed while receiving data') {
        // Retry fetching danger zones if the connection is closed
        await fetchDangerZones();
      }
    }

    // Upload the updated danger zone data to Firebase
    uploadToFirbase();

    // Todo: Call the save lists function and return to the usual flow
  }

  Future<void> fetchingLocation() async {
    // Create a Location instance.
    Location location = Location();

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

    // Listen to location changes and determine if the current location is inside a geofence.
    location.onLocationChanged.listen((LocationData currentLocation) {
      bool isInsideGeofence = _isPositionInsideGeofence(
          currentLocation.latitude, currentLocation.longitude);

      // Check if the geofence status has changed.
      if (isInsideGeofence != _isInsideGeofence) {
        setState(() {
          _isInsideGeofence = isInsideGeofence;
        });

        // Trigger appropriate actions based on the geofence status.
        if (_isInsideGeofence) {
          _onEnterGeofence();
        } else {
          _onExitGeofence();
        }
      }
    });
  }

  bool _isPositionInsideGeofence(currentLatitude, currentLongitude) {
    // Check if the position is inside any of the circles.
    for (Circle circle in circles) {
      // Calculate the distance between the current position and the center of the circle.
      double distance = Geolocator.distanceBetween(
        currentLatitude,
        currentLongitude,
        circle.center.latitude,
        circle.center.longitude,
      );

      // Check if the distance is within the tolerance radius.
      if (distance <= tolerance) {
        // Check if the circle ID is not present in the history list to avoid duplicate entries.
        if (!historyList
            .any((element) => element['id'] == circle.circleId.value)) {
          setState(() {
            // Add the circle ID and current position to the history list.
            historyList.add({
              'id': circle.circleId.value,
              'position': '$currentLatitude,$currentLongitude'.toString()
            });

            // Find the corresponding danger zone element based on the circle ID.
            var foundElement = dangerZonesData.where((element) =>
                element['id'].toString() == circle.circleId.value.toString());

            // Extract the title from the found element to be used for notification.
            notificationBody =
                foundElement.isNotEmpty ? foundElement.first['title'] : "null";

            // Upload the history list to Firebase.
            uploadToFirbase();
          });
        }
        return true;
      }
    }

    // Check if the position is inside any of the polygons.
    for (Polygon polygon in polygons) {
      // Convert the polygon points to LatLng objects.
      List<maps_toolkit.LatLng> polygonLatLngs = polygon.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();

      // Create a LatLng object for the current position.
      maps_toolkit.LatLng positionLatLng =
          maps_toolkit.LatLng(currentLatitude, currentLongitude);

      // Check if the position is inside the polygon or within the allowed distance from the polygon edges.
      bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
          positionLatLng, polygonLatLngs, true);
      bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
          positionLatLng, polygonLatLngs, tolerance: tolerance, true);

      // Check if the position is inside the polygon or within the allowed distance.
      if ((isInsidePolygon == false && allowedDistance == true) ||
          isInsidePolygon == true) {
        // Check if the polygon ID is not present in the history list to avoid duplicate entries.
        if (!historyList
            .any((element) => element['id'] == polygon.polygonId.value)) {
          setState(() {
            // Add the polygon ID and current position to the history list.
            historyList.add({
              'id': polygon.polygonId.value,
              'position': '$currentLatitude,$currentLongitude'.toString()
            });

            // Upload the history list to Firebase.
            uploadToFirbase();
          });

          // Find the corresponding danger zone element based on the polygon ID.
          var foundElement = dangerZonesData.where((element) =>
              element['id'].toString() == polygon.polygonId.value.toString());

          // Extract the title from the found element to be used for notification.
          notificationBody =
              foundElement.isNotEmpty ? foundElement.first['title'] : "null";
        }
        return true;
      }
    }
    return false;
  }

  Future<void> uploadToFirbase() async {
    // Upload danger zones data
    for (int i = 0; i < dangerZonesData.length; i++) {
      dangerZonesRef
          .doc(deviceId.toString())
          .collection('dangerZonesData')
          .get()
          .then((QuerySnapshot querySnapshot) {
        final existingIds = Set<String>.from(
            querySnapshot.docs.map((doc) => doc['id'].toString()));

        // Check if the danger zone ID already exists in the Firebase collection
        if (existingIds.lookup(dangerZonesData[i]['id'].toString()) == null) {
          // Add the danger zone to the Firebase collection
          dangerZonesRef
              .doc(deviceId.toString())
              .collection('dangerZonesData')
              .add({
            'Coordinates': dangerZonesData[i]['Coordinates'].toString(),
            'title': dangerZonesData[i]['title'].toString(),
            'description': dangerZonesData[i]['description'].toString(),
            'id': dangerZonesData[i]['id'].toString(),
            'timeStamp': dangerZonesData[i]['timeStamp'].toString(),
            'Locations': dangerZonesData[i]['Locations'].toString(),
            'newsSource' : dangerZonesData[i]['newsSource'].toString()
          });
        }
      });
    }

    // Upload polygons data
    dangerZonesRef
        .doc(deviceId.toString())
        .collection('polygons')
        .get()
        .then((QuerySnapshot querySnapshot) {
      if (querySnapshot.docs.isEmpty) {
        // Add polygons to the Firebase collection if it's empty
        for (var polygon in polygons) {
          List<String> coordinatesList = [];

          for (var point in polygon.points.toList()) {
            coordinatesList.add(point.toJson().toString());
          }
          dangerZonesRef.doc(deviceId.toString()).collection('polygons').add({
            'polygonId': polygon.polygonId.value.toString(),
            'coordinates': coordinatesList.toString(),
          });
        }
      } else {
        final existingPolygonIds = Set<String>.from(
            querySnapshot.docs.map((doc) => doc['polygonId'].toString()));
        // Add polygons to the Firebase collection if they don't already exist
        for (var polygon in polygons) {
          if (existingPolygonIds.lookup(polygon.polygonId.value.toString()) ==
              null) {
            List<String> coordinatesList = [];

            for (var point in polygon.points.toList()) {
              coordinatesList.add(point.toJson().toString());
            }
            dangerZonesRef.doc(deviceId.toString()).collection('polygons').add({
              'polygonId': polygon.polygonId.value.toString(),
              'coordinates': coordinatesList.toString(),
            });
          }
        }
      }
    });

    // Upload circles data
    dangerZonesRef
        .doc(deviceId.toString())
        .collection('circles')
        .get()
        .then((QuerySnapshot querySnapshot) {
      if (querySnapshot.docs.isEmpty) {
        // Add circles to the Firebase collection if it's empty
        for (var circle in circles) {
          dangerZonesRef.doc(deviceId.toString()).collection('circles').add({
            'circleId': circle.circleId.value.toString(),
            'center': circle.center.toJson().toString(),
            'radius': circle.radius.toString(),
          });
        }
      } else {
        final existingCircleIds = Set<String>.from(
            querySnapshot.docs.map((doc) => doc['circleId'].toString()));
        // Add circles to the Firebase collection if they don't already exist
        for (var circle in circles) {
          if (existingCircleIds.lookup(circle.circleId.value.toString()) ==
              null) {
            dangerZonesRef.doc(deviceId.toString()).collection('circles').add({
              'circleId': circle.circleId.value.toString(),
              'center': circle.center.toJson().toString(),
              'radius': circle.radius.toString(),
            });
          }
        }
      }
    });

    // Upload history list data
    dangerZonesRef
        .doc(deviceId.toString())
        .collection('historyList')
        .get()
        .then((QuerySnapshot querySnapshot) {
      final existingHistoryIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['id'].toString()));
      // Add history items to the Firebase collection if they don't already exist
      for (var history in historyList) {
        if (!existingHistoryIds.contains(history['id'].toString())) {
          dangerZonesRef
              .doc(deviceId.toString())
              .collection('historyList')
              .add({
            'id': history['id'].toString(),
            'position': history['position'].toString()
          });
        }
      }
    });
  }

//Load Data from Firebase

  Future<void> loadDataToListFromBase() async {
    // Retrieve data from the Firestore collection
    await dangerZonesRef.doc().get().then((_) async {
      // Load circles, danger zones data, polygons, and history list
      await loadCircles();
      await loadDangerZonesData();
      await loadPolygons();
      await loadHistoryList();
    });
  }

  Future<void> loadDangerZonesData() async {
    // Retrieve danger zones data from the Firebase collection
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('dangerZonesData').get();

    List<Map<String, dynamic>> newDangerZones = [];

    querySnapshot.docs.forEach((element) {
      // Extract data from the document snapshot
      Map data = element.data() as Map;

      // Check if the danger zone ID already exists in the current danger zones data
      bool found = dangerZonesData
          .any((item) => item['id'].toString() == data['id'].toString());

      // Add the new danger zone to the list if it doesn't already exist
      if (!found) {
        newDangerZones.add({
          'Coordinates': data['Coordinates'],
          'Locations': data['Locations'],
          'description': data['description'],
          'id': data['id'],
          'timeStamp': data['timeStamp'],
          'title': data['title'],
          'newsSource': data['newsSource']
        });
      }
    });

    // Update the danger zones data with the new danger zones
    setState(() {
      dangerZonesData.addAll(newDangerZones);
    });
  }

  Future<void> loadCircles() async {
    // Retrieve circles data from the Firebase collection
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('circles').get();

    List<Circle> newCircles = [];

    querySnapshot.docs.forEach((element) {
      // Extract data from the document snapshot
      Map data = element.data() as Map;

      // Check if the circle with the given circle ID already exists
      bool found = circles
          .any((circle) => circle.circleId.value == data['circleId'].toString());

      // Add the new circle to the list if it doesn't already exist
      if (!found) {
        List<dynamic> center = jsonDecode(data['center']);
        double latitude = double.parse(center[0].toString());
        double longitude = double.parse(center[1].toString());
        Circle tempCircle = Circle(
          circleId: CircleId(data['circleId'].toString()),
          center: LatLng(latitude, longitude),
          radius: double.parse(data['radius'].toString()),
        );

        newCircles.add(tempCircle);
      }
    });

    // Update the circles data with the new circles
    setState(() {
      circles.addAll(newCircles);
    });
  }

  Future<void> loadPolygons() async {
    // Retrieve polygons data from the Firebase collection
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('polygons').get();

    List<Polygon> newPolygons = [];

    querySnapshot.docs.forEach((element) {
      // Extract data from the document snapshot
      Map data = element.data() as Map;

      // Check if the polygon with the given polygon ID already exists
      bool found = polygons.any(
          (polygon) => polygon.polygonId.value == data['polygonId'].toString());

      // Add the new polygon to the list if it doesn't already exist
      if (!found) {
        List<dynamic> coordinates = jsonDecode(data['coordinates']);
        List<LatLng> latLngList = coordinates
            .map((coord) => LatLng(
                  coord[0] as double, // latitude
                  coord[1] as double, // longitude
                ))
            .toList();

        Polygon tempPoly = Polygon(
          polygonId: PolygonId(data['polygonId']),
          points: latLngList,
        );

        newPolygons.add(tempPoly);
      }
    });

    // Update the polygons data with the new polygons
    setState(() {
      polygons.addAll(newPolygons);
    });
  }

  Future<void> loadHistoryList() async {
    // Retrieve history list data from the Firebase collection
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('historyList').get();

    List<Map<String, String>> newHistoryList = [];

    querySnapshot.docs.forEach((element) {
      // Extract data from the document snapshot
      Map data = element.data() as Map;

      // Check if the history item with the given ID already exists
      bool found = historyList
          .any((item) => item['id'].toString() == data['id'].toString());

      // Add the new history item to the list if it doesn't already exist
      if (!found) {
        newHistoryList.add({
          'id': data['id'].toString(),
          'position': data['position'].toString(),
        });
      }
    });

    // Update the history list with the new history items
    setState(() {
      historyList.addAll(newHistoryList);
    });
  }

  Future<void> clear(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;

    // Iterate over the historyList and delete corresponding documents from Firestore
    historyList.forEach((element) async {
      await firestore
          .collection('dangerZones')
          .doc(deviceId)
          .collection('historyList')
          .where('id', isEqualTo: element['id'].toString())
          .get()
          .then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
    });
    // Clear the historyList
    setState(() {
      historyList.clear();
    });
    // Show a snackbar indicating that all danger zones have been cleared
    const snackBar = SnackBar(
      content: Text('!تم مسح جميع مناطق الخطر', textAlign: TextAlign.right),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Function to delete documents within all collections based on a specific ID and timestamp
  Future<void> deleteDocuments() async {
    final firestore = FirebaseFirestore.instance;
    final currentTime = DateTime.now();
    final twentyFourHoursAgo = currentTime.subtract(const Duration(hours: 24));
    // Query documents within the 'dangerZonesData' collection
    final querySnapshot = await firestore
        .collection('dangerZones')
        .doc(deviceId)
        .collection('dangerZonesData')
        .get();
    // Iterate through each document
    for (final doc in querySnapshot.docs) {
      final id = doc['id'];
      final timestamp = doc['timeStamp'];

      // Convert timestamp to DateTime object if needed

      // Check if the timestamp is before 24 hours ago
      if (isTimestampBeforeTwentyFourHours(timestamp, twentyFourHoursAgo)) {
        // Delete documents within the 'circles' collection

        await firestore
            .collection('dangerZones')
            .doc(deviceId)
            .collection('circles')
            .where('circleId', isEqualTo: id)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        // Delete documents within the 'dangerZonesData' collection
        await firestore
            .collection('dangerZones')
            .doc(deviceId)
            .collection('dangerZonesData')
            .where('id', isEqualTo: id)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        // Delete documents within the 'historyList' collection
        await firestore
            .collection('dangerZones')
            .doc(deviceId)
            .collection('historyList')
            .where('id', isEqualTo: id)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        // Delete documents within the 'polygons' collection
        await firestore
            .collection('dangerZones')
            .doc(deviceId)
            .collection('polygons')
            .where('polygonId', isEqualTo: id)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            doc.reference.delete();
          }
        });
      }
      historyList.removeWhere((element) => element['id'] == id.toString());

      dangerZonesData.removeWhere((element) => element['id'] == id.toString());
      circles.removeWhere(
          (element) => element.circleId.value.toString() == id.toString());
      polygons.removeWhere(
          (element) => element.polygonId.value.toString() == id.toString());
    }
  }

  void _onEnterGeofence() {
    // Show a big text notification when the user enters a dangerous zone
    NotificationService.showBigTextNotification(
      title: "لقد دخلت في منطقة خطرة!",
      body: notificationBody,
      fln: flutterLocalNotificationsPlugin,
    );
  }

  void _onExitGeofence() {
    // TODO: Handle exit geofence event
    // Show a big text notification when the user exits a dangerous zone
    NotificationService.showBigTextNotification(
      title: "أنت في أمان!",
      body: "لقد خرجت من منطقة الخطر",
      fln: flutterLocalNotificationsPlugin,
    );
  }

  // Loads the value of "Minutes" from SharedPreferences and sets the 'minutes' variable accordingly.
// If the value is not found, it sets 'minutes' to a default value of 15.
  Future<void> loadMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedMinutes = prefs.getInt("Minutes");
      setState(() {
        minutes = loadedMinutes ?? 15;
      });
    } catch (e) {
      throw e.toString();
    }
  }

// Saves the current value of 'minutes' to SharedPreferences with the key "Minutes".
  Future<void> saveMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("Minutes", minutes);
    } catch (e) {
      throw e.toString();
    }
  }

// Starts a periodic timer that executes the 'callServerFunction()' at regular intervals based on the 'minutes' value.
// The timer is stored in the '_timerServer' variable.
  void startTimerServer() {
    var serverMinutes = Duration(minutes: minutes);
    _timerServer = Timer.periodic(
      serverMinutes,
      (Timer timer) => callServerFunction(),
    );
  }

// Performs network requests by calling 'fetchDangerZones()' and 'loadDataToListFromBase()' functions.
  void callServerFunction() {
    fetchDangerZones();
    loadDataToListFromBase();
  }

// Cancels the timer stored in the '_timerServer' variable.
  void cancelTimerServer() {
    _timerServer.cancel();
  }

// Starts a periodic timer that executes the 'callListFunction()' every 24 hours.
// The timer is stored in the '_timerList' variable.
  void startTimerList() {
    const listHours = Duration(hours: 24);
    _timerList = Timer.periodic(
      listHours,
      (Timer timer) => callListFunction(),
    );
  }

// Executes the 'deleteDocuments()' function, which likely deletes some documents or performs related operations.
  void callListFunction() {
    deleteDocuments();
  }

// Cancels the timer stored in the '_timerList' variable.
  void cancelTimerList() {
    _timerList.cancel();
  }

  // Retrieves device information, specifically the device ID.
  Future<void> deviceInfo() async {
    deviceId = await PlatformDeviceId.getDeviceId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Loads data from the base when the application is resumed.
      loadDataToListFromBase();
    }
    if (state == AppLifecycleState.paused) {
      // Uploads data to Firebase when the application is paused.
      uploadToFirbase();
    }
  }

  @override
  void dispose() {
    // Cancels the timers to stop any ongoing periodic tasks.
    _timerServer.cancel();
    _timerList.cancel();

    // Removes the observer for application lifecycle changes to prevent unnecessary callbacks.
    WidgetsBinding.instance.removeObserver(this);

    // Uploads data to Firebase before disposing of the resources.
    uploadToFirbase();

    // Calls the base dispose method to properly dispose of the state.
    super.dispose();
  }

  bool isTimestampBeforeTwentyFourHours(
      dynamic timestamp, DateTime twentyFourHoursAgo) {
    if (timestamp is String) {
      // Convert the timestamp string to a DateTime object
      final dateFormat = DateFormat("MM/dd/yyyy, HH:mm:ss");
      final timestampDateTime = dateFormat.parse(timestamp);

      // Compare the timestamp with the twentyFourHoursAgo parameter
      return timestampDateTime.isBefore(twentyFourHoursAgo);
    } else if (timestamp is Timestamp) {
      // Compare the Firestore Timestamp directly with the twentyFourHoursAgo parameter
      return timestamp.toDate().isBefore(twentyFourHoursAgo);
    }
    // Return false if the timestamp format is unsupported or invalid
    return false;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "حذف جميع مناطق الخطر",
            onPressed: () => showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  icon: const Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: 50,
                  ),
                  title: const Text(
                    "تأكيد الحذف",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 25),
                  ),
                  content: const Text(
                    "هل أنت متأكد أنك تريد حذف سجل مناطق الخطر الخاص بك؟",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 20),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "إلغاء",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        clear(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "حذف ",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'تغيير وقت التحقق من الأخبار الجديدة',
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text(
                      'تغيير وقت جلب البيانات',
                      textAlign: TextAlign.right,
                    ),
                    children: <Widget>[
                      Container(
                        alignment: Alignment.center,
                        width: 200,
                        height: 70,
                        child: NumberSelection(
                          theme: NumberSelectionTheme(
                              draggableCircleColor: Colors.red.shade300,
                              iconsColor: Colors.white,
                              numberColor: Colors.white,
                              backgroundColor: Colors.red.shade900,
                              outOfConstraintsColor: Colors.deepOrange),
                          initialValue: minutes,
                          minValue: 1,
                          maxValue: 60,
                          direction: Axis.horizontal,
                          withSpring: true,
                          onChanged: (int value) {
                            minutes = value;
                          },
                          enableOnOutOfConstraintsAnimation: true,
                          onOutOfConstraints: () =>
                              print("This value is too high or too low"),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              "إلغاء",
                              style: TextStyle(fontSize: 25),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              saveMinutes();
                              cancelTimerServer();
                              startTimerServer();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              "تم",
                              style: TextStyle(
                                fontSize: 25,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  );
                },
              );
            },
          ),
        ],
        backgroundColor: Colors.red.shade700,
        title: const Text('الأخبار'),
        centerTitle: true,
      ),
      body: historyList.isEmpty || dangerZonesData.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Center(
                  child: Text(
                    "أنت في أمان \n !لم تدخل أي منطقة خطرة",
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : Cards(historyList, dangerZonesData),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: FloatingActionButton(
          backgroundColor: Colors.red.shade800,
          child: const Icon(Icons.refresh),
          onPressed: () => fetchDangerZones(),
        ),
      ),
    );
  }
}
