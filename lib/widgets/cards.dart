import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:updated_grad/widgets/NewsCards.dart';

class Cards extends StatefulWidget {
  List<String> historyList = <String>[''];
  List<dynamic> dataList = [''];

  Cards(this.historyList, this.dataList);

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
    List<dynamic> MatchedList = [];
    for (int index = 0; index < widget.dataList.length; index++) {
      for (var item in widget.historyList) {
        print(widget.dataList[index]['id'].toString() + "--" + item.toString());
        if (widget.dataList[index]['id'] == item &&
            !MatchedList.contains(item)) {
          MatchedList.add(widget.dataList[index]);
        }
      }
    }

    return SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        width: MediaQuery.of(context).size.width,
        child: MatchedList.isEmpty
            ? Text("Maaaaa")
            : GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 10),
                children: [
                  for (int index = 0; index < MatchedList.length; index++)
                    NewsCards(
                      title: MatchedList[index]['title'],
                      description: MatchedList[index]['description'],
                      timestamp: MatchedList[index]['timeStamp'],
                      Coo: MatchedList[index]['Coordinates'],
                    )
                ],
              ));
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
