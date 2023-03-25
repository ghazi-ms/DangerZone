import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
class MainLayout extends StatefulWidget {
  TextEditingController coor = TextEditingController();
  LatLng center ;
  Set<Circle> circles = {};
  Set<Polygon> polygons = {};
  late List<String> lists;

  MainLayout(this.coor, this.center, this.circles, this.polygons,this.lists);

  @override
  State<MainLayout> createState() => _MainLayoutState(this.lists);
}

class _MainLayoutState extends State<MainLayout> {
  List<String> list;
  late String dropdownValue;
  _MainLayoutState(this.list);

  @override


  void changeDrop() {

    setState(() {
      final data = dropdownValue.toString().split(",");
      widget.center = LatLng(double.parse(data[0]), double.parse(data[1]));
      Circle c = Circle(
        circleId: CircleId(const Time().second.toString()),
        center: widget.center,
        radius: 200,
        fillColor: Colors.red.withOpacity(0.5),
        strokeColor: Colors.red,
      );
      if(widget.circles.contains(c)){
        print("contains");
      }else{
        widget.circles.add(c);
      }

    });


  }
  Polygon p=Polygon(
    polygonId: PolygonId(const Time().second.toString()),
    points: [
      LatLng(31.8288, 35.9010),
      LatLng(31.8274, 35.8973),
      LatLng(31.8236, 35.8999),
      LatLng(31.8263, 35.9048),
    ],
    fillColor: Colors.blue.withOpacity(0.5),
    strokeColor: Colors.blue,
  );
  void add() {


    setState(() {
      widget.polygons.add(p);


    if (widget.coor.text !="") {
      list.add(widget.coor.text);

        final data = widget.coor.toString().split(",");

        widget.center = LatLng(double.parse(data[0]), double.parse(data[1]));
        Circle c = Circle(
          circleId: CircleId(const Time().second.toString()),
          center: widget.center,
          radius: 400,
          fillColor: Colors.red.withOpacity(0.5),
          strokeColor: Colors.red,
        );
        if(widget.circles.contains(c)){

        }else{
          widget.circles.add(c);
        }

      }
    });

  }


  Widget build(BuildContext context) {

    dropdownValue = list[0];
    return SingleChildScrollView(
      child: Column(
        children:[
                (widget.circles.isEmpty && widget.polygons.isEmpty) ? const Text("Empty") :
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height*0.6,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: widget.center,
                          zoom: 16.0,
                        ),
                        circles: widget.circles,
                        polygons: widget.polygons,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),



                        DropdownButton<String>(
                          value: dropdownValue,
                          icon: const Icon(Icons.arrow_downward),
                          elevation: 16,
                          style: const TextStyle(color: Colors.deepPurple),
                          underline: Container(
                            height: 2,
                            color: Colors.deepPurpleAccent,
                          ),
                          items: list.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? value) {

                            // This is called when the user selects an item.
                            setState(() {
                              dropdownValue = value!;
                              changeDrop();
                            });
                          },
                        ),
                        TextField(
                          controller: widget.coor,
                        ),
                        ElevatedButton(onPressed: add, child: const Text("Add")),
                    ]
      )
          );
  }
}
