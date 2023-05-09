import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:updated_grad/widgets/NewsCards.dart';
import 'package:device_info_plus/device_info_plus.dart';

class Cards extends StatefulWidget {
  List<Map<String, String>> historyList = [];
  List<dynamic> dataList = [''];

  Cards(this.historyList, this.dataList, {Key? key}) : super(key: key);

  @override
  State<Cards> createState() => _CardsState();
}

class _CardsState extends State<Cards> {
  bool isExpanded = false;
  List<Map<String, dynamic>> matchedList = [];
  Future<void> DeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print('Running on ${androidInfo.id}'); // e.g. "Moto G (4)"

    // IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    // print('Running on ${iosInfo.utsname.machine}'); // e.g. "iPod7,1"
  }

  @override
  Widget build(BuildContext context) {
    DeviceInfo();
    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('dangerZones');
    for (var element in widget.historyList) {
      print("id in history ${element['id'].toString()}");

      for (var dataListObject in widget.dataList) {
        print('id in data list ${dataListObject['id']}');
        if (dataListObject['id'].toString() == element['id'].toString()) {
          // Check if the ID already exists in matchedList

          String targetId =
              dataListObject['id'].toString(); // the ID you want to check

          FirebaseFirestore.instance
              .collection('dangerZones')
              .get()
              .then((QuerySnapshot querySnapshot) {
            bool idExists = false;
            querySnapshot.docs.forEach((doc) {
              if (doc['id'] == targetId) {
                idExists = true;
              }
            });
            if (idExists) {
              print('$targetId exists in at least one document');
            } else {
              collectionReference.add({
                'title': dataListObject['title'],
                'description': dataListObject['description'],
                'timeStamp': dataListObject['timeStamp'],
                'id': element['id'].toString(),
                'position': element['position'].toString(),
              });
            }
          }).catchError((error) => print('Error getting documents: $error'));
        }
      }
    }
    return Expanded(
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('dangerZones')
                .snapshots(),
            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              return Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (BuildContext context, int index) {
                    var dangerZone = snapshot.data!.docs[index].data() as Map;
                    return NewsCards(
                      title: dangerZone['title'],
                      description: dangerZone['description'],
                      timestamp: dangerZone['timeStamp'],
                      coordinate: dangerZone['position'],
                      id: dangerZone['id'],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

//
// ListView.builder(
// itemBuilder: (ctx, index) {
// return Card(
// child: InkWell(
// onTap: () {
// print("Tap");
// },
// child: Row(
// crossAxisAlignment: CrossAxisAlignment.start,
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// Expanded(
// flex: 1,
// child: Center(
// heightFactor: 1.7,
// child: IconButton(
// alignment: Alignment.center,
//
// iconSize: 50,
// onPressed: (){reDirectToMaps(MatchedList[index]['Coordinates']);},
// icon: Icon(Icons.map),
// ),
// )
// ),
// Expanded(
// flex: 3,
// child: Padding(
// padding: const EdgeInsets.all(8.0),
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text(
// MatchedList[index]['title'],
// style: TextStyle(
// fontSize: 18,
// fontWeight: FontWeight.bold,
// ),
// ),
// SizedBox(height: 4),
// Text(
// '${MatchedList[index]['timeStamp']}',
// style: TextStyle(
// color: Colors.grey[600],
// ),
// ),
// SizedBox(height: 8),
// isExpanded
// ? Text(MatchedList[index]['description'])
//     : Text(
// MatchedList[index]['description'],
// maxLines: 3,
// overflow: TextOverflow.ellipsis,
// ),
// SizedBox(height: 8),
// GestureDetector(
// onTap: () {
// setState(() {
// isExpanded = !isExpanded;
// });
// },
// child: isExpanded ? Text('Read less') : Text('Read more'),
// ),
// ],
// ),
// ),
// ),
// ],
// ),
// ),
// );
//
// },
// itemCount: MatchedList.length,
// ),

//befooore
// Card(
// child: InkWell(
// onTap: () {
// print("Tap");
// },
// child: Row(
// crossAxisAlignment: CrossAxisAlignment.start,
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// Expanded(
// flex: 1,
// child: Center(
// heightFactor: 1.7,
// child: IconButton(
// alignment: Alignment.center,
//
// iconSize: 50,
// onPressed: (){},
// icon: Icon(Icons.map),
// ),
// )
// ),
// Expanded(
// flex: 3,
// child: Padding(
// padding: const EdgeInsets.all(8.0),
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text(
// widget.title,
// style: TextStyle(
// fontSize: 18,
// fontWeight: FontWeight.bold,
// ),
// ),
// SizedBox(height: 4),
// Text(
// 'By ${widget.author} | ${widget.date}',
// style: TextStyle(
// color: Colors.grey[600],
// ),
// ),
// SizedBox(height: 8),
// isExpanded
// ? Text(widget.summary)
//     : Text(
// widget.summary,
// maxLines: 3,
// overflow: TextOverflow.ellipsis,
// ),
// SizedBox(height: 8),
// GestureDetector(
// onTap: () {
// setState(() {
// isExpanded = !isExpanded;
// });
// },
// child: isExpanded ? Text('Read less') : Text('Read more'),
// ),
// ],
// ),
// ),
// ),
// ],
// ),
// ),
// );
