import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';

import 'DescriptionPage.dart';

class NewsCards extends StatefulWidget {
  const NewsCards({
    Key? key,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.coo,
  }) : super(key: key);

  final String title;
  final String timestamp;
  final coo;
  final String description;

  @override
  State<NewsCards> createState() => _NewsCardsState();

}

class _NewsCardsState extends State<NewsCards> {
  bool isExpanded = false;
  var height;
  Future<void> reDirectToMaps(List<double> coordinates) async {

    MapsLauncher.launchQuery('${coordinates}');
  }

  @override
  Widget build(BuildContext context) {


    double? contianerHeight;


    if (widget.title.length<=55) {
    setState(() {
      contianerHeight=120.0;
    });
    }else if (widget.title.length<=110) {
      setState(() {
        TextSpan titleText = TextSpan(
          text: widget.title,
          style: const TextStyle(fontSize: 25),
        );
        TextPainter textPainter = TextPainter(
          text: titleText,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
// Calculate the container height based on the title size
        contianerHeight = MediaQuery.of(context).size.height * 0.15 + textPainter.height;
      });
    }  else {
      setState(() {
        TextSpan titleText = TextSpan(
          text: widget.title,
          style: const TextStyle(fontSize: 25),
        );
        TextPainter textPainter = TextPainter(
          text: titleText,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
// Calculate the container height based on the title size
        contianerHeight = MediaQuery.of(context).size.height * 0.30 + textPainter.height;
      });
    }
    return SingleChildScrollView(
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
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          elevation: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: contianerHeight,
                width: MediaQuery.of(context).size.width,
                // decoration: BoxDecoration(
                //   borderRadius: BorderRadius.circular(40),
                //   gradient: const LinearGradient(
                //     colors: [
                //       Color(0xFFFF7043), // deep orange
                //       Color(0xFFE57373), // light red
                //       Color(0xFFB71C1C), // dark red
                //       Color(0xFF1565C0), // blue
                //       Color(0xFF42A5F5), // light blue
                //       Color(0xFFE0F7FA), // pale blue
                //     ],
                //     begin: Alignment.topLeft,
                //     end: Alignment.bottomRight,
                //   ),
                // ),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFCE3C3C), // Red
                      Color(0xFFEE5484), // Pink
                      Color(0xFF942020), // Red
                    ],
                    stops: [0, 0.4, 1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),




                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 0,
                      bottom: 20,
                      child: IconButton(
                        onPressed: () {
                          reDirectToMaps(widget.coo);
                        },
                        icon: const Icon(
                          Icons.map,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 15,
                      child: Text(
                        widget.timestamp,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      left: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.60,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );


  }
}
