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
import 'package:updated_grad/firebase_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:updated_grad/serivces/firebase_helper.dart';
import '../notification_service.dart';
import '../widgets/cards.dart';
import 'package:number_selection/number_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  _TestState createState() => _TestState();
}

class _TestState extends State<Test> with WidgetsBindingObserver {
  List<Map<String, String>> historyList = [];
  List<dynamic> dangerGeofences = [''];
  final List<dynamic> dangerZonesData = [];

  late String notificationBody = "";

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

  FireBaseHelper? fireBaseHelper;
  @override
  void initState() {
    super.initState();

    fireBaseHelper=FireBaseHelper();

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
      // fetchDangerZones();
    });
  }

  Future<void> fetchDangerZones() async {
    showNotification();
    // await fetchDangerZoneData();
    updateUI();
    await loadDataToList();
    uploadToFirebase();
  }

  void showNotification() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text(
          'استرجاع مناطق الخطر الجديدة',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  Future<void> fetchDangerZoneData() async {
    const apiEndpoint =
        "https://backendgradproject-z9mv-master-gtgu5kzprq-wl.a.run.app/";

    try {
      final response =
          await get(Uri.parse(apiEndpoint)).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> data =
            json.decode(response.body).cast<Map<String, dynamic>>();
        processDangerZoneData(data);
      } else {
        throw 'Problem with the GET request';
      }
    } catch (e) {
      if (e.toString() == 'Connection closed while receiving data') {
        await fetchDangerZoneData(); // Retry fetching danger zones if the connection is closed
      }
    }
  }

  void processDangerZoneData(List<Map<String, dynamic>> data) {
    data.forEach((Map<String, dynamic> newData) {
      int id = newData['id'];
      // Check if the ID already exists in dangerZonesData
      bool idExists = dangerZonesData.any(
          (existingData) => existingData['id'].toString() == id.toString());

      if (!idExists) {
        dangerZonesData.add(newData);
      }
    });

    updatePolygons();
    updateCircles();
  }

  void updatePolygons() {
    final polygonsTemp = <Polygon>{};

    for (final item in dangerZonesData) {
      final coordinates = item['Coordinates'];
      final points = <LatLng>[];

      if (coordinates.length > 2) {
        for (final co in coordinates) {
          final lat = double.parse(co[0].toString());
          final lng = double.parse(co[1].toString());
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

  void updateUI() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content:
            Text('!تم استرجاع مناطق الخطر الجديدة', textAlign: TextAlign.right),
      ),
    );
  }

  Future<void> fetchingLocation() async {
    // Create a Location instance.
    Location location = Location();

    await ensureLocationServiceEnabled(location);

    // Listen to location changes and determine if the current location is inside a geofence.
    location.onLocationChanged.listen((LocationData currentLocation) {
      _handleLocationChange(
          currentLocation.latitude, currentLocation.longitude);
    });
  }

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

  bool _isPositionInsideGeofence(currentLatitude, currentLongitude) {
    bool isInsideCircle =
        _isPositionInsideCircles(currentLatitude, currentLongitude);
    bool isInsidePolygon =
        _isPositionInsidePolygons(currentLatitude, currentLongitude);

    return isInsideCircle || isInsidePolygon;
  }

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
            circle.circleId.value, currentLatitude, currentLongitude);
        return true;
      }
    }

    return false;
  }

  bool _isPositionInsidePolygons(
      double currentLatitude, double currentLongitude) {
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
      bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
        positionLatLng,
        polygonLatLngs,
        tolerance: tolerance,
        true,
      );

      if ((isInsidePolygon == false && allowedDistance == true) ||
          isInsidePolygon == true) {
        if (!_isPolygonIdInHistoryList(polygon.polygonId.value)) {
          _addToHistoryList(
              polygon.polygonId.value, currentLatitude, currentLongitude);
        }
        return true;
      }
    }
    return false;
  }

  bool _isPolygonIdInHistoryList(String polygonId) {
    return historyList.any((element) => element['id'] == polygonId);
  }

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

  Future<void> uploadToFirebase() async {
    print("uploading0");
    fireBaseHelper?.uploadData(dangerZonesData, 'dangerData');
    fireBaseHelper?.uploadData(circles, 'circle');
    fireBaseHelper?.uploadData(polygons, 'polygon');
    fireBaseHelper?.uploadData(historyList, 'history');

  }

