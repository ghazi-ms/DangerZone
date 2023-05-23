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
import 'package:updated_grad/local_notifications.dart';
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

  late String notificationMSG;
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

  Future<void> loadMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedMinutes = prefs.getInt("Minutes");
      setState(() {
        minutes = loadedMinutes ?? 15;
      });
      print("Loaded: $minutes");
    } catch (e) {
      print("Error loading data: $e");
    }
  }

  void startTimerServer() {
    print("after $minutes");
    var SecondsServer = Duration(minutes: minutes);
    _timerServer = Timer.periodic(
      SecondsServer,
      (Timer timer) => callServerFunction(),
    );
  }

  Future<void> saveMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("Minutes", minutes);
      print("Saved: $minutes");
    } catch (e) {
      print("Error saving data: $e");
    }
  }

  void callServerFunction() {
    // Perform network request
    print("calling");
    fetchDangerZones();
    loadDataToListFromBase();
  }

  void cancelTimerServer() {
    _timerServer.cancel();
  }

  void startTimerList() {
    const SecondsList = Duration(hours: 24);
    _timerList = Timer.periodic(
      SecondsList,
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
  void dispose() {
    _timerServer.cancel();
    _timerList.cancel();
    WidgetsBinding.instance.removeObserver(this);
    uploadToFirbase();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadDataToListFromBase();
    }
    if (state == AppLifecycleState.paused) {
      uploadToFirbase();
    }
  }

  Future<void> DeviceInfo() async {
    deviceId = await PlatformDeviceId.getDeviceId;
    print(deviceId);
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

  // Function to delete documents within all collections based on a specific ID and timestamp
  Future<void> deleteDocuments() async {
    final firestore = FirebaseFirestore.instance;
    final currentTime = DateTime.now();
    final twentyFourHoursAgo = currentTime.subtract(Duration(hours: 24));

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
        print('delete $id in $timestamp');

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

  @override
  void initState() {
    super.initState();
    loadMinutes().then((_) {
      startTimerList();
      startTimerServer();
    });
    DeviceInfo();
    dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
    WidgetsBinding.instance.addObserver(this);
    LocalNotificationService.initialize();
    LocalNotificationService.requestNotificationPermission(context);
    NotificationService.initialize(flutterLocalNotificationsPlugin);

    FirebaseMessaging.instance.getInitialMessage().then((event) {});

    FirebaseMessaging.onMessage.listen((event) {
      LocalNotificationService.showNotificationOnForeground(event);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((event) {});

    fetchingLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchDangerZones();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        loadDataToListFromBase();
      });
    });
  }

  Future<void> fetchingLocation() async {
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    location.enableBackgroundMode(enable: true);
    location.onLocationChanged.listen((LocationData currentLocation) {
      bool isInsideGeofence = _isPositionInsideGeofence(
          currentLocation.latitude, currentLocation.longitude);
      if (isInsideGeofence != _isInsideGeofence) {
        setState(() {
          _isInsideGeofence = isInsideGeofence;
        });
        if (_isInsideGeofence) {
          _onEnterGeofence();
          print('inside');
        } else {
          print('outside');
          _onExitGeofence();
        }
      }
    });
  }

  bool _isPositionInsideGeofence(currentLatitude, currentLongitude) {
    for (Circle circle in circles) {
      double distance = Geolocator.distanceBetween(
        currentLatitude,
        currentLongitude,
        circle.center.latitude,
        circle.center.longitude,
      );
      if (distance <= tolerance) {
        if (!historyList
            .any((element) => element['id'] == circle.circleId.value)) {
          setState(() {
            historyList.add({
              'id': circle.circleId.value,
              'position': '$currentLatitude,$currentLongitude'.toString()
            });
            var foundElement = dangerZonesData.where((element) =>
                element['id'].toString() == circle.circleId.value.toString());
            // Extract the title from the found element
            notificationBody =
                foundElement.isNotEmpty ? foundElement.first['title'] : "null";
            uploadToFirbase();
          });
        }
        return true;
      }
    }
    // Check if the position is inside the polygon
    for (Polygon polygon in polygons) {
      List<maps_toolkit.LatLng> polygonLatLngs = polygon.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();
      maps_toolkit.LatLng positionLatLng =
          maps_toolkit.LatLng(currentLatitude, currentLongitude);

      bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
          positionLatLng, polygonLatLngs, true);

      bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
          positionLatLng, polygonLatLngs, tolerance: tolerance, true);

      if ((isInsidePolygon == false && allowedDistance == true) ||
          isInsidePolygon == true) {
        if (!historyList
            .any((element) => element['id'] == polygon.polygonId.value)) {
          setState(() {
            historyList.add({
              'id': polygon.polygonId.value,
              'position': '$currentLatitude,$currentLongitude'.toString()
            });
            uploadToFirbase();
          });
          var foundElement = dangerZonesData.where((element) =>
              element['id'].toString() == polygon.polygonId.value.toString());
          // Extract the title from the found element
          notificationBody =
              foundElement.isNotEmpty ? foundElement.first['title'] : "null";
        }
        return true;
      }
    }
    return false;
  }

  //to databasse
  Future<void> uploadToFirbase() async {
    print("called upload");
    for (int i = 0; i < dangerZonesData.length; i++) {
      dangerZonesRef
          .doc(deviceId.toString())
          .collection('dangerZonesData')
          .get()
          .then((QuerySnapshot querySnapshot) {
        final existingIds = Set<String>.from(
            querySnapshot.docs.map((doc) => doc['id'].toString()));

        if (existingIds.lookup(dangerZonesData[i]['id'].toString()) == null) {
          dangerZonesRef
              .doc(deviceId.toString())
              .collection('dangerZonesData')
              .add({
            'Coordinates': dangerZonesData[i]['Coordinates'].toString(),
            'title': dangerZonesData[i]['title'].toString(),
            'description': dangerZonesData[i]['description'].toString(),
            'id': dangerZonesData[i]['id'].toString(),
            'timeStamp': dangerZonesData[i]['timeStamp'].toString(),
            'Locations': dangerZonesData[i]['Locations'].toString()
          });
        } else {
          print('no');
        }
      }).catchError((error) => print('Error getting documents: $error'));
    }

    dangerZonesRef
        .doc(deviceId.toString())
        .collection('polygons')
        .get()
        .then((QuerySnapshot querySnapshot) {
      if (querySnapshot.docs.isEmpty) {
        for (var polygon in polygons) {
          List<String> coordinatesList = [];

          for (var point in polygon.points.toList()) {
            coordinatesList.add(point.toJson().toString());
          }
          print(coordinatesList.toString());
          dangerZonesRef.doc(deviceId.toString()).collection('polygons').add({
            'polygonId': polygon.polygonId.value.toString(),
            'coordinates': coordinatesList.toString(),
          });
        }
      } else {
        final existingPolygonIds = Set<String>.from(
            querySnapshot.docs.map((doc) => doc['polygonId'].toString()));
        for (var polygon in polygons) {
          print("existing id $existingPolygonIds");
          print("current id ${polygon.polygonId}");
          print(
              "contains or not ${existingPolygonIds.contains(polygon.polygonId.toString())}");
          if (existingPolygonIds.lookup(polygon.polygonId.value.toString()) ==
              null) {
            List<String> coordinatesList = [];

            for (var point in polygon.points.toList()) {
              coordinatesList.add(point.toJson().toString());
            }
            print(coordinatesList.toString());
            dangerZonesRef.doc(deviceId.toString()).collection('polygons').add({
              'polygonId': polygon.polygonId.value.toString(),
              'coordinates': coordinatesList.toString(),
            });
          } else {
            print('no');
          }
        }
      }
    }).catchError((error) => print('Error getting documents: $error'));
    dangerZonesRef
        .doc(deviceId.toString())
        .collection('circles')
        .get()
        .then((QuerySnapshot querySnapshot) {
      if (querySnapshot.docs.isEmpty) {
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
        for (var circle in circles) {
          print("existing id $existingCircleIds");
          print("current id ${circle.circleId.value}");
          print("contains or not ");

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
    }).catchError((error) => print('Error getting documents: $error'));

    dangerZonesRef
        .doc(deviceId.toString())
        .collection('historyList')
        .get()
        .then((QuerySnapshot querySnapshot) {
      final existingHistoryIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['id'].toString()));
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
    }).catchError((error) => print('Error getting documents: $error'));
  }

