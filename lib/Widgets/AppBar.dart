import 'package:flutter/material.dart';
import 'package:teiker_app/theme/app_colors.dart';

AppBar buildAppBar(
  String title, {
  List<Widget>? actions,
  bool seta = false,
  Color bgColor = AppColors.primaryGreen,
}) {
  return AppBar(
    automaticallyImplyLeading: seta,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    backgroundColor: bgColor,
    foregroundColor: Colors.white,
    actions: actions,
  );
}
