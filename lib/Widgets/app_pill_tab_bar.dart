import 'package:flutter/material.dart';

class AppPillTabBar extends StatelessWidget {
  const AppPillTabBar({
    super.key,
    required this.primaryColor,
    required this.tabs,
    this.borderColor,
  });

  final Color primaryColor;
  final Color? borderColor;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? primaryColor.withValues(alpha: .2),
        ),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: primaryColor.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: primaryColor,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: tabs,
      ),
    );
  }
}