//From Database
  Future<void> loadDataToListFromBase() async {
    print("loading");
    await dangerZonesRef.doc().get().then((_) async {
      await loadCircles();
      await loadDangerZonesData();
      await loadPolygons();
      await loadHistoryList();
    });
  }

  Future<void> loadDangerZonesData() async {
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('dangerZonesData').get();

    List<Map<String, dynamic>> newDangerZones = [];

    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;

      bool found = dangerZonesData
          .any((item) => item['id'].toString() == x['id'].toString());
      print(found);
      if (!found) {
        newDangerZones.add({
          'Coordinates': x['Coordinates'],
          'Locations': x['Locations'],
          'description': x['description'],
          'id': x['id'],
          'timeStamp': x['timeStamp'],
          'title': x['title'],
        });
      }
    });

    setState(() {
      dangerZonesData.addAll(newDangerZones);
    });
  }

  Future<void> loadCircles() async {
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('circles').get();

    if (querySnapshot.docs.isEmpty) {
      print("help empty");
    }
    List<Circle> newCircles = [];

    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;

      bool found = circles
          .any((circle) => circle.circleId.value == x['circleId'].toString());

      if (!found) {
        List<dynamic> center = jsonDecode(x['center']);
        double latitude = double.parse(center[0].toString());
        double longitude = double.parse(center[1].toString());
        Circle tempCircle = Circle(
          circleId: CircleId(x['circleId'].toString()),
          center: LatLng(latitude, longitude),
          radius: double.parse(x['radius'].toString()),
        );

        newCircles.add(tempCircle);
      }
    });

    setState(() {
      circles.addAll(newCircles);
    });
  }

  Future<void> loadPolygons() async {
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('polygons').get();

    List<Polygon> newPolygons = [];

    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;

      bool found = polygons.any(
          (polygon) => polygon.polygonId.value == x['polygonId'].toString());

      if (!found) {
        List<dynamic> coordinates = jsonDecode(x['coordinates']);
        List<LatLng> latLngList = coordinates
            .map((coord) => LatLng(
                  coord[0] as double, // latitude
                  coord[1] as double, // longitude
                ))
            .toList();

        Polygon tempPoly = Polygon(
          polygonId: PolygonId(x['polygonId']),
          points: latLngList,
        );

        newPolygons.add(tempPoly);
      }
    });

    setState(() {
      polygons.addAll(newPolygons);
    });
  }

  Future<void> loadHistoryList() async {
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('historyList').get();

    List<Map<String, String>> newHistoryList = [];

    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;

      bool found = historyList
          .any((item) => item['id'].toString() == x['id'].toString());

      if (!found) {
        newHistoryList.add(
            {'id': x['id'].toString(), 'position': x['position'].toString()});
      }
    });

    setState(() {
      historyList.addAll(newHistoryList);
    });
  }

  Future<void> fetchDangerZones() async {
    loadDataToListFromBase();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
          content: Text(
        'استرجاع مناطق الخطر الجديدة',
        textAlign: TextAlign.right,
      )),
    );
    // const apiEndpoint = "http://192.168.0.108:5000";
    const apiEndpoint = "http://ghazims.pythonanywhere.com/";

    try {
      final response =
          await get(Uri.parse(apiEndpoint)).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('!تم استرجاع مناطق الخطر الجديدة',
                  textAlign: TextAlign.right)),
        );

        List<Map<String, dynamic>> data =
            json.decode(response.body).cast<Map<String, dynamic>>();
