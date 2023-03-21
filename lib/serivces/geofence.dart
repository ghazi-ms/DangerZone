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

class GeofenceMap extends StatefulWidget {
  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}
List<String> list = <String>['31.7983,35.9326', '32.0235,35.8762', '31.8734,35.8873', '31.9039,35.8669'];

class _GeofenceMapState extends State<GeofenceMap> {
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final coor = TextEditingController();
  LatLng _center = const LatLng(31.872378, 35.885011);
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
  bool _isPositionIsidePolygon(Position position){
    // Check if the position is inside the polygon
    print("polygon called");
    bool isInsidePolygon = false;
    if(_polygons.isEmpty) {
      print("polygon False");
      print(_polygons.length);
      return false;
    }
    for(var i in _polygons){
      List<maps_toolkit.LatLng> polygonLatLngs = i.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();
      maps_toolkit.LatLng positionLatLng =
      maps_toolkit.LatLng(position.latitude, position.longitude);
      isInsidePolygon = maps_toolkit.PolygonUtil.isLocationOnEdge(
          positionLatLng, polygonLatLngs, tolerance: 100, true);
    }

    print("polygon :"+isInsidePolygon.toString());

    return isInsidePolygon;
  }
  bool _isPositionInsideCircle(Position position){
    if (_circles.isNotEmpty) {
      for (var c in _circles) {
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

    if(_isPositionInsideCircle(position)){
      return true;
    }else if (_isPositionIsidePolygon(position)){
      return true;
    }else{
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
  void changeDrop() {
    print("called");
    setState(() {
      final data = dropdownValue.toString().split(",");
      _center = LatLng(double.parse(data[0]), double.parse(data[1]));
      Circle c = Circle(
        circleId: CircleId(const Time().second.toString()),
        center: _center,
        radius: 200,
        fillColor: Colors.red.withOpacity(0.5),
        strokeColor: Colors.red,
      );
      if(_circles.contains(c)){
        print("contains");
      }else{
        _circles.add(c);
      }

    });
    print(_circles.length);

  }

  void add() {
    print("called");
    setState(() {
      _polygons.add(Polygon(
        polygonId: PolygonId(const Time().second.toString()),
        points: [
          LatLng(31.8288, 35.9010),
          LatLng(31.8274, 35.8973),
          LatLng(31.8236, 35.8999),
          LatLng(31.8263, 35.9048),
        ],
        fillColor: Colors.blue.withOpacity(0.5),
        strokeColor: Colors.blue,
      ));

      _polygons.add(Polygon(
        polygonId: PolygonId(const Time().second.toString()),
        points: [
          LatLng(32.0027842, 35.8658503),
          LatLng(32.0317505, 35.8658503),
          LatLng(32.0317505, 35.8876572),
          LatLng(32.0027842, 35.8876572),
        ],
        fillColor: Colors.red.withOpacity(0.5),
        strokeColor: Colors.red,
      ));
    });

    if (coor.text !="") {
      list.add(coor.text);
      setState(() {
        final data = coor.toString().split(",");

        _center = LatLng(double.parse(data[0]), double.parse(data[1]));
        Circle c = Circle(
          circleId: CircleId(const Time().second.toString()),
          center: _center,
          radius: 400,
          fillColor: Colors.red.withOpacity(0.5),
          strokeColor: Colors.red,
        );
        if(_circles.contains(c)){
          print("contains");
        }else{
          _circles.add(c);
        }

      });
    }
    print(_circles.length);

  }

  String dropdownValue = list[0];

@override
  Widget build(BuildContext context) {


    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Map'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _circles.isEmpty ? const Text("Empty") :
            SizedBox(
              height: 400,
              width: 350,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: 16.0,
                ),
                circles: _circles,
                polygons: _polygons,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),

            DropdownButton<String>(
              value: dropdownValue,
              icon: const Icon(Icons.arrow_downward),
              elevation: 16,
              style: const TextStyle(color: Colors.deepPurple),
              underline: Container(
                height: 2,
                color: Colors.deepPurpleAccent,
              ),
              items: list.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? value) {

                // This is called when the user selects an item.
                setState(() {
                  dropdownValue = value!;
                  changeDrop();
                });
              },
            ),
            TextField(
              controller: coor,
            ),
            ElevatedButton(onPressed: add, child: const Text("Add"))
          ],
        ),
      ),
    ));
  }
}
