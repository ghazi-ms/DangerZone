import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:maps_launcher/maps_launcher.dart';

class Cards extends StatelessWidget {
  List<String> historyList = <String>[];
  List<dynamic> dataList = [''];

  Cards(this.historyList, this.dataList);

  Future<void> reDirectToMaps(List<dynamic> title) async {
    MapsLauncher.launchQuery(title.first.toString());
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> MatchedList=[];
    for(int index=0;index<dataList.length;index++){
      for(var item in historyList){
        if (dataList[index]['id']==item ) {
          
          MatchedList.add(dataList[index]);
        }
      }
    }

    return MatchedList.isEmpty
        ? Text("empty")
        : Container(
            height: MediaQuery.of(context).size.height * 0.50,
            child: historyList.isEmpty
                ? Text("data")
                : ListView.builder(
                    itemBuilder: (ctx, index) {

                           return Card(
                            elevation: 6,
                            margin: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 5),
                            child: ListTile(
                              leading: IconButton(
                                onPressed: () {
                                  reDirectToMaps(
                                      MatchedList[index]['Coordinates']);
                                },
                                icon: Icon(Icons.map),
                                iconSize: 39,
                              ),
                              title: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.60,
                                height: 40,
                                child: Container(
                                  width: MediaQuery.of(context).size.width*.50,
                                  height: 40,
                                  child: Text(MatchedList[index]['title'],
                                      style:
                                          Theme.of(context).textTheme.headline6,
                                      textAlign: TextAlign.end),
                                ),
                              ),
                              subtitle: Text("تفاصيل الخبر"),
                              trailing: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.20,
                                height: 30,
                                child: Text(MatchedList[index]['timeStamp']),
                              ),
                            ),
                          );


                    },
                    itemCount: MatchedList.length,
                  ),
          );
  }
}
