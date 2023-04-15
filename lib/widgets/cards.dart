import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:maps_launcher/maps_launcher.dart';
class Cards extends StatelessWidget {
  List<dynamic> mylist;
  Cards(this.mylist);

  Future<void> reDirectToMaps(List<String> title) async {

    MapsLauncher.launchQuery('$title');
  }

  @override
  Widget build(BuildContext context) {



    return mylist.isEmpty? Text("empty"): Container(
      height: MediaQuery.of(context).size.height*0.26,

      child: ListView.builder(itemBuilder: (ctx, index) {

        return  Container(
          width: MediaQuery.of(context).size.width,
          height: 88,
          child: Card(

            elevation: 6,
            margin: EdgeInsets.symmetric(vertical: 6,horizontal: 5),
            child: ListTile(
              leading: IconButton(
                onPressed: (){reDirectToMaps(mylist[index]['coordinates']);},
                icon: Icon(Icons.map),
                iconSize: 39,
              ),
              title: SizedBox(width: MediaQuery.of(context).size.width*0.60,height: 40,child:  Text(mylist[index]['title'],style: Theme.of(context).textTheme.headline6 ,textAlign: TextAlign.end),),
              subtitle: Text("تفاصيل الخبر"),
              trailing: SizedBox(width: MediaQuery.of(context).size.width*0.20,height: 30,child: Text(mylist[index]['timeStamp']),),
            ),
          ),
        );
      }
        ,itemCount: mylist.length,
      ),
    );
  }
}
