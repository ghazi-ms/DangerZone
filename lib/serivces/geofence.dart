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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:updated_grad/local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../notification_service.dart';
import '../widgets/cards.dart';



class GeofenceMap extends StatefulWidget {
  const GeofenceMap({super.key});

  @override
  _GeofenceMapState createState() => _GeofenceMapState();
}
  List<Map<String, String>> historyList = [];

 List<dynamic> dangerGeofences = [''];
 final List<dynamic>dangerZonesData=[];
class _GeofenceMapState extends State<GeofenceMap> with WidgetsBindingObserver {
  late String notificationMSG;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late LatLng center;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};
  bool _isInsideGeofence = false;
  final distanceFilter = 50;

  Future<void> saveData() async {
    print("saving");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonString = json.encode(historyList);
    print("sad $jsonString");
    await prefs.setString('listItems', jsonString).whenComplete(() => print("done saving"));

  }

  Future<void> loadData() async {
    print("loading");
    // SharedPreferences? prefs = await SharedPreferences.getInstance();
    // print(prefs.getKeys());
    // if (prefs != null) {
    //   String? jsonString = prefs.getString('listItems');
    //   if (jsonString != null) {
    //     List<dynamic> jsonList = jsonDecode(jsonString);
    //     List<Map<String, String>> mapList =
    //     jsonList.map((json) => Map<String, String>.from(json)).toList();
    //     print("mmm $mapList");
    //     setState(() {
    //       historyList=mapList.toList();
    //     });
    //   } else {
    //     print('No data found in SharedPreferences');
    //   }
    // } else {
    //   print('SharedPreferences instance is null');
    // }
  }



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


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
        } else {
          _onExitGeofence();
        }
      }
    });
  }

  bool _isPositionInsideGeofence(currentLatitude, currentLongitude) {
    for (var dangerElement in dangerGeofences) {
      if (dangerElement.runtimeType == Circle) {
        Circle cir=dangerElement;
        double distance = Geolocator.distanceBetween(
          currentLatitude,
          currentLongitude,
          cir.center.latitude,
          cir.center.longitude,
        );
        if (distance <= 100) {
          if (!historyList
              .any((element) => element['id'] == cir.circleId.value)) {
            setState(() {
              historyList.add({
                'id': cir.circleId.value,
                'position': '$currentLatitude,$currentLongitude'.toString()
              });
            });
          }
          return true;
        }
      }
      // Check if the position is inside the polygon
      if (dangerElement.runtimeType == Polygon) {
        Polygon Poly=dangerElement;
        List<maps_toolkit.LatLng> polygonLatLngs = Poly.points
            .map((point) =>
            maps_toolkit.LatLng(point.latitude, point.longitude))
            .toList();
        maps_toolkit.LatLng positionLatLng =
        maps_toolkit.LatLng(currentLatitude, currentLongitude);

        bool isInsidePolygon = maps_toolkit.PolygonUtil.containsLocation(
            positionLatLng, polygonLatLngs, true);

        bool allowedDistance = maps_toolkit.PolygonUtil.isLocationOnEdge(
            positionLatLng, polygonLatLngs,
            tolerance: 100, true);

        if ((isInsidePolygon == false && allowedDistance == true) ||
            isInsidePolygon == true) {
          if (!historyList.any(
                  (element) => element['id'] == Poly.polygonId.value)) {
            setState(() {
              historyList.add({
                'id': Poly.polygonId.value,
                'position': '$currentLatitude,$currentLongitude'.toString()
              });
            });
          }
          return true;
        }
      }
    }
    return false;
  }


  Future<void> fetchDangerZones() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Getting new danger zones')),
    );

    const apiEndpoint = "http://192.168.0.111:5000";
        // 'https://g62j4qvp3h.execute-api.us-west-2.amazonaws.com/';

    try {
      final response = await get(Uri.parse(apiEndpoint));
      final data = json.decode(response.body);
      dangerZonesData.addAll(data);
      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Data Received !')),
        );
        for (final item in data) {
          final coordinates = item['Coordinates'];

            print('id is: ${item['id']} name: ${item['title']}');
            if (dangerGeofences.isEmpty) {
              if (coordinates.length > 2) {
                final points = <LatLng>[];
                for (final co in coordinates) {
                  final lat = double.parse(co[0].toString());
                  final lng = double.parse(co[1].toString());
                  points.add(LatLng(lat, lng));
                }
                Polygon tempPolygon=Polygon(
                  polygonId: PolygonId(item['id'].toString()),
                  points: points.toList(),
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                );
                setState(() {
                  dangerGeofences.add(tempPolygon);
                });
                points.clear();

              }else{
                Circle tempCircle=Circle(
                  circleId: CircleId(item['id'].toString()),
                  center: LatLng(double.parse(coordinates.first[0].toString()),
                      double.parse(coordinates.first[1].toString())),
                  radius: 100,
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                );
                setState(() {
                  dangerGeofences.add(tempCircle);
                });
              }
            } else {

              if (coordinates.length > 2) {
                final points = <LatLng>[];

                //polygons
                for (final co in coordinates) {
                  final lat = double.parse(co[0].toString());
                  final lng = double.parse(co[1].toString());
                  points.add(LatLng(lat, lng));
                }
                Polygon tempPolygon = Polygon(
                  polygonId: PolygonId(item['id'].toString()),
                  points: points.toList(),
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                );

                if (!dangerGeofences.contains(tempPolygon)) {
                  setState(() {
                    dangerGeofences.add(tempPolygon);
                  });
                }

                points.clear();
              }else{
                //circle
                Circle tempCircle=Circle(
                  circleId: CircleId(item['id'].toString()),
                  center: LatLng(double.parse(coordinates.first[0].toString()),
                      double.parse(coordinates.first[1].toString())),
                  radius: 100,
                  fillColor: Colors.blue.withOpacity(0.5),
                  strokeColor: Colors.blue,
                );
                if (!dangerGeofences.contains(tempCircle)) {
                  setState(() {
                    dangerGeofences.add(tempCircle);
                  });
                }
              }

          }

        }
      } else {
        print("asdasasdaszd"+response.body);
        throw 'Problem with the get request';
      }
    } catch (e) {
      print('$e error');
      if (e.toString() == 'Connection closed while receiving data') {
        await fetchDangerZones();
      }
    }finally{
      print('done');
      print("danger llist ");
      // dangerZoneDataList.forEach((element) {
      //   if (element.runtimeType==Circle) {
      //     print(element.circleId);
      //   }if (element.runtimeType==Polygon) {
      //     print(element.polygonId);
      //   }
      //
      // });
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
                Cards(historyList, dangerZonesData),
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
    setState(()  {

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
