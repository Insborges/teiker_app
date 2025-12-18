import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreens/DefinicoesTeikersScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';

class TeikersMainscreen extends StatefulWidget {
  const TeikersMainscreen({super.key});

  @override
  _TeikersMainscreenState createState() => _TeikersMainscreenState();
}

class _TeikersMainscreenState extends State<TeikersMainscreen> {
  int selected = 0;
  bool showOptions = false;
  final controller = PageController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        offset: showOptions ? const Offset(0, 0.15) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: showOptions ? 0.8 : 1.0,
          child: StylishBottomBar(
            option: AnimatedBarOptions(
              iconSize: 32,
              barAnimation: BarAnimation.blink,
              iconStyle: IconStyle.animated,
              opacity: 0.4,
            ),
            backgroundColor: const Color.fromARGB(255, 4, 76, 32),
            items: [
              BottomBarItem(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                selectedColor: Colors.white,
                unSelectedColor: Colors.white,
                title: const Text('Home'),
              ),
              BottomBarItem(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                selectedColor: Colors.white,
                unSelectedColor: Colors.white,
                title: const Text('Clientes'),
              ),
              BottomBarItem(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                selectedColor: Colors.white,
                unSelectedColor: Colors.white,
                title: const Text('Definições'),
              ),
            ],
            hasNotch: true,
            currentIndex: selected,
            notchStyle: NotchStyle.square,
            onTap: (index) {
              controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
              setState(() => selected = index);
            },
          ),
        ),
      ),

      body: PageView(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [HomeScreen(), ClientesScreen(), DefinicoesTeikersScreen()],
      ),
    );
  }
}
