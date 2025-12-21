import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreens/DefinicoesAdminScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';
import 'package:teiker_app/Screens/TeikersInfoScreen.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/models/Clientes.dart';

class Adminscreen extends StatefulWidget {
  const Adminscreen({super.key});

  @override
  _AdminscreenState createState() => _AdminscreenState();
}

class _AdminscreenState extends State<Adminscreen> {
  int selected = 0;
  bool showOptions = false;
  final controller = PageController();

  final Color selectedColor = const Color.fromARGB(255, 4, 76, 32);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _teikerAdd() {
    Color selectedCor = Colors.green; // cor padrão

    showDialog(
      context: context,
      builder: (_) {
        final nameController = TextEditingController();
        final emailController = TextEditingController();
        final passwordController = TextEditingController();
        final telemovelController = TextEditingController();
        final horasController = TextEditingController();

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Adicionar Teiker",
            style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nome
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Nome",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Email
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Password
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Telemóvel
                TextField(
                  controller: telemovelController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Telemovel",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Horas
                TextField(
                  controller: horasController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Horas",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Color Picker
                Row(
                  children: [
                    const Text("Cor: "),
                    StatefulBuilder(
                      builder: (context, setStateDialog) => GestureDetector(
                        onTap: () async {
                          Color? picked = await showDialog(
                            context: context,
                            builder: (context) {
                              Color tempColor = selectedCor;
                              return AlertDialog(
                                title: const Text("Escolhe uma cor"),
                                content: SingleChildScrollView(
                                  child: BlockPicker(
                                    pickerColor: tempColor,
                                    onColorChanged: (color) {
                                      tempColor = color;
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancelar"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, tempColor),
                                    child: const Text("Selecionar"),
                                  ),
                                ],
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedCor = picked;
                            });
                          }
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: selectedCor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => Navigator.pop(context),
                    text: "Cancelar",
                    outline: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      final telemovel = telemovelController.text.trim();
                      final horas = horasController.text.trim();

                      // Valida campos
                      if ([
                        name,
                        email,
                        password,
                        telemovel,
                        horas,
                      ].any((e) => e.isEmpty)) {
                        AppSnackBar.show(
                          context,
                          message: "Preencha todos os campos",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      // Valida telemovel
                      if (!RegExp(r'^[0-9]+$').hasMatch(telemovel)) {
                        AppSnackBar.show(
                          context,
                          message: "Telemovel inválido",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      // Valida horas
                      double? horasValue = double.tryParse(horas);
                      if (horasValue == null) {
                        AppSnackBar.show(
                          context,
                          message: "Horas inválidas",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      try {
                        await AuthService().createTeiker(
                          name: name,
                          email: email,
                          password: password,
                          telemovel: int.parse(telemovel),
                          horas: horasValue,
                          cor: selectedCor,
                        );

                        Navigator.pop(context);
                        AppSnackBar.show(
                          context,
                          message: "Teiker criado com sucesso!",
                          icon: Icons.check,
                          background: Colors.green.shade700,
                        );
                      } catch (e) {
                        AppSnackBar.show(
                          context,
                          message: "Erro ao criar Teiker: $e",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                      }
                    },
                    text: "Adicionar",
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _clienteAdd() {
    showDialog(
      context: context,
      builder: (_) {
        final nameController = TextEditingController();
        final moradaController = TextEditingController();
        final telemovelController = TextEditingController();
        final emailController = TextEditingController();
        final orcamentoController = TextEditingController();

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Adicionar Cliente",
            style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Nome",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: moradaController,
                  decoration: InputDecoration(
                    labelText: "Morada",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: telemovelController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Telemóvel",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: orcamentoController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Orçamento (€)",
                    labelStyle: TextStyle(color: selectedColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: "Cancelar",
                    outline: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: "Adicionar",
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final morada = moradaController.text.trim();
                      final telemovel = telemovelController.text.trim();
                      final email = emailController.text.trim();
                      final orcamento = orcamentoController.text.trim();

                      // Validações
                      if ([
                        name,
                        morada,
                        telemovel,
                        email,
                        orcamento,
                      ].any((e) => e.isEmpty)) {
                        AppSnackBar.show(
                          context,
                          message: "Preencha todos os campos",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      if (!RegExp(r'^[0-9]+$').hasMatch(telemovel)) {
                        AppSnackBar.show(
                          context,
                          message: "Telemóvel inválido",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      final double? orc = double.tryParse(
                        orcamento.replaceAll(",", "."),
                      );
                      if (orc == null) {
                        AppSnackBar.show(
                          context,
                          message: "Orçamento inválido",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      try {
                        // Criar modelo Cliente
                        final newCliente = Clientes(
                          uid: FirebaseFirestore.instance
                              .collection("clientes")
                              .doc()
                              .id, // UID automático
                          nameCliente: name,
                          moradaCliente: morada,
                          telemovel: int.parse(telemovel),
                          email: email,
                          orcamento: orc,
                          hourasCasa: 0.0,
                          teikersIds: [],
                        );

                        await AuthService().createCliente(newCliente);

                        Navigator.pop(context);
                        AppSnackBar.show(
                          context,
                          message: "Cliente criado com sucesso!",
                          icon: Icons.check,
                          background: Colors.green.shade700,
                        );
                      } catch (e) {
                        AppSnackBar.show(
                          context,
                          message: "Erro ao criar cliente: $e",
                          icon: Icons.error,
                          background: Colors.red.shade700,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                selectedColor: Colors.white,
                unSelectedColor: Colors.white,
                title: const Text('Teikers'),
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
            fabLocation: StylishBarFabLocation.end,
            notchStyle: NotchStyle.square,
            currentIndex: selected,
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
      floatingActionButton: SafeArea(
        child: SizedBox(
          width: 220,
          height: 230,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              IgnorePointer(
                ignoring: !showOptions,
                child: AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  right: 0,
                  bottom: showOptions ? 72 : -150,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: showOptions ? 1 : 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _fabAction(
                          icon: Icons.person_add_alt_1,
                          label: "Adicionar Teiker",
                          onTap: _teikerAdd,
                          color: selectedColor,
                        ),
                        const SizedBox(height: 10),
                        _fabAction(
                          icon: Icons.home_work_outlined,
                          label: "Adicionar Cliente",
                          onTap: _clienteAdd,
                          color: Colors.teal.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => showOptions = !showOptions),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        selectedColor,
                        selectedColor.withOpacity(.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: selectedColor.withOpacity(.28),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    showOptions ? CupertinoIcons.xmark : CupertinoIcons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: PageView(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          HomeScreen(),
          TeikersInfoScreen(),
          ClientesScreen(),
          DefinicoesAdminScreen(),
        ],
      ),
    );
  }

  Widget _fabAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? selectedColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: c.withOpacity(.12),
                child: Icon(icon, color: c, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
