import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreens/DefinicoesAdminScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';
import 'package:teiker_app/Screens/TeikersInfoScreen.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/models/Clientes.dart';

class Adminscreen extends StatefulWidget {
  const Adminscreen({super.key});

  @override
  State<Adminscreen> createState() => _AdminscreenState();
}

class _AdminscreenState extends State<Adminscreen> {
  int selected = 0;
  bool showOptions = false;

  final PageController controller = PageController();

  static const Color primaryColor = Color.fromARGB(255, 4, 76, 32);
  static const Color creamBackground = Color(0xFFF8F6EB);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // ---------------- NAV ----------------

  void _onNavTap(int index) {
    setState(() => selected = index);
    controller.jumpToPage(index);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: showOptions ? () => setState(() => showOptions = false) : null,
        child: Stack(
          children: [
            PageView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                HomeScreen(),
                TeikersInfoScreen(),
                ClientesScreen(),
                DefinicoesAdminScreen(),
              ],
            ),

            // FAB ACTIONS
            if (showOptions)
              Positioned(
                right: 16,
                bottom: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _fabAction(
                      icon: Icons.person_add_alt_1,
                      label: "Adicionar Teiker",
                      onTap: () {
                        setState(() => showOptions = false);
                        _teikerAdd();
                      },
                      color: primaryColor,
                    ),
                    const SizedBox(height: 8),
                    _fabAction(
                      icon: Icons.home_work_outlined,
                      label: "Adicionar Cliente",
                      onTap: () {
                        setState(() => showOptions = false);
                        _clienteAdd();
                      },
                      color: Colors.teal.shade700,
                    ),
                  ],
                ),
              ),

            // NAVBAR
            Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomNavBar(
                index: selected,
                fabOpen: showOptions,
                items: const [
                  NavItemConfig(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_filled,
                    label: "Home",
                  ),
                  NavItemConfig(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: "Teikers",
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
                onFabTap: () => setState(() => showOptions = !showOptions),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- FAB ACTION ----------------

  Widget _fabAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- FORMS (MANTIDOS) ----------------

  void _teikerAdd() {
    Color selectedCor = Colors.green;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final telemovelController = TextEditingController();
    final horasController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              left: 12,
              right: 12,
            ),
            child: StatefulBuilder(
              builder: (context, setStateSheet) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(.12),
                              child: Icon(
                                Icons.person_add_alt_1,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Adicionar Teiker",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _formInput("Nome", nameController),
                        const SizedBox(height: 10),
                        _formInput(
                          "Email",
                          emailController,
                          keyboard: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        _formInput(
                          "Password",
                          passwordController,
                          obscure: true,
                        ),
                        const SizedBox(height: 10),
                        _formInput(
                          "Telemóvel",
                          telemovelController,
                          keyboard: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        _formInput(
                          "Horas",
                          horasController,
                          keyboard: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              "Cor da Teiker",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () async {
                                Color tempColor = selectedCor;
                                final picked = await showDialog<Color>(
                                  context: sheetContext,
                                  builder: (c) => AlertDialog(
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
                                        onPressed: () => Navigator.pop(c, null),
                                        child: const Text("Cancelar"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, tempColor),
                                        child: const Text("Selecionar"),
                                      ),
                                    ],
                                  ),
                                );
                                if (picked != null) {
                                  setStateSheet(() => selectedCor = picked);
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: selectedCor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(color: primaryColor),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text("Cancelar"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text(
                                  "Adicionar",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final name = nameController.text.trim();
                                  final email = emailController.text.trim();
                                  final password = passwordController.text
                                      .trim();
                                  final telemovel = telemovelController.text
                                      .trim();
                                  final horas = horasController.text.trim();

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

                                  if (!RegExp(
                                    r'^[0-9]+$',
                                  ).hasMatch(telemovel)) {
                                    AppSnackBar.show(
                                      context,
                                      message: "Telemóvel inválido",
                                      icon: Icons.error,
                                      background: Colors.red.shade700,
                                    );
                                    return;
                                  }

                                  final horasValue = double.tryParse(horas);
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

                                    if (Navigator.canPop(sheetContext)) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    if (!mounted) return;
                                    AppSnackBar.show(
                                      context,
                                      message: "Teiker criada com sucesso!",
                                      icon: Icons.check,
                                      background: Colors.green.shade700,
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    AppSnackBar.show(
                                      context,
                                      message: "Erro ao criar Teiker: $e",
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
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _clienteAdd() {
    final nameController = TextEditingController();
    final moradaController = TextEditingController();
    final telemovelController = TextEditingController();
    final emailController = TextEditingController();
    final orcamentoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              left: 12,
              right: 12,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(.12),
                          child: Icon(
                            Icons.home_work_outlined,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Adicionar Cliente",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _formInput("Nome", nameController),
                    const SizedBox(height: 10),
                    _formInput("Morada", moradaController),
                    const SizedBox(height: 10),
                    _formInput(
                      "Telemóvel",
                      telemovelController,
                      keyboard: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _formInput(
                      "Email",
                      emailController,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _formInput(
                      "Orçamento (€)",
                      orcamentoController,
                      keyboard: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Cancelar"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text(
                              "Adicionar",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final morada = moradaController.text.trim();
                              final telemovel = telemovelController.text.trim();
                              final email = emailController.text.trim();
                              final orcamento = orcamentoController.text.trim();

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
                                final newCliente = Clientes(
                                  uid: FirebaseFirestore.instance
                                      .collection("clientes")
                                      .doc()
                                      .id,
                                  nameCliente: name,
                                  moradaCliente: morada,
                                  telemovel: int.parse(telemovel),
                                  email: email,
                                  orcamento: orc,
                                  hourasCasa: 0.0,
                                  teikersIds: [],
                                );

                                await AuthService().createCliente(newCliente);

                                if (Navigator.canPop(sheetContext)) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (!mounted) return;
                                AppSnackBar.show(
                                  context,
                                  message: "Cliente criado com sucesso!",
                                  icon: Icons.check,
                                  background: Colors.green.shade700,
                                );
                              } catch (e) {
                                if (!mounted) return;
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _formInput(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor.withOpacity(.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
