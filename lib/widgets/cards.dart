import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:updated_grad/widgets/NewsCards.dart';

class Cards extends StatefulWidget {
  List<Map<String, String>> historyList = [];
  List<dynamic> dataList = [''];
  String? deviceId;
  Cards(this.historyList, this.dataList, this.deviceId, {Key? key})
      : super(key: key);
  @override
  State<Cards> createState() => _CardsState();
}

class _CardsState extends State<Cards> {
  bool isExpanded = false;
  List<Map<String, dynamic>> matchedList = [];

  @override
  Widget build(BuildContext context) {
    final RawScreenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final buttonBarHeight = MediaQuery.of(context).padding.bottom;
    final screenHeight =
        RawScreenHeight - appBarHeight - statusBarHeight - buttonBarHeight - 28;

    //CollectionReference collectionReference = FirebaseFirestore.instance.collection('dangerZones');

    //---------------
    for (var element in widget.historyList) {
      print("id in history ${element['id'].toString()}");

      for (var dataListObject in widget.dataList) {
        print('id in data list ${dataListObject['id']}');
        if (dataListObject['id'].toString() == element['id'].toString() ) {

          // Check if the ID already exists in matchedList
          bool idExists = false;
          for (var matchedObject in matchedList) {
            if (matchedObject['id'] == element['id'].toString()) {
              idExists = true;
              break;
            }
          }
          if (!idExists) {
            matchedList.insert(0,{
              'title': dataListObject['title'],
              'description': dataListObject['description'],
              'timeStamp': dataListObject['timeStamp'],
              'id': element['id'].toString(),
              'position': element['position'].toString(),
            });
          } else {
            print("Duplicate ID found: ${element['id'].toString()}");
          }
        }
      }
    }


    return matchedList.isNotEmpty
        ? SizedBox(
      height: screenHeight,
      width: screenWidth,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (int index = 0; index < matchedList.length; index++)
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 15),
                child: NewsCards(
                  title: matchedList[index]['title'],
                  description: matchedList[index]['description'],
                  timestamp: matchedList[index]['timeStamp'],
                  coordinate: matchedList[index]['position'],
                  id: matchedList[index]['id'],
                ),
              ),
            NewsCards(
              title:
              "الرئيس التركي يسلم قائد فريق البحث والانقاذ الدولي الاردني وسام التضحية العظمى",
              description:
              "سلم الرئيس التركي رجب طيب أردوغان، الثلاثاء، قائد فريق البحث والانقاذ الدولي الاردني المقدم أنس العبادي وسام التضحية العظمى رفيع المستوى من الدرجة الخاصة.جاء ذلك خلال حفل توزيع وسام الدولة للتضحية في المجمع الرئاسي التركي في العاصمة التركية أنقرة.ويأتي الوسام تقديراً لجهود فريق البحث والانقاذ الدولي الأردني التابع لمديرية الأمن العام الدفاع المدني، ودوره في تقديم المساعدة، وإغاثة متضرري الزلزال الذي ضرب جنوبي تركيا في شباط الماضي",
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title:
              "في أول أيام العيد.. وفاة بحادث تصادم مروع على طريق جرش",
              description:
              "وأوضح المصدر أن وزارة المياه والري لا تستطيع اقامة سدود في المناطق الشرقية نظرا لطبيعة تلك المناطق، حيث أن الأرض مستوية ورملية، ولا يوجد بها جبال وأودية يمكن تصميم سدود بها، لافتا إلى أن الوزارة تقوم بعمل مشاريع حصاد مائي من خلال الحفائر والسدود الترابية في تلك المناطق."
                  .length
                  .toString(),
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title:
              "إغلاق 19 منشأة وإتلاف أطنان من المواد الغذائية خلال عيد الفطر",
              description:
              "الغذاء والدواء:  كوادر الرقابة والتفتيش أتلفت خلال فترة العيد نحو 3 أطنان من المواد الغذائية,أعلنت مؤسسة الغذاء والدواء عن أن فرق الرقابة والتفتيش التابعة لها أغلقت 19 منشأة غذائية مخالفة لوجود سلبيات حرجةوأوقفت المؤسسة 70 منشأة أخرى عن العمل، خلال 800 جولة تفتيشية نفذتها فرقها الرقابية بفروعها المنتشرة في مختلف مناطق الأردن خلال فترة عيد الفطر، وفق ما جاء في بيان المؤسسة,بدوره قال مدير عام المؤسسة، نزار مهيدات، الثلاثاء: إن كوادر الرقابة والتفتيش أتلفت خلال فترة العيد نحو 3 أطنان من المواد الغذائية المخالفة للاشتراطات الصحية والمعدة في ظروف صحية سيئة، ونحو 900 لتر من المواد الغذائية السائلة.وأضاف أن فرق التفتيش حجزت نحو 28 طنا، و 1500 لتر من الأغذية المتداولة في الأسواق لغايات الفحص المخبري.وأشار إلى أن كوادر المؤسسة في المراكز الجمركية أنجزت نحو 160 بيانا جمركيا خاصا بالمواد الغذائية المستوردة بعد الكشف على الإرساليات الجمركية وسحب العينات، والتأكد من مطابقتها للاشتراطات الصحية والمواصفات القياسية الخاصة بالمادة الغذائية المستوردة",
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title: "مراسل : إخماد حريق مركبة في الكرك دون وقوع إصابات",
              description:
              "قرَّرت الهيئة الحاكمة لدى محكمة التَّمييز، برئاسة القاضي محمود البطوش وعضوية القضاة محمد الخشاشنة والدكتور فوزي النَّهار وإبراهيم أبو شمَّا وقاسم الدغمي، رد التَّمييز المقدَّم من أحد المُدانين بقضية غسيل أموال، وصلت قيمتها لنصف مليون دينار، وأيدت الحكم الذي أصدرته محكمة استئناف عمَّان، والذي يقضي بوضعه وشخص آخر بالأشغال المؤقتة لمدة 7 سنوات وتضمينهما دفع مبلغ مالي قيمته مليون دينار.",
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title: " 3 إصابات بحادث تصادم في إربد",
              description:
              " وتشير تفاصيل القضية إلى أنَّ المُدانين أسندت لهما جناية غسل الأموال بحدود المادة 3 من قانون غسيل الأموال ومكافحة الإرهاب رقم 20 لسنة 2021 وعملا بالمادة 30 من ذات القانون، وأنَّ المشتكيين قاما بفتح حساب وديعة لدى أحد البنوك الأردنية عام 2011 وسافرا إلى الخارج وقاما بتغذيته خلال الفترة السابقة إلى أن وصلت قيمة الوديعة 732 ألفا و921 دولارًا وجرى تجميدها من قبل البنك لغايات تحديث الحساب، وتوجه المشتكي للبنك واستفسر عن الحساب وتفاجأ من موظفة البنك بأن رصيد الحساب هو فقط حوالي 27 ألف دولار فقط وأخبرته بأنه جرى تحويل مبلغ 696 ألف دولار تقريبا الى إحدى المحاكم وتم تزويده برقم القضية."
                  .length
                  .toString(),
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title: "إصابة 5 أشخاص بحادث تصادم في الطفيلة",
              description:
              "لى صعيد آخر، أقرَّ مجلس الوزراء الاستراتيجيَّة الوطنيَّة للتِّجارة الإلكترونيَّة؛ ليُصار إلى قيام وزارة الصِّناعة والتِّجارة والتَّموين بالسَّير قُدُماً في تنفيذ الإجراءات ذات الأولويَّة للأعوام (2023 - 2025م) بالتَّعاون مع جميع الجهات ذات العلاقة.وتهدف الاستراتيجيَّة إلى تهيئة بيئة ممكِّنة للتِّجارة الإلكترونيَّة جاذبة للاستثمار وممارسة الأعمال وتوفير فرص للدَّخل للمواطنين، وتعزيز القدرة التَّنافسيَّة للمشاريع المتناهية الصِّغر والصَّغيرة والمتوسِّطة وروَّاد الأعمال من خلال استخدام حلول التِّجارة الإلكترونيَّة والتقنيَّات الحديثة للتوسُّع محليَّاً وعالميَّاً، وتسهيل التِّجارة وتعزيز القدرة التَّنافسيَّة لقطاع الخدمات اللوجستيَّة.",
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title:
              "مسيرة ليلية في معان للافراج عن المعتقلين ووقف ملاحقة مشاركين باضراب الشاحنات",
              description:
              "نذرت أمانة عمان الكبرى، اليوم الاحد، 29 عامل وطن وعامل حدائق آخر، بالعودة إلى عملهم خلال 3 أيام، وإلا سيتم فصلهم نتيجة تغيبهم عن العمل لمدة تزيد عن 10 أيام. ",
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),
              id: ("55555"),
            ),
            NewsCards(
              title:
              "الجبور: منسوب المياه في بعض مناطق الزرقاء وصل الى (2.5) مترا والسيول جرفتمسيرة ليلية في معان للافراج عن المعتقلين ووقف ملاحقة مشاركين باضراب الشاحنات ",
              description:
              "دعا الديوان بالتنسيق مع مختلف المؤسسات والوزارات إلى تعبئة شواغر مختلفة استنادا للشروط المنصوص عليها من كل مؤسسة. "
                  .length
                  .toString(),
              timestamp: DateTime.now().toString(),
              coordinate:  ('32.345435,33.67845'),

              id: ("55555"),
            ),
          ],
        ),
      ),
    )
        : const Placeholder();
  }
