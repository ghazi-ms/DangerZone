import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';

import 'DescriptionPage.dart';

class NewsCards extends StatefulWidget {
  const NewsCards({
    Key? key,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.coordinate,
    required this.id,
  }) : super(key: key);

  final String title;
  final String timestamp;
  final String coordinate ;
  final String description;
  final String id;

  @override
  State<NewsCards> createState() => _NewsCardsState();

}

class _NewsCardsState extends State<NewsCards> {
  bool isExpanded = false;

  Future<void> reDirectToMaps(String coordinates) async {

    MapsLauncher.launchQuery(coordinates);
  }

  @override
  Widget build(BuildContext context) {



    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DescriptionPage(
                  description: widget.description,
                  title: widget.title,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF7043), // deep orange
                  Color(0xFFE57373), // light red
                  Color(0xFFB71C1C), // dark red
                  Color(0xFF1565C0), // blue
                  Color(0xFF42A5F5), // light blue
                  // Color(0xFFE0F7FA), // pale blue
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
              ),
            ),
            //new color
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(40),
            //   gradient: const LinearGradient(
            //     colors: [
            //       Colors.red,
            //       Color(0xFFFFA07A), // light salmon
            //       Colors.redAccent,
            //       Color(0xFFFFC0CB), // pink
            //     ],
            //     begin: Alignment.topLeft,
            //     end: Alignment.bottomRight,
            //   ),
            // ),
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(40),
            //   gradient: const LinearGradient(
            //     colors: [
            //       Color(0xFFCE3C3C), // Red
            //       Color(0xFFEE5484), // Pink
            //       Color(0xFF942020), // Red
            //     ],
            //     stops: [0, 0.4, 1],
            //     begin: Alignment.topLeft,
            //     end: Alignment.bottomRight,
            //   ),
            // ),
            child: ListTile(
              contentPadding: const EdgeInsets.only(top: 10,bottom: 40),

              leading:
              SizedBox(
                child: IconButton(
                  iconSize: 80,
                  onPressed: () {
                    reDirectToMaps(widget.coordinate);
                  },
                  icon: const Icon(
                    Icons.book,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),

              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.50,
                  child: Text(
                    widget.title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              subtitle: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  widget.timestamp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              trailing: IconButton(
                  iconSize: 60,

                  icon: const Icon(Icons.remove,color: Colors.white,),
                  onPressed: (){print("clicked");},

                )

            ),
          ),
        ),
      ),

    );

  }
}

