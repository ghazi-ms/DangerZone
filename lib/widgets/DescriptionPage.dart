import 'package:flutter/material.dart';

/// class that takes [title] and [description] to display on a separate page.
class DescriptionPage extends StatelessWidget {
  final String title;
  final String description;

  const DescriptionPage({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        title: Text("حريق منزل في منطقة الجبيهة"),
        centerTitle: true,
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade900, Colors.red.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              "اندلع حريق هائل في منزل وسط منطقة الجبيهة في الأردن، وذلك بجوار مدرسة المنهل العالمية. وقد تلقت فرق الإطفاء البلاغ في الساعات الأولى من صباح اليوم، حيث تم نشر فرق الإنقاذ والإطفاء على الفور للتعامل مع الحادث",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 25, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
