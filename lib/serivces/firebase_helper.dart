import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:platform_device_id/platform_device_id.dart';

/// [FireBaseHelper] is a class that helps the app to connect to the firebase store .
class FireBaseHelper {
  late String _deviceId;
  late CollectionReference _dangerZonesRef;
  static FireBaseHelper? _instance;
  final List<String> _deletedIds = [];

  /// a factory method to create an object of the class using the same instance to apply singleton principle.
  /// if the object is null it creates only one instance of it.
  factory FireBaseHelper() {
    _instance ??= FireBaseHelper._internal();

    return _instance!;
  }

  ///an internal constructor that gets called only once when the object is created.
  FireBaseHelper._internal() {
    _deviceInfo();
    _dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
  }

  /// function to return the devices unique device id [_deviceId].
  Future<void> _deviceInfo() async {
    _deviceId = (await PlatformDeviceId.getDeviceId)!;
  }

  ///function that takes [list] and [listName] and deletes all the corresponding [ids] in the [list] inside that [listName].
  Future<void> clearData(dynamic list, String listName) async {
    final firestore = FirebaseFirestore.instance;

    // Iterate over the historyList and delete corresponding documents from Firestore
    list.forEach((element) async {
      await firestore
          .collection('dangerZones')
          .doc(_deviceId)
          .collection(listName)
          .where('id', isEqualTo: element['id'].toString())
          .get()
          .then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
    });
    // Clear the historyList
  }

  /// Loads data based on the provided [list] and [type].
  ///
  /// The [list] parameter is the data list to be loaded.
  /// The [type] parameter indicates the type of data to be loaded.
  /// It can be one of the following values: "circle", "polygon", "history", "dangerData".
  Future<void> loadData(dynamic list, String type) async {
    await _dangerZonesRef.doc().get().then((_) async {
      switch (type) {
        case "circle":
          await _loadCircles(list);
          break;
        case "polygon":
          await _loadPolygons(list);
          break;
        case "history":
          await _loadHistoryList(list);
          break;
        case "dangerData":
          await _loadDangerZonesData(list);
          break;
      }
    });
  }

  /// Uploads data based on the provided [list] and [type].
  ///
  /// The [list] parameter is the data list to be uploaded.
  /// The [type] parameter indicates the type of data to be uploaded.
  /// It can be one of the following values: "circle", "polygon", "history", "dangerData".
  Future<void> uploadData(dynamic list, String type) async {
    switch (type) {
      case "circle":
        await _uploadCirclesData(list);
        break;
      case "polygon":
        await _uploadPolygonsData(list);
        break;
      case "history":
        await _uploadHistoryListData(list);
        break;
      case "dangerData":
        await _uploadDangerZonesData(list);
        break;
    }
  }

  /// Deletes documents older than 24 hours from the Firestore collection.
  ///
  /// Returns a list of deleted document IDs.
  Future<List<String>> deleteDocuments() async {
    final firestore = FirebaseFirestore.instance;
    final currentTime = DateTime.now();
    final twentyFourHoursAgo = currentTime.subtract(const Duration(hours: 24));

    final querySnapshot = await firestore
        .collection('dangerZones')
        .doc(_deviceId)
        .collection('dangerZonesData')
        .get();

    for (final doc in querySnapshot.docs) {
      final id = doc['id'];
      final timestamp = doc['timeStamp'];
      _deletedIds.add(id);
      if (_isTimestampBeforeTwentyFourHours(timestamp, twentyFourHoursAgo)) {
        await _deleteDocumentsInCollection(
          firestore,
          'circles',
          id,
          'circleId',
        );
        await _deleteDocumentsInCollection(
          firestore,
          'dangerZonesData',
          id,
          'id',
        );
        await _deleteDocumentsInCollection(firestore, 'historyList', id, 'id');
        await _deleteDocumentsInCollection(
          firestore,
          'polygons',
          id,
          'polygonId',
        );
      }
    }

    return _deletedIds;
  }