// Adding the data to dangerZonesData if the id doesn't exist already
        data.forEach((Map<String, dynamic> newData) {
          int id = newData['id'];

          // Checking if the id already exists in dangerZonesData
          bool idExists =
              dangerZonesData.any((existingData) => existingData['id'] == id);

          if (!idExists) {
            dangerZonesData.add(newData);
          }
        });
// Printing the updated dangerZonesData list
        print(dangerZonesData);

        final polygonsTemp = <Polygon>{};

        for (final item in dangerZonesData) {
          final coordinates = item['Coordinates'];
          // print(coordinates);
          final points = <LatLng>[];
          // print('$item----$coordinates');

          if (coordinates.length > 2) {
            for (final co in coordinates) {
              final lat = double.parse(co[0].toString());
              final lng = double.parse(co[1].toString());
              points.add(LatLng(lat, lng));
            }
            // print(points.toString());
            print('id is: ${item['id']} name: ${item['title']}');
            if (polygons.isEmpty) {
              setState(() {
                polygons.add(Polygon(
                  polygonId: PolygonId(item['id'].toString()),
                  points: points.toList(),
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                ));
                print(
                    "this is the poly id ${polygons.first.polygonId.value} and points ${polygons.first.points}");
              });
            } else {
              for (final polygon in polygons) {
                print(
                    "this is the poly id ${polygon.polygonId.value} and points ${polygons.last.points}");
                if (polygon.polygonId.value != item['id']) {
                  // Todo () make it on title
                  setState(() {
                    polygonsTemp.add(Polygon(
                      polygonId: PolygonId(item['id'].toString()),
                      points: points.toList(),
                      fillColor: Colors.blue.withOpacity(0.5),
                      strokeColor: Colors.blue,
                    ));
                  });
                } else {
                  print('already there');
                }
              }
              polygons.addAll(polygonsTemp);
            }

            points.clear();
          } else {
            setState(() {
              circles.add(Circle(
                circleId: CircleId(item['id'].toString()),
                center: LatLng(double.parse(coordinates.first[0].toString()),
                    double.parse(coordinates.first[1].toString())),
                radius: 100,
                fillColor: Colors.blue.withOpacity(0.5),
                strokeColor: Colors.blue,
              ));
              print('added circle and this is the id ${circles.last.circleId}');
            });
          }
        }
      } else {
        print(response.body);
        throw 'Problem with the get request';
      }
    } catch (e) {
      print('$e error');
      if (e.toString() == 'Connection closed while receiving data') {
        await fetchDangerZones();
      }
    } finally {
      print('done');
      print("danger llist ");
    }
    uploadToFirbase();
    //Todo() call the save lists function and return to usuall
  }

  void _onEnterGeofence() {
    print('Entered geofence');
    //FirebaseMessaging.onBackgroundMessage(backgroundHandler);

    NotificationService.showBigTextNotification(
        title: "لقد دخلت في منطقة خطرة!",
        body: notificationBody,
        fln: flutterLocalNotificationsPlugin);
  }

  void _onExitGeofence() {
    print('Exited geofence');
    NotificationService.showBigTextNotification(
        title: "أنت في أمان!",
        body: "لقد خرجت من منطقة الخطر",
        fln: flutterLocalNotificationsPlugin);
  }

  void getList() {
    dangerZonesData.forEach((element) {
      print("dang " + element['id'].toString());
    });
    polygons.forEach((element) {
      print("poly " + element.polygonId.value.toString());
      // print(element.points.toList().first.toJson());
    });
    circles.forEach((element) {
      print("cicle " + element.circleId.value.toString());
      // print(element.center.toJson().toString());
    });
    print("Minutes is $minutes");
    if (historyList.isEmpty) print("empty history");
    for (var item in historyList) {
      print("the id is ${item['id']} and the position is ${item['position']}");
    }
  }

  Future<void> clear(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
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
    setState(() {
      historyList.clear();
    });
    const snackBar = SnackBar(
      content: Text('!تم مسح جميع مناطق الخطر', textAlign: TextAlign.right),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
                  title: const Text("تأكيد الحذف"),
                  content: const Text(
                      "هل أنت متأكد أنك تريد حذف سجل مناطق الخطر الخاص بك؟"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء"),
                    ),
                    TextButton(
                      onPressed: () {
                        clear(context);
                        Navigator.pop(context);
                      },
                      child: const Text("حذف "),
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
                    title: const Text('تغيير وقت جلب البيانات',textAlign: TextAlign.right,),
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
                            child: Text("إلغاء"),
                          ),
                          TextButton(
                            onPressed: () {
                              saveMinutes();
                              print(minutes);
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
          // IconButton(
          //   icon: const Icon(Icons.update),
          //   onPressed: () => getList(),
          // ),
          // IconButton(
          //     onPressed: loadDataToListFromBase, icon: Icon(Icons.save_alt)),
          // IconButton(onPressed: uploadToFirbase, icon: Icon(Icons.upload)),
          // IconButton(
          //     onPressed: deleteDocuments, icon: Icon(Icons.delete_sweep)),
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
                    "أنت في أمان " + "\n !" + "لم تدخل أي منطقة خطرة",
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
