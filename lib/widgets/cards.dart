import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:updated_grad/widgets/NewsCards.dart';

class Cards extends StatefulWidget {
  List<String> historyList = <String>[''];
  List<dynamic> dataList = [''];

  Cards(this.historyList, this.dataList);

  @override
  State<Cards> createState() => _CardsState();
}

class _CardsState extends State<Cards> {
  Future<void> reDirectToMaps(List<dynamic> title) async {
    MapsLauncher.launchQuery(title.first.toString());
  }

  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    List<dynamic> MatchedList = [];
    for (int index = 0; index < widget.dataList.length; index++) {
      for (var item in widget.historyList) {
        print(widget.dataList[index]['id'].toString() + "--" + item.toString());
        if (widget.dataList[index]['id'] == item &&
            !MatchedList.contains(item)) {
          MatchedList.add(widget.dataList[index]);
        }
      }
    }

    return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        width: MediaQuery.of(context).size.width,
        child: MatchedList.isEmpty
            ? const Text("Maaaaa")
            : GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 4 / 3,
                    crossAxisSpacing: 30,
                    mainAxisSpacing: 25),
                children: [
                  for (int index = 0; index < MatchedList.length; index++)
                    NewsCards(
                      title: MatchedList[index]['title'],
                      description: MatchedList[index]['description'],
                      timestamp: MatchedList[index]['timeStamp'],
                      Coo: MatchedList[index]['Coordinates'],
                    ),
                  NewsCards(
                    title:
                        "الرئيس التركي يسلم قائد فريق البحث والانقاذ الدولي الاردني وسام التضحية العظمى",
                    description:
                        "سلم الرئيس التركي رجب طيب أردوغان، الثلاثاء، قائد فريق البحث والانقاذ الدولي الاردني المقدم أنس العبادي وسام التضحية العظمى رفيع المستوى من الدرجة الخاصة.جاء ذلك خلال حفل توزيع وسام الدولة للتضحية في المجمع الرئاسي التركي في العاصمة التركية أنقرة.ويأتي الوسام تقديراً لجهود فريق البحث والانقاذ الدولي الأردني التابع لمديرية الأمن العام الدفاع المدني، ودوره في تقديم المساعدة، وإغاثة متضرري الزلزال الذي ضرب جنوبي تركيا في شباط الماضي",
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title: "في أول أيام العيد.. وفاة بحادث تصادم مروع على طريق جرش",
                    description: "في أول أيام العيد.. وفاة بحادث تصادم مروع على طريق جرش".length.toString(),
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title:
                        "إغلاق 19 منشأة وإتلاف أطنان من المواد الغذائية خلال عيد الفطر",
                    description:
                        "الغذاء والدواء:  كوادر الرقابة والتفتيش أتلفت خلال فترة العيد نحو 3 أطنان من المواد الغذائية,أعلنت مؤسسة الغذاء والدواء عن أن فرق الرقابة والتفتيش التابعة لها أغلقت 19 منشأة غذائية مخالفة لوجود سلبيات حرجةوأوقفت المؤسسة 70 منشأة أخرى عن العمل، خلال 800 جولة تفتيشية نفذتها فرقها الرقابية بفروعها المنتشرة في مختلف مناطق الأردن خلال فترة عيد الفطر، وفق ما جاء في بيان المؤسسة,بدوره قال مدير عام المؤسسة، نزار مهيدات، الثلاثاء: إن كوادر الرقابة والتفتيش أتلفت خلال فترة العيد نحو 3 أطنان من المواد الغذائية المخالفة للاشتراطات الصحية والمعدة في ظروف صحية سيئة، ونحو 900 لتر من المواد الغذائية السائلة.وأضاف أن فرق التفتيش حجزت نحو 28 طنا، و 1500 لتر من الأغذية المتداولة في الأسواق لغايات الفحص المخبري.وأشار إلى أن كوادر المؤسسة في المراكز الجمركية أنجزت نحو 160 بيانا جمركيا خاصا بالمواد الغذائية المستوردة بعد الكشف على الإرساليات الجمركية وسحب العينات، والتأكد من مطابقتها للاشتراطات الصحية والمواصفات القياسية الخاصة بالمادة الغذائية المستوردة",
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title: "مراسل : إخماد حريق مركبة في الكرك دون وقوع إصابات",
                    description: "asdasdsadasdsadas",
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title: " 3 إصابات بحادث تصادم في إربد",
                    description: " 3 إصابات بحادث تصادم في إربد".length.toString(),
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title: "إصابة 5 أشخاص بحادث تصادم في الطفيلة",
                    description: "asdasdsadasdsadas",
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title: "مسيرة ليلية في معان للافراج عن المعتقلين ووقف ملاحقة مشاركين باضراب الشاحنات",
                    description: "asdasdsadasdsadas",
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),
                  NewsCards(
                    title: "الجبور: منسوب المياه في بعض مناطق الزرقاء وصل الى (2.5) مترا والسيول جرفتمسيرة ليلية في معان للافراج عن المعتقلين ووقف ملاحقة مشاركين باضراب الشاحنات ",
                    description: "الجبور: منسوب المياه في بعض مناطق الزرقاء وصل الى (2.5) مترا والسيول جرفتمسيرة ليلية في معان للافراج عن المعتقلين ووقف ملاحقة مشاركين باضراب الشاحنات ".length.toString(),
                    timestamp: DateTime.now().toString(),
                    Coo: const [45884.184, 84654.4684],
                  ),

                ],
              ));
  }
}
//
// ListView.builder(
// itemBuilder: (ctx, index) {
// return Card(
// child: InkWell(
// onTap: () {
// print("Tap");
// },
// child: Row(
// crossAxisAlignment: CrossAxisAlignment.start,
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// Expanded(
// flex: 1,
// child: Center(
// heightFactor: 1.7,
// child: IconButton(
// alignment: Alignment.center,
//
// iconSize: 50,
// onPressed: (){reDirectToMaps(MatchedList[index]['Coordinates']);},
// icon: Icon(Icons.map),
// ),
// )
// ),
// Expanded(
// flex: 3,
// child: Padding(
// padding: const EdgeInsets.all(8.0),
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text(
// MatchedList[index]['title'],
// style: TextStyle(
// fontSize: 18,
// fontWeight: FontWeight.bold,
// ),
// ),
// SizedBox(height: 4),
// Text(
// '${MatchedList[index]['timeStamp']}',
// style: TextStyle(
// color: Colors.grey[600],
// ),
// ),
// SizedBox(height: 8),
// isExpanded
// ? Text(MatchedList[index]['description'])
//     : Text(
// MatchedList[index]['description'],
// maxLines: 3,
// overflow: TextOverflow.ellipsis,
// ),
// SizedBox(height: 8),
// GestureDetector(
// onTap: () {
// setState(() {
// isExpanded = !isExpanded;
// });
// },
// child: isExpanded ? Text('Read less') : Text('Read more'),
// ),
// ],
// ),
// ),
// ),
// ],
// ),
// ),
// );
//
// },
// itemCount: MatchedList.length,
// ),

//befooore
// Card(
// child: InkWell(
// onTap: () {
// print("Tap");
// },
// child: Row(
// crossAxisAlignment: CrossAxisAlignment.start,
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// Expanded(
// flex: 1,
// child: Center(
// heightFactor: 1.7,
// child: IconButton(
// alignment: Alignment.center,
//
// iconSize: 50,
// onPressed: (){},
// icon: Icon(Icons.map),
// ),
// )
// ),
// Expanded(
// flex: 3,
// child: Padding(
// padding: const EdgeInsets.all(8.0),
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text(
// widget.title,
// style: TextStyle(
// fontSize: 18,
// fontWeight: FontWeight.bold,
// ),
// ),
// SizedBox(height: 4),
// Text(
// 'By ${widget.author} | ${widget.date}',
// style: TextStyle(
// color: Colors.grey[600],
// ),
// ),
// SizedBox(height: 8),
// isExpanded
// ? Text(widget.summary)
//     : Text(
// widget.summary,
// maxLines: 3,
// overflow: TextOverflow.ellipsis,
// ),
// SizedBox(height: 8),
// GestureDetector(
// onTap: () {
// setState(() {
// isExpanded = !isExpanded;
// });
// },
// child: isExpanded ? Text('Read less') : Text('Read more'),
// ),
// ],
// ),
// ),
// ),
// ],
// ),
// ),
// );
