import 'package:flutter/material.dart';

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
      backgroundColor: const Color.fromARGB(255, 4, 76, 32),
      child: Icon(icon, color: Colors.white),
    );
  }
}
