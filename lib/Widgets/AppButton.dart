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
    this.minHeight = 48,
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
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width <= 380;
    final borderColor = enabled ? color : Colors.grey.shade400;
    final backgroundColor = outline
        ? Colors.transparent
        : (enabled ? color : Colors.grey.shade400);
    final foregroundColor = outline ? borderColor : textColor;
    final effectiveVerticalPadding = isCompact
        ? (verticalPadding > 14 ? 14.0 : verticalPadding)
        : verticalPadding;
    final effectiveMinHeight = isCompact && minHeight >= 48 ? 44.0 : minHeight;
    final fontSize = isCompact ? 15.0 : 16.0;
    final iconSize = isCompact ? 20.0 : 24.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: effectiveMinHeight),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: effectiveVerticalPadding),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: outline
                  ? Border.all(color: borderColor, width: 1.8)
                  : null,
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
                  Icon(icon, color: foregroundColor, size: iconSize),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
