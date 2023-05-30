import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:updated_grad/firebase_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:updated_grad/serivces/firebase_helper.dart';
import '../notification_service.dart';
import '../widgets/cards.dart';
import 'package:number_selection/number_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:updated_grad/serivces/location_permission.dart';
import 'package:updated_grad/serivces/backend_data_fetch.dart';

/// The Geofence class .
class Geofence extends StatefulWidget {
  const Geofence({super.key});

  @override
  GeofenceState createState() => GeofenceState();
}

/// The main class of the Geofence class.
class GeofenceState extends State<Geofence> with WidgetsBindingObserver {
  List<Map<String, String>> historyList = [];
  final List<dynamic> dangerZonesData = [];
  late String notificationBody = "";
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? deviceId;
  bool _isInsideGeofence = false;
  final distanceFilter = 50;
  static const int tolerance = 400;
  late int minutes;
  late Timer _timerServer;
  late Timer _timerList;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};
  FireBaseHelper? fireBaseHelper;

  @override
  void initState() {
    super.initState();

    fireBaseHelper = FireBaseHelper();

    // Initialize references and services.

    NotificationService.requestNotificationPermission(context);
    NotificationService.initialize(flutterLocalNotificationsPlugin);

    // Load the initial value of 'minutes' and start the timers.
    loadMinutes().then((_) {
      startTimerList();
      startTimerServer();
    });

    // Handle foreground and background notification messages.
    FirebaseMessaging.onMessage.listen((event) {
      FirebaseNotifications.showNotification(event);
    });

    // Fetch location and initiate data fetching and loading after the UI has finished rendering.
    fetchingLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        // Load existing data from the Firebase collection
        loadDataToList();
      });
      fetchDangerZones();
    });
  }

  /// Fetches danger zone data from the backend.
  Future<void> fetchDangerZones() async {
    showSnackBar('يتم استرجاع مناطق الخطر الجديدة');
    BackendDataFetch backendFetch = BackendDataFetch();

    dynamic response = await backendFetch.fetchDangerZoneData(dangerZonesData);
    if (response['status'] == 200) {
      await loadDataToList();
      setState(() {
        dangerZonesData;
        historyList;
        circles;
        polygons;
      });
      updatePolygons();
      updateCircles();
      uploadToFirebase();
    }
    showSnackBar(response['message']);
  }

  /// Updates the polygons based on the retrieved data.
  void updatePolygons() {
    final polygonsTemp = <Polygon>{};
    for (final item in dangerZonesData) {

      List coordinates = jsonDecode(item['Coordinates']);
      print(coordinates.first[0]);
      final points = <LatLng>[];
      if (coordinates.length > 2) {
        for (var coordinate in coordinates) {
          final lat = double.parse(coordinate[0].toString());
          final lng = double.parse(coordinate[1].toString());
          points.add(LatLng(lat, lng));
        }

        if (polygons.isEmpty) {
          setState(() {
            polygons.add(Polygon(
              polygonId: PolygonId(item['id'].toString()),
              points: points.toList(),
              fillColor: Colors.blue.withOpacity(0.5),
              strokeColor: Colors.blue,
            ));
          });
        } else {
          for (final polygon in polygons) {
            if (polygon.polygonId.value.toString() != item['id'].toString()) {
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
      }
    }
  }

  /// Updates the circles list.
  void updateCircles() {
    for (final item in dangerZonesData) {
      final coordinates = item['Coordinates'];

      if (coordinates.length == 1) {
        setState(() {
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
  }

  /// function shows a SnackBar for each message received.
  void showSnackBar(String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
      ),
    );
  }

  /// function to fetch the current location
  Future<void> fetchingLocation() async {
    // Create a Location instance.
    Location location = Location();
    await ensureLocationServiceEnabled(location);

    // Listen to location changes and determine if the current location is inside a geofence.
    location.onLocationChanged.listen((LocationData currentLocation) {
      _handleLocationChange(
        currentLocation.latitude,
        currentLocation.longitude,
      );
    });
  }

  /// function to to be triggered if the user changes his location
  void _handleLocationChange(currentLatitude, currentLongitude) {
    bool isInsideGeofence = _isPositionInsideGeofence(
      currentLatitude,
      currentLongitude,
    );
    if (isInsideGeofence != _isInsideGeofence) {
      setState(() {
        _isInsideGeofence = isInsideGeofence;
      });
      if (_isInsideGeofence) {
        _onEnterGeofence();
      } else {
        _onExitGeofence();
      }
    }
  }

  /// function to check if the user is inside any geofence's
  bool _isPositionInsideGeofence(currentLatitude, currentLongitude) {
    bool isInsideCircle =
        _isPositionInsideCircles(currentLatitude, currentLongitude);
    bool isInsidePolygon =
        _isPositionInsidePolygons(currentLatitude, currentLongitude);

    return isInsideCircle || isInsidePolygon;
  }

  /// function to check if the user is inside a circle geofence
  bool _isPositionInsideCircles(currentLatitude, currentLongitude) {
    for (Circle circle in circles) {
      double distance = Geolocator.distanceBetween(
        currentLatitude,
        currentLongitude,
        circle.center.latitude,
        circle.center.longitude,
      );
      if (distance <= tolerance) {
        _addToHistoryList(
          circle.circleId.value,
          currentLatitude,
          currentLongitude,
        );
        // Find the corresponding danger zone element based on the circle ID.
        var foundElement = dangerZonesData.where((element) =>
        element['id'].toString() == circle.circleId.value.toString());

        // Extract the title from the found element to be used for notification.
        notificationBody =
        foundElement.isNotEmpty ? foundElement.first['title'] : "null";
        return true;
      }
    }

    return false;
  }

  /// function to check if the user is inside a polygon geofence
  bool _isPositionInsidePolygons(
    double currentLatitude,
    double currentLongitude,
  ) {
    for (Polygon polygon in polygons) {
      List<maps_toolkit.LatLng> polygonLatLngs = polygon.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();

      maps_toolkit.LatLng positionLatLng =
          maps_toolkit.LatLng(currentLatitude, currentLongitude);

      bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
        positionLatLng,
        polygonLatLngs,
        true,
      );


      if (isInsidePolygon) {
        if (!_isPolygonIdInHistoryList(polygon.polygonId.value)) {
          _addToHistoryList(
            polygon.polygonId.value,
            currentLatitude,
            currentLongitude,
          );
        }
        var foundElement = dangerZonesData.where((element) =>
        element['id'].toString() == polygon.polygonId.value.toString());

        // Extract the title from the found element to be used for notification.
        notificationBody =
        foundElement.isNotEmpty ? foundElement.first['title'] : "null";

        return true;
      }
    }

    return false;
  }

  /// function to check if the given polygon id is in the history list
  bool _isPolygonIdInHistoryList(String polygonId) {
    return historyList.any((element) => element['id'] == polygonId);
  }

  /// function to add the given id of an geofence and the current user location to the history list
  void _addToHistoryList(String id, double latitude, double longitude) {
    final existingHistoryIds =
        Set<String>.from(historyList.map((item) => item['id'].toString()));

    if (!existingHistoryIds.contains(id.toString())) {
      setState(() {
        historyList.add({
          'id': id.toString(),
          'position': '$latitude,$longitude',
        });
      });
      uploadToFirebase();
    }
  }

  /// function that calls the upload methods inside the fireBaseHelper to upload all the lists to the firebase
  Future<void> uploadToFirebase() async {
    fireBaseHelper?.uploadData(dangerZonesData, 'dangerData');
    fireBaseHelper?.uploadData(circles, 'circle');
    fireBaseHelper?.uploadData(polygons, 'polygon');
    fireBaseHelper?.uploadData(historyList, 'history');
  }

  ///function to Load Data from Firebase
  Future<void> loadDataToList() async {
    await fireBaseHelper?.loadData(dangerZonesData, 'dangerData');
    await fireBaseHelper?.loadData(circles, 'circle');
    await fireBaseHelper?.loadData(polygons, 'polygon');
    await fireBaseHelper?.loadData(historyList, 'history');
    setState(() {
      historyList;
      dangerZonesData;
    });
  }

  /// function to clear the history list and clears the history from the firebase
  Future<void> clear(
    BuildContext context,
    dynamic list,
    String listName,
  ) async {
    fireBaseHelper?.clearData(list, listName);

    setState(() {
      list.clear();
    });
    showSnackBar('!تم مسح جميع مناطق الخطر');
  }

  /// function to delete all the danger zone data and geofence's from the firebase and the local lists
  Future<void> deleteDocuments() async {
    var deletedIds = await fireBaseHelper?.deleteDocuments();
    removeItemFromHistoryList(deletedIds as List<String>);
    removeItemFromDangerZonesData(deletedIds as List<String>);
    removeCircleItem(deletedIds as List<String>);
    removePolygonItem(deletedIds as List<String>);
  }

  /// function to delete all deleted ids that are 24 hours old from the history list
  void removeItemFromHistoryList(List<String> deletedIds) async {
    for (var id in deletedIds) {
      historyList.removeWhere((element) => element['id'] == id);
    }
  }

  /// function to delete all deleted ids that are 24 hours old from the dangerZonesData list

  void removeItemFromDangerZonesData(List<String> deletedIds) {
    for (var id in deletedIds) {
      dangerZonesData.removeWhere((element) => element['id'] == id);
    }
  }

  /// function to delete all deleted ids that are 24 hours old from the circles list

  void removeCircleItem(List<String> deletedIds) {
    for (var id in deletedIds) {
      circles.removeWhere((element) => element.circleId.value.toString() == id);
    }
  }

  /// function to delete all deleted ids that are 24 hours old from the polygons list

  void removePolygonItem(List<String> deletedIds) {
    for (var id in deletedIds) {
      polygons
          .removeWhere((element) => element.polygonId.value.toString() == id);
    }
  }

  /// function to show a notification when the user enters a geofence
  void _onEnterGeofence() {
    NotificationService.showBigTextNotification(
      title: "لقد دخلت في منطقة خطرة!",
      body: notificationBody,
      fln: flutterLocalNotificationsPlugin,
    );
  }

  /// function to show a notification when the user exits a geofence
  void _onExitGeofence() {
    NotificationService.showBigTextNotification(
      title: "أنت في أمان!",
      body: "لقد خرجت من منطقة الخطر",
      fln: flutterLocalNotificationsPlugin,
    );
  }

  /// Loads the initial value of 'minutes' from shared preferences.
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

  /// saves the initial value of 'minutes' from shared preferences.
  Future<void> saveMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("Minutes", minutes);
    } catch (e) {
      throw e.toString();
    }
  }

  void startTimerServer() {
    final serverMinutes = Duration(minutes: minutes);
    _timerServer = Timer.periodic(
      serverMinutes,
      (Timer timer) => callServerFunction(),
    );
  }

  void callServerFunction() {
    fetchDangerZones();
    setState(() {
      loadDataToList();
    });
  }

  void cancelTimerServer() {
    _timerServer.cancel();
  }

  /// Starts the timer that updates the danger zone list every 24 hours.
  void startTimerList() {
    const listHours = Duration(hours: 24);
    _timerList = Timer.periodic(
      listHours,
      (Timer timer) => callListFunction(),
    );
  }

  void callListFunction() async {
    await deleteDocuments();
  }

  void cancelTimerList() {
    _timerList.cancel();
  }

  /// to call specific functions on the change of app state
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Loads data from the base when the application is resumed.
      setState(() {
        loadDataToList();
      });
    }
    if (state == AppLifecycleState.paused) {
      // Uploads data to Firebase when the application is paused.
      uploadToFirebase();
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
    uploadToFirebase();

    // Calls the base dispose method to properly dispose of the state.
    super.dispose();
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
                        clear(context, historyList, 'historyList');
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
                            outOfConstraintsColor: Colors.deepOrange,
                          ),
                          initialValue: minutes,
                          minValue: 1,
                          maxValue: 60,
                          direction: Axis.horizontal,
                          withSpring: true,
                          onChanged: (int value) {
                            minutes = value;
                          },
                          enableOnOutOfConstraintsAnimation: true,

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
                      ),
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
