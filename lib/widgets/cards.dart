import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:updated_grad/widgets/DangerEventCard.dart';

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

    final screenWidth = MediaQuery.of(context).size.width;
    final RawScreenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight; // Use the constant value for AppBar height
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final buttonBarHeight = MediaQuery.of(context).padding.bottom;
    final screenHeight =
        RawScreenHeight - appBarHeight - statusBarHeight - buttonBarHeight;
    //CollectionReference collectionReference = FirebaseFirestore.instance.collection('dangerZones');

    //---------------
    for (var element in widget.historyList) {
      print("id in history ${element['id'].toString()}");

      for (var dataListObject in widget.dataList) {
        print('id in data list ${dataListObject['id']}');
        if (dataListObject['id'].toString() == element['id'].toString() ) {

          // Check if the ID already exists in matchedList
          bool idExists = false;
          for (var matchedObject in matchedList) {
            if (matchedObject['id'] == element['id'].toString()) {
              idExists = true;
              break;
            }
          }
          if (!idExists) {
            matchedList.insert(0,{
              'title': dataListObject['title'],
              'description': dataListObject['description'],
              'timeStamp': dataListObject['timeStamp'],
              'id': element['id'].toString(),
              'position': element['position'].toString(),
            });
          } else {
            print("Duplicate ID found: ${element['id'].toString()}");
          }
        }
      }
    }

    return matchedList.isNotEmpty
        ? LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 100,
              maxHeight: screenHeight-24,
            ),
            child: ListView(

              children: [
                for (int index = 0; index < matchedList.length; index++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(23, 16, 23, 16),
                    child: DangerEventCard(
                      title: matchedList[index]['title'],
                      description: matchedList[index]['description'],
                      timestamp: matchedList[index]['timeStamp'],
                      coordinate: matchedList[index]['position'],
                      id: matchedList[index]['id'],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(23, 16, 23, 16),
                  child: DangerEventCard(
                    title: "إجلاء مئات الأشخاص إثر حريق غابات في إسبانيا",
                    description: "matchedList[index]['description']",
                    timestamp: '05/19/2323',
                    coordinate: "32.25565,35.20165165",
                    id: '-1',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(23, 16, 23, 16),
                  child: DangerEventCard(
                    title: "السفير الهولندي لدى عمّان يشيد بأهمية دور الأردن بالمنطقة والعالم - فيديو",
                    description: "matchedList[index]['description']",
                    timestamp: '05/19/2323',
                    coordinate: "32.25565,35.20165165",
                    id: '-1',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(23, 16, 23, 16),
                  child: DangerEventCard(
                    title: "توقيف 13 شخصا اعتدوا على رجال أمن في الزرقاء",
                    description: "matchedList[index]['description']",
                    timestamp: '05/19/2323',
                    coordinate: "32.25565,35.20165165",
                    id: '-1',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    )

        : Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Center(
          child: Text(
            "You're safe!\nYou haven't entered any danger zones",
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

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
    //
    /*
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

     */

}
}
