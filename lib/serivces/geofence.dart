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
    loadDataToListFromBase();
    WidgetsBinding.instance.addObserver(this);
    startTimerList();
    loadData().then((_) {
      fetchDangerZones();
      LocalNotificationService.initilize();
      fetchingLocation();

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
  void checkListInAnotherFunction(){
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
//From Database
  Future<void> loadDataToListFromBase() async {

    QuerySnapshot querySnapshot ;
    querySnapshot= await dangerZonesRef
        .doc(deviceId)
        .collection('historyList')
        .get();
    //Data checks if it contains duplicates
    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;
      if (!checkListsforDuplicates(historyList, x['id'])) {
        historyList.add({'id': x['id'], 'position': x['position']});
      }
    });
    querySnapshot = await dangerZonesRef
        .doc(deviceId)
        .collection('dangerZonesData')
        .get();
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

    querySnapshot = await dangerZonesRef
        .doc(deviceId)
        .collection('circles')
        .get();
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
    querySnapshot = await dangerZonesRef
        .doc(deviceId)
        .collection('polygons')
        .get();
    querySnapshot.docs.forEach((element) {
      Map x = element.data() as Map;
      if (!checkDuplicatesPolygon(polygons, x['polygonId'])) {
        List<dynamic> coordinates = jsonDecode(x['coordinates']);
        List<LatLng> latLngList = coordinates.map((coord) =>
            LatLng(
              coord[0] as double, // latitude
              coord[1] as double, // longitude
            )).toList();

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

    const apiEndpoint = "http://172.20.10.6:5000";
    // 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';
    final response = await get(Uri.parse(apiEndpoint));
    if (response.statusCode == 200) {
      try {

        final data = json.decode(response.body);
        dangerZonesData.addAll(data);
        print(data[0]['id']);
        for (int i = 0; i < data.length; i++) {
          // dangerZonesData to firebase
          dangerZonesRef
              .doc(deviceId.toString())
              .collection('dangerZonesData')
              .get()
              .then((QuerySnapshot querySnapshot) {
            bool idExists = false;
            querySnapshot.docs.forEach((doc) {
              if (doc['id'].toString() == data[i]['id'].toString()) {
                idExists = true;
              }
            });
            if (!idExists) {
              dangerZonesRef
                  .doc(deviceId.toString())
                  .collection('dangerZonesData')
                  .add({
                'Coordinates': data[i]['Coordinates'].toString(),
                'title': data[i]['title'].toString(),
                'description': data[i]['description'].toString(),
                'id': data[i]['id'].toString(),
                'timeStamp': data[i]['timeStamp'].toString(),
                'Locations': data[i]['Locations'].toString()
              });
            }
          }).catchError((error) => print('Error getting documents: $error'));

          if (data[i]['Coordinates'].length > 2) {
            dangerZonesRef
                .doc(deviceId.toString())
                .collection('polygons')
                .get()
                .then((QuerySnapshot querySnapshot) {
              bool idExists = false;
              querySnapshot.docs.forEach((doc) {
                if (doc['polygonId'].toString() == data[i]['id'].toString()) {
                  idExists = true;
                }
              });
              if (!idExists) {
                dangerZonesRef
                    .doc(deviceId.toString())
                    .collection('polygons')
                    .add({
                  'polygonId': data[i]['id'].toString(),
                  'coordinates': data[i]['Coordinates'].toString(),

                });
              }
            }).catchError((error) => print('Error getting documents: $error'));
          } else {
            dangerZonesRef
                .doc(deviceId.toString())
                .collection('circles')
                .get()
                .then((QuerySnapshot querySnapshot) {
              bool idExists = false;
              querySnapshot.docs.forEach((doc) {
                if (doc['circleId'].toString() == data[i]['id'].toString()) {
                  idExists = true;
                }
              });
              if (!idExists) {
                final List<dynamic> coordinates = data[i]['Coordinates'];
                dangerZonesRef
                    .doc(deviceId.toString())
                    .collection('circles')
                    .add({
                  'circleId': data[i]['id'].toString(),
                  'center': coordinates.toString(),
                  'radius': '100',
                });
              }
            }).catchError((error) => print('Error getting documents: $error'));
          }
        }

        //------------------------------------------------------------------


      } catch (e) {
        print('$e error');
        if (e.toString() == 'Connection closed while receiving data') {
          await fetchDangerZones();
        }
      } finally {
        print('done');
        print("danger llist ");
      }
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Data Received !')),
      );
      loadDataToListFromBase();
    } else {
      print(response.body);
      throw 'Problem with the get request';
    }
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
    dangerZonesData.forEach((element) {
      print(element);
    });
    dangerGeofences.forEach((element) {
      print(element);
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
          IconButton(onPressed: loadData, icon: Icon(Icons.upload)),
          IconButton(onPressed: checkListInAnotherFunction, icon: Icon(Icons.abc_sharp)), //To check the 4 lists if there any duplicates (Just testing bro:) }
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
