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
import 'package:numberpicker/numberpicker.dart';

class GeofenceMap extends StatefulWidget {
  const GeofenceMap({super.key});

  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

List<Map<String, String>> historyList = [];

List<dynamic> dangerGeofences = [''];
final List<dynamic> dangerZonesData = [];

class _GeofenceMapState extends State<GeofenceMap> with WidgetsBindingObserver {
  var dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late LatLng center;
  String? deviceId;
  bool _isInsideGeofence = false;
  final distanceFilter = 50;
  static const int tolerance = 100;
  int Minutes = 15;
  late Timer _timerServer;
  late Timer _timerList;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};

  void startTimerServer() {
    const SecondsServer = const Duration(minutes: 15);
    _timerServer = new Timer.periodic(
      SecondsServer,
      (Timer timer) => callServerFunction(),
    );
  }

  void callServerFunction() {
    // Perform network request
    fetchDangerZones();
  }

  void cancelTimerServer() {
    _timerServer.cancel();
  }

  void startTimerList() {
    const SecondsList = const Duration(hours: 24);
    _timerList = new Timer.periodic(
      SecondsList,
      (Timer timer) => callListFunction(),
    );
  }

  void callListFunction() {
    // clear newsfeed list
    deleteAllDocuments('dangerZones');
    historyList.clear();
    dangerGeofences.clear();
    dangerZonesData.clear();
  }

  void cancelTimerList() {
    _timerList.cancel();
  }

  Future<void> deleteAllDocuments(String collectionPath) async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection(collectionPath).get();
    final List<Future<void>> futures = [];

    for (final DocumentSnapshot doc in snapshot.docs) {
      futures.add(doc.reference.delete());
    }

