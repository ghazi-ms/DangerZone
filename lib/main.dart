import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:updated_grad/local_notifications.dart';
import 'notification_service.dart';


List<String> list = <String>['31.7983,35.9326', '32.0235,35.8762', '31.8734,35.8873', '31.9039,35.8669'];

Future<void> backgroundHandler(RemoteMessage message) async {
  print("This is message form background");
  print(message.notification?.title);
  print(message.notification?.body);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  runApp(GeofenceMap());
}

class GeofenceMap extends StatefulWidget {
  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}

class _GeofenceMapState extends State<GeofenceMap> {
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final coor = TextEditingController();
  LatLng _center = LatLng(31.872378, 35.885011);
  Set<Circle> _circles = {};
  Set<Polygon> _polygons = {};
  late GeolocatorPlatform _geolocator;
  bool _isInsideGeofence = false;

  @override
  void initState() {
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
    // Check if we have permission to access the user's location
    LocationPermission permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Permission denied to access location');
      return;
    }

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
    bool isInsidePolygon = false;
    if(_polygons.isEmpty)
      return false;
    for(var i in _polygons){
      List<maps_toolkit.LatLng> polygonLatLngs = i.points
          .map((point) => maps_toolkit.LatLng(point.latitude, point.longitude))
          .toList();
      maps_toolkit.LatLng positionLatLng =
      maps_toolkit.LatLng(position.latitude, position.longitude);
      isInsidePolygon = maps_toolkit.PolygonUtil.isLocationOnEdge(
          positionLatLng, polygonLatLngs, tolerance: 100, true);
    }


    return isInsidePolygon;
  }
  bool _isPositionInsideCircle(Position position){
    if (!_circles.isEmpty) {
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
        title: "Geofence",
        body: "Danger!!",
        fln: flutterLocalNotificationsPlugin);
  }

  void _onExitGeofence() {
    print('Exited geofence');
    // TODO: Handle exit geofence event
    NotificationService.showBigTextNotification(
        title: "Exit", body: "Danger!!", fln: flutterLocalNotificationsPlugin);
  }

  void changeDrop() {
    print("called");
    setState(() {
      final data = dropdownValue.toString().split(",");
      _center = LatLng(double.parse(data[0]), double.parse(data[1]));
      Circle c = Circle(
        circleId: CircleId(Time().second.toString()),
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

    if (coor.text =="") {
      list.add(coor.text);
      setState(() {
        final data = coor.toString().split(",");

        _center = LatLng(double.parse(data[0]), double.parse(data[1]));
        Circle c = Circle(
          circleId: CircleId(Time().second.toString()),
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

    // _polygons.add(Polygon(
    //   polygonId: PolygonId('Geofence'),
    //   points: [
    //     LatLng(31.9397339197085, 35.8867618197085),
    //     LatLng(31.9424318802915, 35.8894597802915),
    //   ],
    //   fillColor: Colors.blue.withOpacity(0.5),
    //   strokeColor: Colors.blue,
    // ));

    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: Text('Geofence Map'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _circles.isEmpty ? Text("Empty") :
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
            ElevatedButton(onPressed: add, child: Text("Add"))
          ],
        ),
      ),
    ));
  }
}
