import 'package:flutter/material.dart';
import 'package:updated_grad/widgets/DangerEventCard.dart';

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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final rawScreenHeight = mediaQuery.size.height;
    const appBarHeight = kToolbarHeight;

    final statusBarHeight = mediaQuery.padding.top;
    final buttonBarHeight = mediaQuery.padding.bottom;

    final screenHeight = rawScreenHeight -
        appBarHeight -
        statusBarHeight -
        buttonBarHeight -
        mediaQuery.systemGestureInsets.top.toDouble() -
        mediaQuery.systemGestureInsets.bottom.toDouble();

    for (var element in widget.historyList) {
      for (var dataListObject in widget.dataList) {
        if (dataListObject['id'].toString() == element['id'].toString()) {
          // Check if the ID already exists in matchedList
          bool idExists = false;
          for (var matchedObject in matchedList) {
            if (matchedObject['id'] == element['id'].toString()) {
              idExists = true;
              break;
            }
          }
          if (!idExists) {
            matchedList.insert(0, {
              'title': dataListObject['title'],
              'description': dataListObject['description'],
              'timeStamp': dataListObject['timeStamp'],
              'id': element['id'].toString(),
              'position': element['position'].toString(),
              'newsSource': dataListObject['newsSource'].toString()
            });
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 100,
              maxHeight: screenHeight,
            ),
            child: ListView.builder(
              itemCount: matchedList.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(23, 16, 23, 16),
                  child: DangerEventCard(
                    title: matchedList[index]['title'],
                    description: matchedList[index]['description'],
                    timestamp: matchedList[index]['timeStamp'],
                    coordinate: matchedList[index]['position'],
                    id: matchedList[index]['id'],
                    newsSource: matchedList[index]['newsSource'],
                  ),
                );
              },
            ));
      },
    );
  }
}
