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

class GeofenceMap extends StatefulWidget {
  const GeofenceMap({super.key});

  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

List<Map<String, String>> historyList = [];

List<dynamic> dangerGeofences = [''];
final List<dynamic> dangerZonesData = [];

class _GeofenceMapState extends State<GeofenceMap> with WidgetsBindingObserver {
  var dangerZonesRef;
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
    print("after $Minutes");
    var SecondsServer = Duration(minutes: Minutes);
    _timerServer = Timer.periodic(
      SecondsServer,
      (Timer timer) => callServerFunction(),
    );
  }

  Future<void> saveData() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.remove("Minutes");
    prefs.setInt("Minutes", Minutes);
    print("saved $Minutes");
  }

  Future<void> loadData(BuildContext context) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      if (prefs.getInt("Minutes") != null) {
        setState(() {
          Minutes = prefs.getInt("Minutes")!;
        });
      } else {
        print("Null");
        setState(() {
          Minutes = 15;
        });
      }
      var snackBar = SnackBar(
        content: Text('loaded $Minutes'),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      print("loaded $Minutes");
    } catch (e) {
      print("Error loading data: $e");
    }
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

  @override
  void dispose() {
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

  @override
  void initState() {
    super.initState();
    loadData(context);
    DeviceInfo();
    dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
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
    QuerySnapshot querySnapshot =
        await dangerZonesRef.doc(deviceId).collection('kk').get();
    await loadCircles();
    await loadDangerZonesData();
    await loadPolygons();
    await loadHistoryList();
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
        newHistoryList.add({
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
      historyList.addAll(newHistoryList);
    });
  }

  Future<void> fetchDangerZones() async {
    loadDataToListFromBase();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Getting new danger zones')),
    );

    // const apiEndpoint = "http://192.168.0.108:5000";
    const apiEndpoint = "http://192.168.1.21:5000";

    // 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';

    try {
      final response =
          await get(Uri.parse(apiEndpoint)).timeout(const Duration(minutes: 2));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Data Received !')),
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
        /*setState(() {
          dangerZonesData.addAll(data);
        });*/

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
    print("Minutes is $Minutes");
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
              await showDialog<void>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('change fetching time'),
                    children: <Widget>[
                      Container(
                        alignment: Alignment.center,
                        width: 200,
                        height: 70,
                        child: NumberSelection(
                          theme: NumberSelectionTheme(
                              draggableCircleColor: Colors.pinkAccent,
                              iconsColor: Colors.white,
                              numberColor: Colors.white,
                              backgroundColor: Colors.red,
                              outOfConstraintsColor: Colors.deepOrange),
                          initialValue: Minutes,
                          minValue: 1,
                          maxValue: 60,
                          direction: Axis.horizontal,
                          withSpring: true,
                          onChanged: (int value) {
                            Minutes = value;
                          },
                          enableOnOutOfConstraintsAnimation: true,
                          onOutOfConstraints: () =>
                              print("This value is too high or too low"),
                        ),
                      ),
                      TextButton(
                          onPressed: () {
                            saveData();
                            print(Minutes);
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            "Done",
                            style: TextStyle(
                              fontSize: 25,
                            ),
                          ))
                    ],
                  );
                },
              );
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
        children: [Cards(historyList, dangerZonesData, deviceId)],
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
