import 'package:flutter/material.dart';

class NewsCards extends StatefulWidget {
  const NewsCards({
    Key? key,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.Coo,
  }) : super(key: key);

  final String title;
  final String timestamp;
  final Coo;
  final String description;

  @override
  State<NewsCards> createState() => _NewsCardsState();

}

class _NewsCardsState extends State<NewsCards> {
  bool isExpanded = false;
  var height;
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
          style: TextStyle(fontSize: 25),
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
          style: TextStyle(fontSize: 25),
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          elevation: 5,
          child: InkWell(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(


                  height: contianerHeight,
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF8177),
                        Color(0xFFFF867A),
                        Color(0xFFDA5851),
                        Color(0xFFDB5B57),
                      ],
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
                          onPressed: () {},
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 10, 20),
                  child: Container(
                    height: height,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        isExpanded
                            ? SingleChildScrollView(
                              child: Text(
                                  widget.description,
                                  overflow: TextOverflow.visible,
                                ),
                            )
                            : Text(
                                widget.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if(isExpanded==true){
                                isExpanded = !isExpanded;
                                height=MediaQuery.of(context).size.height*0.30;
                              }else{
                                isExpanded = !isExpanded;
                                height=MediaQuery.of(context).size.height*0.10;
                              }
                            });
                          },
                          child: isExpanded
                              ? const Text('Read less')
                              : const Text('Read more'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
