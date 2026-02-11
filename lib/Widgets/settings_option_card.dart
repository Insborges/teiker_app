import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppCardBounceCard.dart';

class SettingsOptionCard extends StatelessWidget {
  const SettingsOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCardBounceCard(
        icon: icon,
        title: label,
        color: color,
        whiteText: true,
        onTap: onTap,
      ),
    );
  }
}