//Load Data from Firebase

  Future<void> loadDataToList() async {
    print("loading0");
    await fireBaseHelper?.loadData(dangerZonesData, 'dangerData');
    await fireBaseHelper?.loadData(circles, 'circle');
    await fireBaseHelper?.loadData(polygons, 'polygon');
    await fireBaseHelper?.loadData(historyList, 'history');

    setState(() {
      historyList;
      dangerZonesData;
    });

  }

  Future<void> clear(BuildContext context, dynamic list,String listName) async {
    fireBaseHelper?.clearData(list,listName);

    setState(() {
      list.clear();
    });
    showClearSnackbar(context);
  }

  void showClearSnackbar(BuildContext context) {
    const snackBar = SnackBar(
      content: Text('!تم مسح جميع مناطق الخطر', textAlign: TextAlign.right),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> deleteDocuments() async {
    final firestore = FirebaseFirestore.instance;
    final currentTime = DateTime.now();
    final twentyFourHoursAgo = currentTime.subtract(const Duration(hours: 24));
    final querySnapshot = await getDangerZonesDataQuerySnapshot(firestore);

    for (final doc in querySnapshot.docs) {
      final id = doc['id'];
      final timestamp = doc['timeStamp'];

      if (isTimestampBeforeTwentyFourHours(timestamp, twentyFourHoursAgo)) {
        await deleteDocumentsInCollection(firestore, 'circles', id);
        await deleteDocumentsInCollection(firestore, 'dangerZonesData', id);
        await deleteDocumentsInCollection(firestore, 'historyList', id);
        await deleteDocumentsInCollection(firestore, 'polygons', id);
      }

      removeItemFromHistoryList(id.toString());
      removeItemFromDangerZonesData(id.toString());
      removeCircleItem(id.toString());
      removePolygonItem(id.toString());
    }
  }

  Future<QuerySnapshot> getDangerZonesDataQuerySnapshot(
      FirebaseFirestore firestore) async {
    return firestore
        .collection('dangerZones')
        .doc(deviceId)
        .collection('dangerZonesData')
        .get();
  }

  Future<void> deleteDocumentsInCollection(
      FirebaseFirestore firestore, String collection, String id) async {
    final querySnapshot = await firestore
        .collection('dangerZones')
        .doc(deviceId)
        .collection(collection)
        .where('id', isEqualTo: id)
        .get();

    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }

  void removeItemFromHistoryList(String id) {
    historyList.removeWhere((element) => element['id'] == id);
  }

  void removeItemFromDangerZonesData(String id) {
    dangerZonesData.removeWhere((element) => element['id'] == id);
  }

  void removeCircleItem(String id) {
    circles.removeWhere((element) => element.circleId.value.toString() == id);
  }

  void removePolygonItem(String id) {
    polygons.removeWhere((element) => element.polygonId.value.toString() == id);
  }

  void _onEnterGeofence() {
    NotificationService.showBigTextNotification(
      title: "لقد دخلت في منطقة خطرة!",
      body: notificationBody,
      fln: flutterLocalNotificationsPlugin,
    );
  }

  void _onExitGeofence() {
    NotificationService.showBigTextNotification(
      title: "أنت في أمان!",
      body: "لقد خرجت من منطقة الخطر",
      fln: flutterLocalNotificationsPlugin,
    );
  }

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

  void startTimerList() {
    const listHours = Duration(hours: 24);
    _timerList = Timer.periodic(
      listHours,
      (Timer timer) => callListFunction(),
    );
  }

  void callListFunction() {
    deleteDocuments();
  }

  void cancelTimerList() {
    _timerList.cancel();
  }



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
                        clear(context,historyList,'historyList');
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