  /// Checks if the [timestamp] is before [twentyFourHoursAgo].
  ///
  /// The [timestamp] can be either a String or a Firestore Timestamp.
  /// The [twentyFourHoursAgo] is the DateTime object representing 24 hours ago.
  /// Returns true if the timestamp is before 24 hours ago; false otherwise.
  bool _isTimestampBeforeTwentyFourHours(
    dynamic timestamp,
    DateTime twentyFourHoursAgo,
  ) {
    if (timestamp is String) {
      // Convert the timestamp string to a DateTime object
      final dateFormat = DateFormat("MM/dd/yyyy, HH:mm:ss");
      final timestampDateTime = dateFormat.parse(timestamp);

      // Compare the timestamp with the twentyFourHoursAgo parameter
      return timestampDateTime.isBefore(twentyFourHoursAgo);
    } else if (timestamp is Timestamp) {
      //the Firestore Timestamp directly with the twentyFourHoursAgo parameter
      return timestamp.toDate().isBefore(twentyFourHoursAgo);
    } else {
      throw ArgumentError(
        'Invalid timestamp type. Must be String or Timestamp.',
      );
    }
  }

  /// Deletes documents from a Firestore collection based on the provided parameters.
  ///
  /// The [firestore] parameter is the Firestore instance.
  /// The [collectionName] parameter is the name of the collection to delete documents from.
  /// The [id] parameter is the ID of the document to delete.
  /// The [fieldName] parameter is the name of the field to match when deleting documents.
  Future<void> _deleteDocumentsInCollection(
    FirebaseFirestore firestore,
    String collectionName,
    String id,
    String fieldName,
  ) async {
    final collectionRef = firestore
        .collection('dangerZones')
        .doc(_deviceId)
        .collection(collectionName);

    final querySnapshot =
        await collectionRef.where(fieldName, isEqualTo: id).get();

    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Loads danger zones data from Firestore and updates the provided [dangerZonesData] list.
  /// It checks for existing danger zones in the list and adds new danger zones from Firestore.
  /// The [dangerZonesData] parameter is a list containing existing danger zones data.
  Future<void> _loadDangerZonesData(dynamic dangerZonesData) async {
    QuerySnapshot querySnapshot = await _dangerZonesRef
        .doc(_deviceId)
        .collection('dangerZonesData')
        .get();

    List<Map<String, dynamic>> newDangerZones = [];

    for (var element in querySnapshot.docs) {
      Map data = element.data() as Map;

      bool found = dangerZonesData
          .any((item) => item['id'].toString() == data['id'].toString());

      if (!found) {
        newDangerZones.add({
          'Coordinates': data['Coordinates'],
          'Locations': data['Locations'],
          'description': data['description'],
          'id': data['id'],
          'timeStamp': data['timeStamp'],
          'title': data['title'],
          'newsSource': data['newsSource'],
        });
      }
    }

    dangerZonesData.addAll(newDangerZones);
  }

  /// Loads circle data from Firestore and updates the provided [circles] list.
  /// It checks for existing circles in the list and adds new circles from Firestore.
  /// The [circles] parameter is a list containing existing circle data.
  Future<void> _loadCircles(dynamic circles) async {
    QuerySnapshot querySnapshot =
        await _dangerZonesRef.doc(_deviceId).collection('circles').get();

    List<Circle> newCircles = [];

    for (var element in querySnapshot.docs) {
      Map data = element.data() as Map;

      bool found = circles.any(
        (circle) => circle.circleId.value == data['circleId'].toString(),
      );

      if (!found) {
        List<dynamic> center = jsonDecode(data['center']);
        double latitude = double.parse(center[0].toString());
        double longitude = double.parse(center[1].toString());
        Circle tempCircle = Circle(
          circleId: CircleId(data['circleId'].toString()),
          center: LatLng(latitude, longitude),
          radius: double.parse(data['radius'].toString()),
        );

        newCircles.add(tempCircle);
      }
    }

    circles.addAll(newCircles);
  }

  /// Loads polygon data from Firestore and updates the provided [polygons] list.
  /// It checks for existing polygons in the list and adds new polygons from Firestore.
  /// The [polygons] parameter is a list containing existing polygon data.
  Future<void> _loadPolygons(dynamic polygons) async {
    QuerySnapshot querySnapshot =
        await _dangerZonesRef.doc(_deviceId).collection('polygons').get();
    List<Polygon> newPolygons = [];
    for (var element in querySnapshot.docs) {
      Map data = element.data() as Map;
      bool found = polygons.any(
        (polygon) => polygon.polygonId.value == data['polygonId'].toString(),
      );
      if (!found) {
        List<dynamic> coordinates = jsonDecode(data['coordinates']);
        List<LatLng> latLngList = coordinates
            .map((coordinate) => LatLng(
                  double.parse(coordinate[0].toString()), // latitude
                  double.parse(coordinate[1].toString()), // longitude
                ))
            .toList();
        Polygon tempPoly = Polygon(
          polygonId: PolygonId(data['polygonId']),
          points: latLngList,
        );

        newPolygons.add(tempPoly);
      }
    }

    polygons.addAll(newPolygons);
  }

  /// Loads history list data from Firestore and updates the provided [historyList] list.
  /// It checks for existing items in the list and adds new items from Firestore.
  /// The [historyList] parameter is a list containing existing history list data.
  Future<void> _loadHistoryList(dynamic historyList) async {
    QuerySnapshot querySnapshot =
        await _dangerZonesRef.doc(_deviceId).collection('historyList').get();

    List<Map<String, String>> newHistoryList = [];

    for (var element in querySnapshot.docs) {
      Map data = element.data() as Map;

      bool found = historyList
          .any((item) => item['id'].toString() == data['id'].toString());

      if (!found) {
        newHistoryList.add({
          'id': data['id'].toString(),
          'position': data['position'].toString(),
        });
      }
    }

    historyList.addAll(newHistoryList);
  }

  /// Uploads danger zones data to Firestore.
  /// The [dangerZonesData] parameter is a list containing danger zones data to be uploaded.
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
            'newsSource': dangerZonesData[i]['newsSource'].toString(),
          });
        }
      });
    }
  }

  /// Uploads polygon data to Firestore.
  /// The [polygons] parameter is a list containing polygons data to be uploaded.
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

  /// Adds polygons data to Firestore.
  /// The [polygons] parameter is a list containing polygons data to be added.
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

  /// Adds new polygons data to Firestore.
  /// The [existingPolygonIds] parameter is a set of existing polygon IDs in Firestore.
  /// The [polygons] parameter is a list containing new polygons data to be added.
  Future<void> _addNewPolygonsToFirebase(
      Set<String> existingPolygonIds, dynamic polygons) async {
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

  /// Uploads circle data to Firestore.
  /// The [circles] parameter is a list containing circles data to be uploaded.
  Future<void> _uploadCirclesData(dynamic circles) async {
    final querySnapshot = await _dangerZonesRef
        .doc(_deviceId.toString())
        .collection('circles')
        .get();
    if (querySnapshot.docs.isEmpty) {
      await _addCirclesToFirebase(circles);
    } else {
      final existingCircleIds = Set<String>.from(
          querySnapshot.docs.map((doc) => doc['circleId'].toString()));

      await _addNewCirclesToFirebase(existingCircleIds, circles);
    }
  }

  /// Adds circles data to Firestore.
  /// The [circles] parameter is a list containing circles data to be added.
  Future<void> _addCirclesToFirebase(dynamic circles) {
    final batch = FirebaseFirestore.instance.batch();
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

  /// Adds new circles data to Firestore.
  /// The [existingCircleIds] parameter is a set of existing polygon IDs in Firestore.
  /// The [circles] parameter is a list containing new circles data to be added.
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

  /// Uploads history data to Firestore.
  /// The [historyList] parameter is a list containing history data to be uploaded.
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

  /// Adds new history Item to Firestore.
  /// The [historyItem] parameter is a set of history [IDs] and [position] in Firestore.
  Future<void> _addHistoryItemToFirebase(
      Map<String, dynamic> historyItem) async {
    _dangerZonesRef.doc(_deviceId.toString()).collection('historyList').add({
      'id': historyItem['id'].toString(),
      'position': historyItem['position'].toString(),
    });
  }
}
