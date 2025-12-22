import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreens/DefinicoesTeikersScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';

class TeikersMainscreen extends StatefulWidget {
  const TeikersMainscreen({super.key});

  @override
  State<TeikersMainscreen> createState() => _TeikersMainscreenState();
}

class _TeikersMainscreenState extends State<TeikersMainscreen> {
  int selected = 0;
  final controller = PageController();

  static const Color creamBackground = Color(0xFFF8F6EB);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => selected = index);
    controller.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: controller,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              HomeScreen(),
              ClientesScreen(),
              DefinicoesTeikersScreen(),
            ],
          ),

            Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomNavBar(
                index: selected,
                showFab: false,
                items: const [
                  NavItemConfig(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_filled,
                    label: "Home",
                  ),
                  NavItemConfig(
                    icon: Icons.people_outline,
                    activeIcon: Icons.groups,
                    label: "Clientes",
                  ),
                  NavItemConfig(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: "Settings",
                  ),
                ],
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }
}
