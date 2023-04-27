import 'package:flutter/material.dart';

class DescriptionPage extends StatelessWidget {
  final String title;
  final String description;

  const DescriptionPage({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            description,
            style: const TextStyle(fontSize: 25),
          ),
        ),
      ),
    );
  }
}
