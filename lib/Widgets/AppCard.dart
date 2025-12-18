import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final Color? iconColor;
  final bool whiteText;
  final Widget? child;
  final EdgeInsets? padding;

  const AppCard({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.color,
    this.whiteText = false,
    this.iconColor,
    this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? Theme.of(context).cardColor,
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child:
              child ??
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      color:
                          iconColor ??
                          (whiteText ? Colors.white : Colors.black),
                    ),
                  if (icon != null) const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: whiteText ? Colors.white : Colors.black,
                            ),
                          ),

                        // ✅ Se existir subtitleWidget, mostra-o
                        if (subtitleWidget != null) ...[
                          const SizedBox(height: 4),
                          subtitleWidget!,
                        ]
                        // ✅ Caso contrário, mostra o subtitle normal
                        else if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 14,
                              color: whiteText
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (trailing != null) trailing!,
                ],
              ),
        ),
      ),
    );
  }
}
