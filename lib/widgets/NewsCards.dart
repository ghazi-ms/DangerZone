import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.75),
              Colors.red.withOpacity(0.9)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8fedf2).withOpacity(0.66),
                  Color(0xFFf6a991).withOpacity(0.9)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(
                      heightFactor: 1.7,
                      child: IconButton(
                        alignment: Alignment.center,
                        iconSize: 50,
                        onPressed: () {},
                        icon: Icon(Icons.map),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${widget.timestamp}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
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
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isExpanded = !isExpanded;
                              });
                            },
                            child: isExpanded
                                ? Text('Read less')
                                : Text('Read more'),
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
      ),
    );
  }
}
