import 'package:flutter/material.dart';

AppBar buildAppBar(
  String title, {
  List<Widget>? actions,
  bool seta = false,
  Color bgColor = const Color.fromARGB(255, 4, 76, 32),
}) {
  return AppBar(
    automaticallyImplyLeading: seta,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    backgroundColor: bgColor,
    foregroundColor: Colors.white,
    actions: actions,
  );
}
