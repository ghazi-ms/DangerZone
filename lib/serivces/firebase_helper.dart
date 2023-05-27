import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:platform_device_id/platform_device_id.dart';

class FireBaseHelper {
  late String _deviceId;
  late CollectionReference _dangerZonesRef;

  static FireBaseHelper? _instance;

  factory FireBaseHelper() {
    _instance ??= FireBaseHelper._internal();
    return _instance!;
  }

  FireBaseHelper._internal() {
    _deviceInfo();
    _dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
  }

  Future<void> _deviceInfo() async {
    _deviceId = (await PlatformDeviceId.getDeviceId)!;
    print(_deviceId);
  }

  Future<void> uploadData(dynamic list, String type) async {
    switch (type) {
      case "circle":
        await _uploadCirclesData(list);
        print('1');
        break;
      case "polygon":
        await _uploadPolygonsData(list);
        print('2');
        break;
      case "history":
        await _uploadHistoryListData(list);
        print('3');
        break;
      case "dangerData":
        await _uploadDangerZonesData(list);
        print('4');
        break;
    }
  }

  Future<void> _uploadDangerZonesData(dynamic dangerZonesData) async {
    for (int i = 0; i < dangerZonesData.length; i++) {
      _dangerZonesRef
          .doc(_deviceId.toString())
          .collection('dangerZonesData')
          .get()
          .then((QuerySnapshot querySnapshot) {
        final existingIds = Set<String>.from(
            querySnapshot.docs.map((doc) => doc['id'].toString()));

        // Check if the danger zone ID already exists in the Firebase collection
        if (existingIds.lookup(dangerZonesData[i]['id'].toString()) == null) {
          // Add the danger zone to the Firebase collection
          _dangerZonesRef
              .doc(_deviceId.toString())
              .collection('dangerZonesData')
              .add({
            'Coordinates': dangerZonesData[i]['Coordinates'].toString(),
            'title': dangerZonesData[i]['title'].toString(),
            'description': dangerZonesData[i]['description'].toString(),
            'id': dangerZonesData[i]['id'].toString(),
            'timeStamp': dangerZonesData[i]['timeStamp'].toString(),
            'Locations': dangerZonesData[i]['Locations'].toString(),
            'newsSource': dangerZonesData[i]['newsSource'].toString()
          });
        }
      });
    }
  }

  Future<void> _uploadPolygonsData(dynamic polygons) async {
    final querySnapshot = await _dangerZonesRef
        .doc(_deviceId.toString())
        .collection('polygons')
        .get();

    if (querySnapshot.docs.isEmpty) {
      await _addPolygonsToFirebase(polygons);
    } else {
      final existingPolygonIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['polygonId'].toString()));

      await _addNewPolygonsToFirebase(existingPolygonIds, polygons);
    }
  }

  Future<void> _addPolygonsToFirebase(dynamic polygons) {
    final batch = FirebaseFirestore.instance.batch();

    for (var polygon in polygons) {
      List<String> coordinatesList = [];

      for (var point in polygon.points.toList()) {
        coordinatesList.add(point.toJson().toString());
      }

      final documentRef = _dangerZonesRef
          .doc(_deviceId.toString())
          .collection('polygons')
          .doc();
      batch.set(documentRef, {
        'polygonId': polygon.polygonId.value.toString(),
        'coordinates': coordinatesList.toString(),
      });
    }

    return batch.commit();
  }

  Future<void> _addNewPolygonsToFirebase(
      Set<String> existingPolygonIds, dynamic polygons) {
    final batch = FirebaseFirestore.instance.batch();

    for (var polygon in polygons) {
      if (!existingPolygonIds.contains(polygon.polygonId.value.toString())) {
        List<String> coordinatesList = [];

        for (var point in polygon.points.toList()) {
          coordinatesList.add(point.toJson().toString());
        }

        final documentRef = _dangerZonesRef
            .doc(_deviceId.toString())
            .collection('polygons')
            .doc();
        batch.set(documentRef, {
          'polygonId': polygon.polygonId.value.toString(),
          'coordinates': coordinatesList.toString(),
        });
      }
    }

    return batch.commit();
  }

  Future<void> _uploadCirclesData(dynamic circles) async {
    final querySnapshot = await _dangerZonesRef
        .doc(_deviceId.toString())
        .collection('circles')
        .get();
    print(querySnapshot.docs.isEmpty);
    if (querySnapshot.docs.isEmpty) {
      print("is empty");
      await _addCirclesToFirebase(circles);
    } else {
      final existingCircleIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['circleId'].toString()));

      await _addNewCirclesToFirebase(existingCircleIds, circles);
    }
  }

  Future<void> _addCirclesToFirebase(dynamic circles) {
    final batch = FirebaseFirestore.instance.batch();
    print("batch");
    for (var circle in circles) {
      final documentRef =
          _dangerZonesRef.doc(_deviceId.toString()).collection('circles').doc();
      batch.set(documentRef, {
        'circleId': circle.circleId.value.toString(),
        'center': circle.center.toJson().toString(),
        'radius': circle.radius.toString(),
      });
    }

    return batch.commit();
  }

  Future<void> _addNewCirclesToFirebase(
      Set<String> existingCircleIds, dynamic circles) {
    final batch = FirebaseFirestore.instance.batch();

    for (var circle in circles) {
      if (!existingCircleIds.contains(circle.circleId.value.toString())) {
        final documentRef = _dangerZonesRef
            .doc(_deviceId.toString())
            .collection('circles')
            .doc();
        batch.set(documentRef, {
          'circleId': circle.circleId.value.toString(),
          'center': circle.center.toJson().toString(),
          'radius': circle.radius.toString(),
        });
      }
    }

    return batch.commit();
  }

  Future<void> _uploadHistoryListData(dynamic historyList) async {
    _dangerZonesRef
        .doc(_deviceId.toString())
        .collection('historyList')
        .get()
        .then((QuerySnapshot querySnapshot) {
      final existingHistoryIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['id'].toString()));
      // Add history items to the Firebase collection if they don't already exist
      for (var history in historyList) {
        if (!existingHistoryIds.contains(history['id'].toString())) {
          _addHistoryItemToFirebase(history);
        }
      }
    });
  }

  Future<void> _addHistoryItemToFirebase(
      Map<String, dynamic> historyItem) async {
    _dangerZonesRef.doc(_deviceId.toString()).collection('historyList').add({
      'id': historyItem['id'].toString(),
      'position': historyItem['position'].toString(),
    });
  }
}
