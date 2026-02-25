import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';
import 'package:teiker_app/Screens/TeikersInfoScreen.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/main_screen_add_forms.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/theme/app_colors.dart';

enum MainRole { admin, teiker }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.role});

  final MainRole role;

  bool get isAdmin => role == MainRole.admin;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selected = 0;
  bool showOptions = false;
  final PageController controller = PageController();
  final AuthService _authService = AuthService();

  bool get _isAdmin => widget.isAdmin;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => selected = index);
    controller.jumpToPage(index);
  }

  List<Widget> _pages() {
    if (_isAdmin) {
      return const [
        HomeScreen(),
        TeikersInfoScreen(),
        ClientesScreen(),
        DefinicoesScreen(role: SettingsRole.admin),
      ];
    }

    return const [
      HomeScreen(),
      ClientesScreen(),
      DefinicoesScreen(role: SettingsRole.teiker),
    ];
  }

  List<NavItemConfig> _navItems() {
    if (_isAdmin) {
      return const [
        NavItemConfig(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_filled,
          label: 'Home',
        ),
        NavItemConfig(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Teikers',
        ),
        NavItemConfig(
          icon: Icons.people_outline,
          activeIcon: Icons.groups,
          label: 'Clientes',
        ),
        NavItemConfig(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'Settings',
        ),
      ];
    }

    return const [
      NavItemConfig(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_filled,
        label: 'Home',
      ),
      NavItemConfig(
        icon: Icons.people_outline,
        activeIcon: Icons.groups,
        label: 'Clientes',
      ),
      NavItemConfig(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (_isAdmin && showOptions)
            ? () => setState(() => showOptions = false)
            : null,
        child: Stack(
          children: [
            PageView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              children: _pages(),
            ),

            if (_isAdmin && showOptions)
              Positioned(
                right: 16,
                bottom: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _fabAction(
                      icon: Icons.person_add_alt_1,
                      label: 'Adicionar Teiker',
                      onTap: () {
                        setState(() => showOptions = false);
                        _teikerAdd();
                      },
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 8),
                    _fabAction(
                      icon: Icons.home_work_outlined,
                      label: 'Adicionar Cliente',
                      onTap: () {
                        setState(() => showOptions = false);
                        _clienteAdd();
                      },
                      color: Colors.teal.shade700,
                    ),
                  ],
                ),
              ),

            Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomNavBar(
                index: selected,
                fabOpen: _isAdmin ? showOptions : false,
                showFab: _isAdmin,
                items: _navItems(),
                onTap: _onNavTap,
                onFabTap: _isAdmin
                    ? () => setState(() => showOptions = !showOptions)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _teikerAdd() async {
    try {
      final data = await showAddTeikerFormSheet(context);

      if (data == null) return;

      await _authService.createTeiker(
        name: data.name,
        email: data.email,
        password: data.password,
        telemovel: data.telemovel,
        phoneCountryIso: data.phoneCountryIso,
        birthDate: data.birthDate,
        workPercentage: data.workPercentage,
        cor: data.cor,
      );
      if (!mounted) return;
      _showSuccess('Teiker criada com sucesso!');
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao criar Teiker: $e');
    }
  }

  Future<void> _clienteAdd() async {
    try {
      final data = await showAddClienteFormSheet(context);

      if (data == null) return;

      final newCliente = Clientes(
        uid: FirebaseFirestore.instance.collection('clientes').doc().id,
        nameCliente: data.name,
        moradaCliente: data.morada,
        codigoPostal: data.codigoPostal,
        telemovel: data.telemovel,
        phoneCountryIso: data.phoneCountryIso,
        email: data.email,
        orcamento: data.orcamento,
        hourasCasa: 0.0,
        teikersIds: const [],
      );

      await _authService.createCliente(newCliente);
      if (!mounted) return;
      _showSuccess('Cliente criado com sucesso!');
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao criar cliente: $e');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AppSnackBar.show(
      context,
      message: message,
      icon: Icons.check,
      background: Colors.green.shade700,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    AppSnackBar.show(
      context,
      message: message,
      icon: Icons.error,
      background: Colors.red.shade700,
    );
  }
}
