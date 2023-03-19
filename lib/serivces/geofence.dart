import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:updated_grad/local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../main.dart';
import '../notification_service.dart';
import 'location_permission.dart';

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.

class GeofenceMap extends StatefulWidget {
  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

class _GeofenceMapState extends State<GeofenceMap> {
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final LatLng _center = const LatLng(31.872378, 35.885011);
  Set<Circle> _circles = {};
  Set<Polygon> _polygons = {};
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

  bool _isPositionInsideGeofence(Position position) {
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _center.latitude,
      _center.longitude,
    );

    // Check if the position is inside the circle
    if (distance <= 100) {
      return true;
    }

    // Check if the position is inside the polygon
    List<maps_toolkit.LatLng> polygonLatLngs = _polygons.first.points
        .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
        .toList();
    maps_toolkit.LatLng positionLatLng =
        maps_toolkit.LatLng(position.latitude, position.longitude);
    bool isInsidePolygon = maps_toolkit.PolygonUtil.isLocationOnEdge(
        positionLatLng, polygonLatLngs, tolerance: 100, true);

    return isInsidePolygon;
  }

  void _onEnterGeofence() {
    print('Entered geofence');
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
    // TODO: Handle enter geofence event
    NotificationService.showBigTextNotification(
        title: "Geofence",
        body: "Danger!!",
        fln: flutterLocalNotificationsPlugin);
  }

  void _onExitGeofence() {
    print('Exited geofence');
    // TODO: Handle exit geofence event
  }

  @override
  Widget build(BuildContext context) {
    _circles.add(Circle(
      circleId: CircleId('Geofence'),
      center: _center,
      radius: 100,
      fillColor: Colors.blue.withOpacity(0.5),
      strokeColor: Colors.blue,
    ));

    _polygons.add(Polygon(
      polygonId: PolygonId('Geofence'),
      points: [
        LatLng(32.0027842, 35.8658503),
        LatLng(32.0317505, 35.8658503),
        LatLng(32.0317505, 35.8876572),
        LatLng(32.0027842, 35.8876572),
      ],
      fillColor: Colors.blue.withOpacity(0.5),
      strokeColor: Colors.blue,
    ));

    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: Text('Geofence Map'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 16.0,
        ),
        circles: _circles,
        polygons: _polygons,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    ));
  }
}
