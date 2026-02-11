import 'package:flutter/material.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.children,
    this.title,
    this.titleColor,
    this.titleIcon,
    this.titleTrailing,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  });

  final String? title;
  final Color? titleColor;
  final IconData? titleIcon;
  final Widget? titleTrailing;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final headerColor = titleColor ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 3,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, size: 20, color: headerColor),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: headerColor,
                        ),
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 8),
                      titleTrailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
