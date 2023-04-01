import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Cards extends StatelessWidget {
  List<String> mylist;
  Cards(this.mylist);

  Future<void> reDirectToMaps(String title) async {
    final Uri url = Uri.parse('https://www.google.com/maps/place/$title');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {



    return mylist.isEmpty? Text("empty"): Container(
      height: MediaQuery.of(context).size.height*0.26,

      child: ListView.builder(itemBuilder: (ctx, index) {
        return  Card(
            elevation: 6,
            margin: EdgeInsets.symmetric(vertical: 6,horizontal: 5),
            child: ListTile(
              leading: IconButton(
                onPressed: (){reDirectToMaps(mylist[index]);},
                icon: Icon(Icons.map),

              ),
              title: Text("خبر مهم",style: Theme.of(context).textTheme.headline6 ,textAlign: TextAlign.end),
              subtitle: Text(mylist[index]+"تفاصيل الخبر"),
              trailing: Text(DateFormat.yMMMd().format(DateTime.now())),
            ),
          );
      }
        ,itemCount: mylist.length,
      ),
    );
  }
}
