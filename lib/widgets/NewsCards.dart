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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
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
                  height: 100,
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
                        top:10,
                        left: 0,
                        bottom: 20,
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.map,
                            color: Colors.white,
                            size: 75,
                          ),
                        ),
                      ),
                      Positioned(


                        left: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 200,
                                //height: MediaQuery.of(context).size.height - 100,// subtract the width of the icon and the padding from the card width
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
                            const SizedBox(height: 8),
                            Text(
                              widget.timestamp,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isExpanded
                          ? Text(
                        widget.description,
                        overflow: TextOverflow.visible,
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
                            isExpanded = !isExpanded;
                          });
                        },
                        child: isExpanded
                            ? const Text('Read less')
                            : const Text('Read more'),
                      ),
                    ],
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
