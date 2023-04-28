import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:updated_grad/widgets/NewsCards.dart';

class Cards extends StatefulWidget {
  List<Map<String, String>> historyList = [];
  List<dynamic> dataList = [''];

  Cards(this.historyList, this.dataList, {Key? key}) : super(key: key);

  @override
  State<Cards> createState() => _CardsState();
}

class _CardsState extends State<Cards> {
  Future<void> reDirectToMaps(List<dynamic> title) async {
    MapsLauncher.launchQuery(title.first.toString());
  }

  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        AppBar().preferredSize.height -
        (kBottomNavigationBarHeight);
    final screenWidth = MediaQuery.of(context).size.width;

    List<Map<String, dynamic>> matchedList = [];

    for (var element in widget.historyList) {
      print("id in history ${element['id'].toString()}");

      for (var dataListObject in widget.dataList) {
        print('id in data list ${dataListObject['id']}');
        if (dataListObject['id'].toString() == element['id'].toString()) {
          print(element['position'].toString());
          matchedList.add({
            'title': dataListObject['title'],
            'description': dataListObject['description'],
            'timeStamp': dataListObject['timeStamp'],
            'id': element['id'].toString(),
            'position': element['position'].toString(),
          });
          print(matchedList[0]['position']);
        }
      }
    }

    return matchedList.isNotEmpty
        ? SizedBox(
      height: screenHeight,
      width: screenWidth,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (int index = 0; index < matchedList.length; index++)
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 15),
                child: NewsCards(
                  title: matchedList[index]['title'],
                  description: matchedList[index]['description'],
                  timestamp: matchedList[index]['timeStamp'],
                  coordinate: matchedList[index]['position'],
                  id: matchedList[index]['id'],
                ),
              ),
          ],
        ),
      ),
    )
        : const Placeholder();
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
