import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:updated_grad/widgets/NewsCards.dart';

class Cards extends StatefulWidget {
  List<Map<String, String>> historyList = [];
  List<dynamic> dataList = [''];
  String? deviceId;
  Cards(this.historyList, this.dataList, this.deviceId, {Key? key})
      : super(key: key);
  @override
  State<Cards> createState() => _CardsState();
}

class _CardsState extends State<Cards> {
  bool isExpanded = false;
  List<Map<String, dynamic>> matchedList = [];

  @override
  Widget build(BuildContext context) {
    final RawScreenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final buttonBarHeight = MediaQuery.of(context).padding.bottom;
    final screenHeight =
        RawScreenHeight - appBarHeight - statusBarHeight - buttonBarHeight - 28;

    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('dangerZones');

    //---------------

// Get a reference to the dangerZones collection
//     var dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
//
//     // Add the dangerZoneList subcollection with some sample data
//     dangerZonesRef
//         .doc(widget.deviceId.toString())
//         .collection('dangerZoneList')
//         .add({
//       "name": 'Zone A',
//       "latitude": 40.7128,
//       'longitude': -74.0060,
//       "radius": 100
//     });
//
//     // Add the historyList subcollection with some sample data
//     dangerZonesRef
//         .doc(widget.deviceId.toString())
//         .collection('historyList')
//         .add({"date": 123213, "message": 'Entered Zone A'});
//
//     // Add the geoList subcollection with some sample data
//     dangerZonesRef
//       ..doc(widget.deviceId.toString()).collection('geoList').add({
//         "latitude": 40.7128,
//         "longitude": -74.0060,
//         "timestamp": 123213,
//       });

    //-------------
    //
    // for (var element in widget.historyList) {
    //   print("id in history ${element['id'].toString()}");
    //
    //   for (var dataListObject in widget.dataList) {
    //     print('id in data list ${dataListObject['id']}');
    //     if (dataListObject['id'].toString() == element['id'].toString()) {
    //       // Check if the ID already exists in matchedList
    //
    //       String targetId =
    //           dataListObject['id'].toString(); // the ID you want to check
    //
    //       FirebaseFirestore.instance
    //           .collection('dangerZones')
    //           .get()
    //           .then((QuerySnapshot querySnapshot) {
    //         bool idExists = false;
    //         querySnapshot.docs.forEach((doc) {
    //           if (doc['id'] == targetId) {
    //             idExists = true;
    //           }
    //         });
    //         if (idExists) {
    //           print('$targetId exists in at least one document');
    //         } else {
    //           collectionReference.add({
    //             'deviceId': widget.deviceId.toString(),
    //             'title': dataListObject['title'],
    //             'description': dataListObject['description'],
    //             'timeStamp': dataListObject['timeStamp'],
    //             'id': element['id'].toString(),
    //             'position': element['position'].toString(),
    //           });
    //         }
    //       }).catchError((error) => print('Error getting documents: $error'));
    //     }
    //   }
    // }
    return SizedBox(
      height: screenHeight,
      width: screenWidth,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dangerZones')
            .doc(widget.deviceId)
            .collection('historyList')
            .snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot> historySnapshot) {
          if (historySnapshot.hasData) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dangerZones')
                  .doc(widget.deviceId)
                  .collection('dangerZonesData')
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> dangerZonesSnapshot) {
                if (dangerZonesSnapshot.hasData) {
                  List<Map<String, dynamic>> dangerZonesList =
                      dangerZonesSnapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();

                  List<Map<String, dynamic>> historyList = historySnapshot
                      .data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();

                  // Filter the danger zones list to only include those that have a matching ID in the history list
                  dangerZonesList = dangerZonesList
                      .where((dangerZone) => historyList
                          .any((history) => history['id'] == dangerZone['id']))
                      .toList();

                  return ListView.builder(
                    itemCount: dangerZonesList.length,
                    itemBuilder: (BuildContext context, int index) {
                      var dangerZone = dangerZonesList[index];
                      return NewsCards(
                        title: dangerZone['title'].toString(),
                        description: dangerZone['description'].toString(),
                        timestamp: dangerZone['timeStamp'].toString(),
                        coordinate: dangerZone['position'].toString(),
                        id: dangerZone['id'].toString(),
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            );
          } else {
            return const Center(
              child: Text("you are safe"),
            );
          }
        },
      ),
    );
  }
}
