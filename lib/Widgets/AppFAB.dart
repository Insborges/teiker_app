import 'package:flutter/material.dart';
import 'package:teiker_app/theme/app_colors.dart';

class AppFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const AppFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: tooltip,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: AppColors.primaryGreen,
      child: Icon(icon, color: Colors.white),
    );
  }
}
