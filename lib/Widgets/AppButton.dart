import 'package:flutter/material.dart';
import 'package:teiker_app/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = AppColors.primaryGreen,
    this.textColor = Colors.white,
    this.icon,
    this.enabled = true,
    this.verticalPadding = 16,
    this.borderRadius = 12,
    this.outline = false,
  });

  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool enabled;
  final double verticalPadding;
  final double borderRadius;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled ? color : Colors.grey.shade400;
    final backgroundColor = outline
        ? Colors.transparent
        : (enabled ? color : Colors.grey.shade400);
    final foregroundColor = outline ? borderColor : textColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: enabled ? onPressed : null,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: outline ? Border.all(color: borderColor, width: 1.8) : null,
            boxShadow: enabled && !outline
                ? const [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foregroundColor),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