// Get a reference to the dangerZones collection
//     var dangerZonesRef = FirebaseFirestore.instance.collection('dangerZones');
//
//     // Add the dangerZoneList subcollection with some sample data
//     dangerZonesRef
//         .doc(widget.deviceId.toString())
//         .collection('dangerZoneList')
//         .add({
//       "name": 'Zone A',
//       "latitude": 40.7128,
//       'longitude': -74.0060,
//       "radius": 100
//     });
//
//     // Add the historyList subcollection with some sample data
//     dangerZonesRef
//         .doc(widget.deviceId.toString())
//         .collection('historyList')
//         .add({"date": 123213, "message": 'Entered Zone A'});
//
//     // Add the geoList subcollection with some sample data
//     dangerZonesRef
//       ..doc(widget.deviceId.toString()).collection('geoList').add({
//         "latitude": 40.7128,
//         "longitude": -74.0060,
//         "timestamp": 123213,
//       });

    //-------------
    //
    //
    /*
    return SizedBox(
      height: screenHeight,
      width: screenWidth,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dangerZones')
            .doc(widget.deviceId)
            .collection('historyList')
            .snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot> historySnapshot) {
          if (historySnapshot.hasData) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dangerZones')
                  .doc(widget.deviceId)
                  .collection('dangerZonesData')
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> dangerZonesSnapshot) {
                if (dangerZonesSnapshot.hasData) {
                  List<Map<String, dynamic>> dangerZonesList =
                      dangerZonesSnapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();

                  List<Map<String, dynamic>> historyList = historySnapshot
                      .data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();

                  // Filter the danger zones list to only include those that have a matching ID in the history list
                  dangerZonesList = dangerZonesList
                      .where((dangerZone) => historyList
                          .any((history) => history['id'] == dangerZone['id']))
                      .toList();

                  return ListView.builder(
                    itemCount: dangerZonesList.length,
                    itemBuilder: (BuildContext context, int index) {
                      var dangerZone = dangerZonesList[index];
                      return NewsCards(
                        title: dangerZone['title'].toString(),
                        description: dangerZone['description'].toString(),
                        timestamp: dangerZone['timeStamp'].toString(),
                        coordinate: dangerZone['position'].toString(),
                        id: dangerZone['id'].toString(),
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            );
          } else {
            return const Center(
              child: Text("you are safe"),
            );
          }
        },
      ),
    );
  }

     */

}
