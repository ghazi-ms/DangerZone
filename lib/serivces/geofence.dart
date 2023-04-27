import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:location/location.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:updated_grad/local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../notification_service.dart';
import '../widgets/cards.dart';

class GeofenceMap extends StatefulWidget {
  const GeofenceMap({super.key});

  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

List<String> list = <String>[
  '31.7983,35.9326',
  '32.0235,35.8762',
  '31.8734,35.8873',
  '31.9039,35.8669'
];
List<String> historyList = <String>[];
List<dynamic> dangerZoneDataList = [''];

class _GeofenceMapState extends State<GeofenceMap> {
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final coor = TextEditingController();
  final testingText = TextEditingController();

  String firstCentre = list.first;
  late LatLng center;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};
  late GeolocatorPlatform _geolocator;
  bool _isInsideGeofence = false;
  var geolocator;
  final distanceFilter = 50;

  @override
  void initState() {
    super.initState();
    LocalNotificationService.initilize();
    _geolocator = GeolocatorPlatform.instance;
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
        } else {
          _onExitGeofence();
        }
      }
    });
  }

  bool _isPositionInsideGeofence(currentLatitude, currentLongitude) {
    print(' $currentLatitude, $currentLongitude');
    // Check if the position is inside the circle
    for (Circle circle in circles) {
      double distance = Geolocator.distanceBetween(
        currentLatitude,
        currentLongitude,
        circle.center.latitude,
        circle.center.longitude,
      );
      if (distance <= 100) {
        if (!historyList
            .contains(circle.circleId.toString().substring(9, 19))) {
          setState(() {
            print("enttt");
            print(circle.circleId.toString());
            // historyList.add([circle.circleId.toString().substring(10,20),position.toString()] as String);
            historyList.add(circle.circleId.toString().substring(9, 19));
          });
        }
        return true;
      }
    }

    // Check if the position is inside the polygon
    bool isInsidePolygon = false;

    for (Polygon polygon in polygons) {
      List<maps_toolkit.LatLng> polygonLatLngs = polygon.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();
      maps_toolkit.LatLng positionLatLng =
          maps_toolkit.LatLng(currentLatitude, currentLongitude);

      bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
          positionLatLng, polygonLatLngs, true);

      bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
          positionLatLng, polygonLatLngs, tolerance: 100, true);

      if ((isInsidePolygon == false && allowedDistance == true) ||
          isInsidePolygon == true) {
        if (!historyList
            .contains(polygon.polygonId.toString().substring(10, 20))) {
          setState(() {
            print(polygon.polygonId.toString());
            // historyList.add([polygon.polygonId.toString().substring(10,20),position.toString()] as String);
            historyList.add(polygon.polygonId.toString().substring(10, 20));
          });
        }
        return true;
      }
    }
    return isInsidePolygon;
  }

  Future<void> fetchDangerZones() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Getting new danger zones')),
    );

    const apiEndpoint = 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';

    try {
      final response = await get(Uri.parse(apiEndpoint));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Data Received !')),
        );
        setState(() {
          dangerZoneDataList = data;
        });

        final polygonsTemp = <Polygon>{};

        for (final item in dangerZoneDataList) {
          final coordinates = item['Coordinates'];
          final points = <LatLng>[];
          print('$item----$coordinates');

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
                print('added ${item['id']}');
                polygons.add(Polygon(
                  polygonId: PolygonId(item['id']),
                  points: points,
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                ));
              });
            } else {
              for (final polygon in polygons) {
                if (polygon.polygonId != item['id']  ) { // Todo () make it on title
                  setState(() {
                    polygonsTemp.add(Polygon(
                      polygonId: PolygonId(item['id']),
                      points: points,
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
                circleId: CircleId(item['id']),
                center: LatLng(
                    double.parse(coordinates.first[0].toString()),
                    double.parse(coordinates.first[1].toString())),
                radius: 100,
                fillColor: Colors.blue.withOpacity(0.5),
                strokeColor: Colors.blue,
              ));
              print('added circle');
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
    }

    print('done');
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
    print("object");
    for (Polygon p in polygons) {
      print(p.polygonId.toString().substring(10, 20));
      print(" maps id${p.mapsId}");
      print(" pol id${p.polygonId}");
      print(" points${p.points}");
    }
    for (Circle c in circles) {
      print("circle");
      print(c.mapsId);
      print(c.circleId);
      print(c);
    }
    if (historyList.isEmpty) print("empty");
    for (var i in historyList) {
      print("${i}his");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        AppBar().preferredSize.height -
        MediaQuery.of(context).padding.bottom -
        (kBottomNavigationBarHeight);
    final screenWidth = MediaQuery.of(context).size.width;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => fetchDangerZones(),
          ),
        ],
        backgroundColor: Colors.red,
        title: const Text('Danger Zone'),
      ),
      body: historyList.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Center(
                    child: Text(
                  "You are Safe ! \n you didn't enter any danger zones",
                  style: TextStyle(
                    fontSize: 25,
                  ),
                  textAlign: TextAlign.center,
                ))
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Cards(historyList, dangerZoneDataList),
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

  void clear() {
    setState(() {
      historyList = [];
      notificationMSG = '';
      polygons.clear();
      circles.clear();
    });
  }

  void getText() {
    setState(() {
      if (!historyList.contains(testingText.text)) {
        historyList.add(testingText.text);
        print("added${testingText.text}");
      }
    });
  }
}
