import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:updated_grad/local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import '../notification_service.dart';
import '../widgets/cards.dart';
import 'location_permission.dart';
import 'package:background_fetch/background_fetch.dart';

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.

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
List<dynamic> dataList = [''];

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
    allowLocationService();
    LocalNotificationService.initilize();
    super.initState();
    _geolocator = GeolocatorPlatform.instance;

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

    BackgroundFetch.registerHeadlessTask(backgroundHandler);

    // Set up the background task
    BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          // minimum time between background fetches
          stopOnTerminate: false,
          // do not stop background fetch when app is terminated
          enableHeadless: true,
          // run task in headless mode
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
        ), (String taskId) async {
      print("[BackgroundFetch] task: $taskId");
      await _getLocationUpdates();

      BackgroundFetch.finish(taskId);
    });
    _getLocationUpdates();
  }

  Future<void> _getLocationUpdates() async {
    geolocator = GeolocatorPlatform.instance;

    geolocator
        .getPositionStream(
            desiredAccuracy: LocationAccuracy.best,
            distanceFilter: distanceFilter)
        .listen((position) {
      // Do something with position data
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
    // Check if the position is inside the circle
    for (Circle circle in circles) {
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        circle.center.latitude,
        circle.center.longitude,
      );
      if (distance <= 100) {
        if (!historyList
            .contains(circle.circleId.toString().substring(10, 20))) {
          setState(() {
            print("enttt");
            print(circle.circleId.toString());
            // historyList.add([circle.circleId.toString().substring(10,20),position.toString()] as String);
            historyList.add(circle.circleId.toString().substring(10, 20));
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
          maps_toolkit.LatLng(position.latitude, position.longitude);

      bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
          positionLatLng, polygonLatLngs, true);

      bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
          positionLatLng, polygonLatLngs, tolerance: 100, true);

      if ((isInsidePolygon == false && allowedDistance == true) ||
          isInsidePolygon == true) {
        if (!historyList
            .contains(polygon.polygonId.toString().substring(10, 20))) {
          setState(() {
            print("enterd this {$position}");
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

  Future getData() async {
    print("start");
    const apiKey = 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';
    try {
      Response response = await get(Uri.parse(apiKey));

      if (response.statusCode == 200) {
        setState(() {
          // print(response.body.isEmpty);
          dataList = json.decode(response.body);
          // if (response.body.isNotEmpty) {
          //   dataList = json.decode(response.body);
          //   // print(dataList.toString());
          // }else{
          //   print("empty");
          //   return;
          // }
        });
        List<dynamic> data = dataList;
        Set<Polygon> polygonsTemp = {};
        for (var item in data) {
          List<dynamic> co = item['Coordinates'];
          // print(item['title'] + "----" + co.toString());
          List<LatLng> po = [];
          if (co.length > 1) {
            print(co.length);
            for (var i in co) {
              po.add(LatLng(double.parse(i[0].toString()),
                  double.parse(i[1].toString())));
            }
            // print(po.toString());
            print("id is:${item['id']} name:${item['title']}");
            if (polygons.isEmpty) {
              setState(() {
                print("added {$item['id']}");
                polygons.add(Polygon(
                  polygonId: PolygonId(item['id']),
                  points: po,
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                ));
              });
            } else {
              for (var i in polygons) {

                if (i.polygonId != item['id']) {
                  setState(() {
                    polygonsTemp.add(Polygon(
                      polygonId: PolygonId(item['id']),
                      points: po,
                      fillColor: Colors.blue.withOpacity(0.5),
                      strokeColor: Colors.blue,
                    ));
                  });
                } else {
                  print("already there");
                }
              }
              polygons.addAll(polygonsTemp);
            }

            po = [];
          } else {
            setState(() {
              circles.add(Circle(
                circleId: CircleId(item['id']),
                center: LatLng(double.parse(co[0]), double.parse(co[1])),
                radius: 100,
                fillColor: Colors.blue.withOpacity(0.5),
                strokeColor: Colors.blue,
              ));
            });
          }
        }
      } else {
        print(response.body);
        throw 'Problem with the get request';
      }
    } catch (e) {
      print("$e error");
      if (e.toString() == 'Connection closed while receiving data') {
        getData();
      }
    }
    // for(var i in polygons){
    //   print(i.mapsId);
    // }
    print("done");
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

  Future<void> reDirectToMaps(List<String> title) async {
    MapsLauncher.launchQuery('$title');
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,

    ]);
    return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.red,
            title: const Text('Danger Zone'),
          ),
          body: Column(
            children: [
              Container(//maybe not needed
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height*0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    //send history
                    // MainLayout(coor, center, circles, polygons, list),
                    Row(
                      children: [
                        historyList.isEmpty
                            ? const Text("You are Safe")
                            : Cards(historyList, dataList),
                      ],
                    ),



                  ],
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height*0.10,
                child: Row(
                  children: [
                    ElevatedButton(onPressed: getData, child: const Text("get Data")),
                    ElevatedButton(onPressed: getList, child: const Text("get list")),
                    ElevatedButton(onPressed: getText, child: const Text("add")),
                    ElevatedButton(onPressed: clear, child: const Text("clear")),
                  ],
                ),

              )
            ],
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
