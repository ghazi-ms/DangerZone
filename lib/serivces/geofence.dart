import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:updated_grad/local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import '../notification_service.dart';
import 'location_permission.dart';
import 'MainLayout.dart';

class GeofenceMap extends StatefulWidget {
  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

List<String> list = <String>[
  '31.7983,35.9326',
  '32.0235,35.8762',
  '31.8734,35.8873',
  '31.9039,35.8669'
];

class _GeofenceMapState extends State<GeofenceMap> {
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final coor = TextEditingController();

  String firstCentre = list.first;
  late LatLng center;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};
  late GeolocatorPlatform _geolocator;
  bool _isInsideGeofence = false;

  @override
  void initState() {
    determinePosition();
    LocalNotificationService.initilize();
    super.initState();
    _geolocator = GeolocatorPlatform.instance;
    _initGeofencing();

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

  void _initGeofencing() async {
    // Subscribe to location updates
    _geolocator.getPositionStream().listen((position) {
      bool isInsideGeofence = _isPositionInsideGeofence(position);
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

  bool _isPositionIsidePolygon(Position position) {
    // Check if the position is inside the polygon

    bool isInsidePolygon = false;

    if (polygons.isEmpty) {

      return false;
    }
    for (var i in polygons) {
      List<maps_toolkit.LatLng> polygonLatLngs = i.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();

      for (int i = 0; i < polygonLatLngs.length; i++) {
        maps_toolkit.LatLng positionLatLng =
            maps_toolkit.LatLng(position.latitude, position.longitude);
        isInsidePolygon = maps_toolkit.PolygonUtil.isLocationOnEdge(
            positionLatLng,
            polygonLatLngs[i] as List<maps_toolkit.LatLng>,
            tolerance: 1000,
            true);
      }
    }



    return isInsidePolygon;
  }

  bool _isPositionInsideCircle(Position position) {

    if (circles.isNotEmpty) {
      for (var c in circles) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          c.center.latitude,
          c.center.longitude,
        );

        // Check if the position is inside the circle
        if (distance <= 100) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isPositionInsideGeofence(Position position) {
    if (_isPositionInsideCircle(position)) {
      return true;
    } else if (_isPositionIsidePolygon(position)) {
      return true;
    } else {
      return false;
    }
  }

  void _onEnterGeofence() {
    print('Entered geofence');
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
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

  @override
  Widget build(BuildContext context) {
    center = LatLng(double.parse(firstCentre[0]), double.parse(firstCentre[1]));

    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Map'),
      ),
      body:MainLayout(coor, center, circles, polygons, list)

      ),
    );
  }
}
