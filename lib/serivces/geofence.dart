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
    dangerZonesRef
        .doc(deviceId.toString())
        .collection('circles')
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        List<dynamic> center = jsonDecode(doc['center']);
        List<List<double>> coordinatesList =
            center.map((coord) => List<double>.from(coord)).toList();
        double latitude = coordinatesList[0][0];
        double longitude = coordinatesList[0][1];

        double distance = Geolocator.distanceBetween(
          currentLatitude,
          currentLongitude,
          latitude,
          longitude,
        );

        if (distance <= 100) {
          dangerZonesRef
              .doc(deviceId.toString())
              .collection('historyList')
              .where('id', isEqualTo: doc['circleId'].toString())
              .get()
              .then((QuerySnapshot querySnapshot) {
            if (querySnapshot.docs.isEmpty) {
              dangerZonesRef
                  .doc(deviceId.toString())
                  .collection('historyList')
                  .add({
                'title': doc['title'].toString(),
                'id': doc['circleId'].toString(),
                'currentLatitude': currentLatitude.toString(),
                'currentLongitude': currentLongitude.toString(),
                'type': 'circle',
              });
            }
          }).catchError((error) => print('Error getting documents: $error'));
        }
      }
    });

    // return true;

    dangerZonesRef
        .doc(deviceId.toString())
        .collection('polygons')
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        List<dynamic> coordinates = jsonDecode(doc['coordinates']);

        List<maps_toolkit.LatLng> polygonLatLngs = coordinates.map((point) {
          double latitude = point[0];
          double longitude = point[1];
          return maps_toolkit.LatLng(latitude, longitude);
        }).toList();

        maps_toolkit.LatLng positionLatLng =
            maps_toolkit.LatLng(currentLatitude, currentLongitude);

        bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
            positionLatLng, polygonLatLngs, true);

        bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
            positionLatLng, polygonLatLngs, tolerance: tolerance, true);

        if ((isInsidePolygon == false && allowedDistance == true) ||
            isInsidePolygon == true) {
          dangerZonesRef
              .doc(deviceId.toString())
              .collection('historyList')
              .where('id', isEqualTo: doc['polygonId'].toString())
              .get()
              .then((QuerySnapshot querySnapshot) {
            if (querySnapshot.docs.isEmpty) {
              dangerZonesRef
                  .doc(deviceId.toString())
                  .collection('historyList')
                  .add({
                'title': doc['title'].toString(),
                'id': doc['polygonId'].toString(),
                'currentLatitude': currentLatitude.toString(),
                'currentLongitude': currentLongitude.toString(),
                'type': 'polygon',
              });
            }
          }).catchError((error) => print('Error getting documents: $error'));
        }
      }
    });

    return false;
  }

  Future<void> fetchDangerZones() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Getting new danger zones')),
    );

    const apiEndpoint = "http://192.168.1.21:5000";
    // 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';

    try {
      final response = await get(Uri.parse(apiEndpoint));
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
                'title': data[i]['title'].toString(),
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
                'title': data[i]['title'].toString(),
                'circleId': data[i]['id'].toString(),
                'center': coordinates.toString(),
                'radius': 100,
              });
            }
          }).catchError((error) => print('Error getting documents: $error'));
        }
      }

      //------------------------------------------------------------------

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Data Received !')),
        );
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
          IconButton(onPressed: saveData, icon: Icon(Icons.save_alt)),
          IconButton(onPressed: loadData, icon: Icon(Icons.upload)),
        ],
        backgroundColor: Colors.red,
        title: const Text('Danger Zone'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
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
