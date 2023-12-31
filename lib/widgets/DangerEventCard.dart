import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'DescriptionPage.dart';

class DangerEventCard extends StatefulWidget {
  /// Constructs a [DangerEventCard] widget.
  const DangerEventCard({
    Key? key,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.coordinate,
    required this.id,
    required this.newsSource,
  }) : super(key: key);

  final String title;
  final String timestamp;
  final String coordinate;
  final String description;
  final String id;
  final String newsSource;
  @override
  State<DangerEventCard> createState() => DangerEventCardState();
}

class DangerEventCardState extends State<DangerEventCard>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Launches maps application with the provided coordinates.
  Future<void> reDirectToMaps(String coordinates) async {
    MapsLauncher.launchQuery(coordinates);
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String> translateList = {"roya": "رؤيا", "alghad": "الغد"};

    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: 1.0 + (_animation.value * 0.1),
          child: child,
        );
      },
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.red.shade900,
                Colors.red.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 120,
                      width: 100,
                      child: GestureDetector(
                        onTap: () {
                          reDirectToMaps(widget.coordinate);
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('images/Icon.png'),
                              fit: BoxFit.cover,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Added space between map icon and text
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16), // Adjusted the spacing
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.timestamp,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 30),
                  Text(
                    "من ${translateList[widget.newsSource]}",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