    await Future.wait(futures);
  }

  void saveData() {}

  Future<void> loadData() async {}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    saveData();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      saveData();
    }
  }

  Future<void> DeviceInfo() async {
    deviceId = await PlatformDeviceId.getDeviceId;
    print(deviceId);
  }

  @override
  void initState() {
    super.initState();
    DeviceInfo();
    saveData();
    WidgetsBinding.instance.addObserver(this);
    startTimerList();
    LocalNotificationService.initilize();
    NotificationService.initialize(flutterLocalNotificationsPlugin);
    //////////

    // terminated state
    FirebaseMessaging.instance.getInitialMessage().then((event) {});

    // foreground state
    FirebaseMessaging.onMessage.listen((event) {
      LocalNotificationService.showNotificationOnForeground(event);
    });

    // background state
    FirebaseMessaging.onMessageOpenedApp.listen((event) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchDangerZones();
    });

    fetchingLocation();
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
    /*
    for (var geofence in dangerGeofences) {
      // Check if the position is inside a circle geofence
      if (geofence is Circle) {
        Circle circle = geofence;
        double distanceToCenter = Geolocator.distanceBetween(
          currentLatitude,
          currentLongitude,
          circle.center.latitude,
          circle.center.longitude,
        );
        if (distanceToCenter <= circle.radius) {
          // Record the geofence entry in the history list
          if (!historyList
              .any((entry) => entry['id'] == circle.circleId.value)) {
            setState(() {
              historyList.add({
                'id': circle.circleId.value,
                'position': '$currentLatitude,$currentLongitude'.toString()
              });
            });
          }
          return true;
        }
      }
      // Check if the position is inside a polygon geofence
      else if (geofence is Polygon) {
        Polygon polygon = geofence;
        List<maps_toolkit.LatLng> polygonLatLngs = polygon.points
            .map(
                (point) => maps_toolkit.LatLng(point.latitude, point.longitude))
            .toList();
        maps_toolkit.LatLng positionLatLng =
        maps_toolkit.LatLng(currentLatitude, currentLongitude);

        bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
            positionLatLng, polygonLatLngs, true);

        bool isCloseToEdge = maps_toolkit.PolygonUtil.isLocationOnEdge(
            positionLatLng, polygonLatLngs, tolerance: tolerance, true);

        if ((isInsidePolygon == false && isCloseToEdge == true) ||
            isInsidePolygon == true) {
          // Record the geofence entry in the history list
          if (!historyList
              .any((entry) => entry['id'] == polygon.polygonId.value)) {
            setState(() {
              historyList.add({
                'id': polygon.polygonId.value,
                'position': '$currentLatitude,$currentLongitude'.toString()
              });
            });
          }
          return true;
        }
      }
    }
    return false;
    */

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
          });
        }
        return true;
      }
    }
    return false;
  }

  ///For debugging and checking the list for duplicates from the database
  void checkListInAnotherFunction() {
    print("History list after getting data from database: ${historyList}");
    print("Danger Zone Data after getting data from database:");
    dangerZonesData.forEach((element) {
      print(element['id']);
    });
    print("Circle List check ===> ");
    circles.forEach((element) {
      print(element.circleId);
    });
    print("Polygon List check ==>");

    polygons.forEach((element) {
      print(element.polygonId);
    });
  }

  ///Danger and history list Id check for duplicates
  bool checkListsforDuplicates(List<dynamic> list, dynamic id) {
    for (var item in list) {
      if (item['id'] == id) {
        return true;
      }
    }
    return false;
  }

  ///Circle ID check for duplicates
  bool checkDuplicatesCircle(Set<Circle> set, dynamic id) {
    for (var item in set) {
      if (item.circleId == id) {
        return true;
      }
    }
    return false;
  }

  ///Polygon ID check for duplicates
  bool checkDuplicatesPolygon(Set<Polygon> set, dynamic id) {
    for (var item in set) {
      if (item.polygonId == id) {
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

        if (!existingIds.contains(dangerZonesData[i]['id'].toString())) {
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
          if (!existingPolygonIds.contains(polygon.polygonId.toString())) {
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
      }
      final existingCircleIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['circleId'].toString()));
      for (var circle in circles) {
        if (!existingCircleIds.contains(circle.circleId.toString())) {
          dangerZonesRef.doc(deviceId.toString()).collection('circles').add({
            'circleId': circle.circleId.value.toString(),
            'center': circle.center.toJson().toString(),
            'radius': circle.radius.toString(),
          });
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
    QuerySnapshot querySnapshot;
    querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('historyList').get();
    //Data checks if it contains duplicates
    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;
      if (!checkListsforDuplicates(historyList, x['id'])) {
        historyList.add({'id': x['id'], 'position': x['position']});
      }
    });
    querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('dangerZonesData').get();
    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;
      if (!checkListsforDuplicates(dangerZonesData, x['id'])) {
        dangerZonesData.add({
          'Coordinates': x['Coordinates'],
          'Locations': x['Locations'],
          'description': x['description'],
          'id': x['id'],
          'timeStamp': x['timeStamp'],
          'title': x['title'],
        });
      }
    });

    querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('circles').get();
    querySnapshot.docs.forEach((element) {
      print(element.data());
      Map x = element.data() as Map;
      if (!checkDuplicatesCircle(circles, x['circleId'])) {
        List<dynamic> center = jsonDecode(x['center']);
        List<List<double>> coordinatesList =
            center.map((coord) => List<double>.from(coord)).toList();
        double latitude = coordinatesList[0][0];
        double longitude = coordinatesList[0][1];
        Circle tempCircle = Circle(
          circleId: CircleId(x['circleId'].toString()),
          center: LatLng(latitude, longitude),
          radius: double.parse(x['radius'].toString()),
        );
        setState(() {
          circles.add(tempCircle);
        });
      }
    });
    querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('polygons').get();
    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;
      if (!checkDuplicatesPolygon(polygons, x['polygonId'])) {
        List<dynamic> coordinates = jsonDecode(x['coordinates']);
        List<LatLng> latLngList = coordinates
            .map((coord) => LatLng(
                  coord[0] as double, // latitude
                  coord[1] as double, // longitude
                ))
            .toList();

        Polygon temppoly = Polygon(
          polygonId: PolygonId(x['polygonId']),
          points: latLngList,
        );
        setState(() {
          polygons.add(temppoly);
        });
      }
    });
  }

  Future<void> fetchDangerZones() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Getting new danger zones')),
    );

    const apiEndpoint = "http://192.168.0.108:5000";
    // 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';

    try {
      final response = await get(Uri.parse(apiEndpoint));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Data Received !')),
        );
        setState(() {
          dangerZonesData.addAll(data);
        });

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
                if (polygon.polygonId != item['id']) {
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
        uploadToFirbase();
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
    loadDataToListFromBase();

    //Todo() call the save lists function and return to usuall
  }

  void _onEnterGeofence() {
    print('Entered geofence');
    //FirebaseMessaging.onBackgroundMessage(backgroundHandler);
    // TODO: Handle enter geofence event
    NotificationService.showBigTextNotification(
        title: "Danger!",
        body: "You have entered a geofence danger",
        fln: flutterLocalNotificationsPlugin);
  }

  void _onExitGeofence() {
    print('Exited geofence');
    // TODO: Handle exit geofence event
    NotificationService.showBigTextNotification(
        title: "Safe",
        body: "Exited Danger",
        fln: flutterLocalNotificationsPlugin);
  }

  void getList() {
    // dangerZonesData.forEach((element) {
    //   print(element);
    // });
    polygons.forEach((element) {
      print(element.polygonId.value.toString());
      print(element.points.toList().first.toJson());
    });
    circles.forEach((element) {
      print(element.circleId.value.toString());
      print(element.center.toJson().toString());
    });
    if (historyList.isEmpty) print("empty history");
    for (var item in historyList) {
      print("the id is ${item['id']} and the position is ${item['position']}");
    }
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
            tooltip: 'Delete All Danger Zones',
            onPressed: () => showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Confirm Delete"),
                  content: const Text(
                      "Are you sure you want to delete your danger zones history?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        clear(context);
                        Navigator.pop(context);
                      },
                      child: const Text("Delete"),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Change When to check for new news',
            onPressed: () async {
              int? selectedMinutes = await showDialog<int>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Select Minutes'),
                    content: NumberPicker(
                      value: Minutes,
                      minValue: 1,
                      maxValue: 60,
                      onChanged: (newValue) {
                        setState(() {
                          Minutes = newValue;
                        });
                      },
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.of(context).pop(Minutes);
                        },
                      ),
                    ],
                  );
                },
              );
              if (selectedMinutes != null) {
                // do something with selectedMinutes
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.update),
            onPressed: () => getList(),
          ),
          IconButton(
              onPressed: loadDataToListFromBase, icon: Icon(Icons.save_alt)),
          IconButton(onPressed: uploadToFirbase, icon: Icon(Icons.upload)),
          IconButton(
              onPressed: checkListInAnotherFunction,
              icon: Icon(Icons.abc_sharp)),
          //To check the 4 lists if there any duplicates (Just testing bro:) }
        ],
        backgroundColor: Colors.red,
        title: const Text('Danger Zone'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Cards(historyList, dangerZonesData, deviceId),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: FloatingActionButton(
          backgroundColor: Colors.red,
          child: const Icon(Icons.refresh),
          onPressed: () => fetchDangerZones(),
        ),
      ),
    );
  }

  Future<void> clear(BuildContext context) async {
    setState(() {
      historyList.clear();
      notificationMSG = '';
      dangerGeofences.clear();
      dangerZonesData.clear();
    });
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.clear();
    const snackBar = SnackBar(
      content: Text('history cleared !'),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
