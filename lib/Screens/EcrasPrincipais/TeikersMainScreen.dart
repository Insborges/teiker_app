import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreens/DefinicoesScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/theme/app_colors.dart';

class TeikersMainscreen extends StatefulWidget {
  const TeikersMainscreen({super.key});

  @override
  State<TeikersMainscreen> createState() => _TeikersMainscreenState();
}

class _TeikersMainscreenState extends State<TeikersMainscreen> {
  int selected = 0;
  final controller = PageController();

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
      backgroundColor: AppColors.creamBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: controller,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              HomeScreen(),
              ClientesScreen(),
              DefinicoesScreen(role: SettingsRole.teiker),
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
