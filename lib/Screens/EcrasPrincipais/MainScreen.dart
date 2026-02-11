import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Screens/ClientesScreen.dart';
import 'package:teiker_app/Screens/DefinicoesScreen.dart';
import 'package:teiker_app/Screens/HomeScreen.dart';
import 'package:teiker_app/Screens/TeikersInfoScreen.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/app_color_palette_picker.dart';
import 'package:teiker_app/Widgets/phone_number_input_row.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/teiker_workload.dart';
import 'package:teiker_app/theme/app_colors.dart';

enum MainRole { admin, teiker }

class _TeikerFormData {
  const _TeikerFormData({
    required this.name,
    required this.email,
    required this.password,
    required this.telemovel,
    required this.phoneCountryIso,
    required this.birthDate,
    required this.workPercentage,
    required this.cor,
  });

  final String name;
  final String email;
  final String password;
  final int telemovel;
  final String phoneCountryIso;
  final DateTime birthDate;
  final int workPercentage;
  final Color cor;
}

class _ClienteFormData {
  const _ClienteFormData({
    required this.name,
    required this.morada,
    required this.codigoPostal,
    required this.telemovel,
    required this.phoneCountryIso,
    required this.email,
    required this.orcamento,
  });

  final String name;
  final String morada;
  final String codigoPostal;
  final int telemovel;
  final String phoneCountryIso;
  final String email;
  final double orcamento;
}

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

  void _disposeControllersDeferred(
    Iterable<TextEditingController> controllers,
  ) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final controller in controllers) {
        try {
          controller.dispose();
        } catch (_) {}
      }
    });
  }

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
    Color selectedCor = const Color(0xFF2D7A4B);
    int selectedWorkPercentage = TeikerWorkload.fullTime;
    String selectedPhoneCountryIso = 'PT';
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final telemovelController = TextEditingController();
    final birthDateController = TextEditingController();
    DateTime? selectedBirthDate;

    try {
      final data = await _showFormSheet<_TeikerFormData>(
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (_, setStateSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHeader(
                    icon: Icons.person_add_alt_1,
                    title: 'Adicionar Teiker',
                    onClose: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (Navigator.canPop(sheetContext)) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _formInput('Nome', nameController),
                  const SizedBox(height: 10),
                  _formInput(
                    'Email',
                    emailController,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _formInput('Password', passwordController, obscure: true),
                  const SizedBox(height: 10),
                  PhoneNumberInputRow(
                    controller: telemovelController,
                    countryIso: selectedPhoneCountryIso,
                    onCountryChanged: (iso) {
                      setStateSheet(() => selectedPhoneCountryIso = iso);
                    },
                    primaryColor: AppColors.primaryGreen,
                    label: 'Telemóvel',
                    fillColor: Colors.white,
                    borderColor: AppColors.primaryGreen.withValues(alpha: .18),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await SingleDatePickerBottomSheet.show(
                        sheetContext,
                        initialDate: selectedBirthDate ?? DateTime(1990, 1, 1),
                        firstDate: DateTime(1900, 1, 1),
                        lastDate: DateTime.now(),
                        title: 'Data de nascimento',
                        subtitle: 'Escolhe a data de nascimento da teiker',
                        confirmLabel: 'Confirmar',
                      );
                      if (picked == null) return;
                      selectedBirthDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                      birthDateController.text = DateFormat(
                        'dd/MM/yyyy',
                        'pt_PT',
                      ).format(selectedBirthDate!);
                      setStateSheet(() {});
                    },
                    child: AbsorbPointer(
                      child: _formInput(
                        'Data de nascimento',
                        birthDateController,
                        keyboard: TextInputType.datetime,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Carga horária',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TeikerWorkload.supportedPercentages.map((value) {
                      final selected = selectedWorkPercentage == value;
                      return ChoiceChip(
                        label: Text(TeikerWorkload.labelForPercentage(value)),
                        selected: selected,
                        selectedColor: AppColors.primaryGreen.withValues(
                          alpha: .14,
                        ),
                        checkmarkColor: AppColors.primaryGreen,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primaryGreen
                              : AppColors.primaryGreen.withValues(alpha: .25),
                        ),
                        onSelected: (_) {
                          setStateSheet(() => selectedWorkPercentage = value);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Meta semanal: ${TeikerWorkload.weeklyHoursForPercentage(selectedWorkPercentage).toStringAsFixed(0)} h',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cor da Teiker',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppColorPalettePicker(
                    selectedColor: selectedCor,
                    onChanged: (color) {
                      setStateSheet(() => selectedCor = color);
                    },
                  ),
                  const SizedBox(height: 16),
                  _sheetActions(
                    sheetContext: sheetContext,
                    onConfirm: () {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      final telemovel = telemovelController.text.trim();

                      if (_hasEmpty([name, email, password, telemovel])) {
                        _showError('Preencha todos os campos');
                        return;
                      }
                      if (selectedBirthDate == null) {
                        _showError('Seleciona a data de nascimento');
                        return;
                      }

                      if (!_isDigits(telemovel)) {
                        _showError('Telemóvel inválido');
                        return;
                      }

                      FocusManager.instance.primaryFocus?.unfocus();
                      if (Navigator.canPop(sheetContext)) {
                        Navigator.of(sheetContext).pop(
                          _TeikerFormData(
                            name: name,
                            email: email,
                            password: password,
                            telemovel: int.parse(telemovel),
                            phoneCountryIso: selectedPhoneCountryIso,
                            birthDate: selectedBirthDate!,
                            workPercentage: selectedWorkPercentage,
                            cor: selectedCor,
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );

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
    } finally {
      _disposeControllersDeferred([
        nameController,
        emailController,
        passwordController,
        telemovelController,
        birthDateController,
      ]);
    }
  }

  Future<void> _clienteAdd() async {
    String selectedPhoneCountryIso = 'PT';
    final nameController = TextEditingController();
    final moradaController = TextEditingController();
    final codigoPostalPrefixController = TextEditingController();
    final codigoPostalSuffixController = TextEditingController();
    final telemovelController = TextEditingController();
    final emailController = TextEditingController();
    final orcamentoController = TextEditingController();

    try {
      final data = await _showFormSheet<_ClienteFormData>(
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (_, setStateSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHeader(
                    icon: Icons.home_work_outlined,
                    title: 'Adicionar Cliente',
                    onClose: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (Navigator.canPop(sheetContext)) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _formInput('Nome', nameController),
                  const SizedBox(height: 10),
                  _formInput('Morada', moradaController),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _formInput(
                          'Código Postal',
                          codigoPostalPrefixController,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _formInput(
                          'Sufixo',
                          codigoPostalSuffixController,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PhoneNumberInputRow(
                    controller: telemovelController,
                    countryIso: selectedPhoneCountryIso,
                    onCountryChanged: (iso) {
                      setStateSheet(() => selectedPhoneCountryIso = iso);
                    },
                    primaryColor: AppColors.primaryGreen,
                    label: 'Telemóvel',
                    fillColor: Colors.white,
                    borderColor: AppColors.primaryGreen.withValues(alpha: .18),
                  ),
                  const SizedBox(height: 10),
                  _formInput(
                    'Email',
                    emailController,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _formInput(
                    'Preço/Hora (€)',
                    orcamentoController,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _sheetActions(
                    sheetContext: sheetContext,
                    onConfirm: () {
                      final name = nameController.text.trim();
                      final morada = moradaController.text.trim();
                      final codigoPostalPrefix = codigoPostalPrefixController
                          .text
                          .trim();
                      final codigoPostalSuffix = codigoPostalSuffixController
                          .text
                          .trim();
                      final telemovel = telemovelController.text.trim();
                      final email = emailController.text.trim();
                      final orcamento = orcamentoController.text.trim();

                      if (_hasEmpty([
                        name,
                        morada,
                        codigoPostalPrefix,
                        codigoPostalSuffix,
                        telemovel,
                        email,
                        orcamento,
                      ])) {
                        _showError('Preencha todos os campos');
                        return;
                      }

                      if (!_isDigits(telemovel)) {
                        _showError('Telemóvel inválido');
                        return;
                      }

                      if (!_isDigits(codigoPostalPrefix) ||
                          !_isDigits(codigoPostalSuffix) ||
                          codigoPostalPrefix.length != 4 ||
                          codigoPostalSuffix.length != 3) {
                        _showError('Código postal inválido');
                        return;
                      }

                      final orc = double.tryParse(
                        orcamento.replaceAll(',', '.'),
                      );
                      if (orc == null) {
                        _showError('Orçamento inválido');
                        return;
                      }

                      FocusManager.instance.primaryFocus?.unfocus();
                      if (Navigator.canPop(sheetContext)) {
                        Navigator.of(sheetContext).pop(
                          _ClienteFormData(
                            name: name,
                            morada: morada,
                            codigoPostal:
                                '$codigoPostalPrefix-$codigoPostalSuffix',
                            telemovel: int.parse(telemovel),
                            phoneCountryIso: selectedPhoneCountryIso,
                            email: email,
                            orcamento: orc,
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );

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
    } finally {
      _disposeControllersDeferred([
        nameController,
        moradaController,
        codigoPostalPrefixController,
        codigoPostalSuffixController,
        telemovelController,
        emailController,
        orcamentoController,
      ]);
    }
  }

  Future<T?> _showFormSheet<T>({
    required Widget Function(BuildContext sheetContext) builder,
  }) {
    return showModalBottomSheet<T>(
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
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: .12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SingleChildScrollView(child: builder(sheetContext)),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHeader({
    required IconData icon,
    required String title,
    required VoidCallback onClose,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primaryGreen.withValues(alpha: .12),
          child: Icon(icon, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _sheetActions({
    required BuildContext sheetContext,
    required VoidCallback onConfirm,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              if (Navigator.canPop(sheetContext)) {
                Navigator.of(sheetContext).pop();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text(
              'Adicionar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }

  bool _hasEmpty(List<String> values) => values.any((value) => value.isEmpty);

  bool _isDigits(String value) => RegExp(r'^[0-9]+$').hasMatch(value);

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

  Widget _formInput(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return AppTextField(
      label: label,
      controller: controller,
      keyboard: keyboard,
      obscureText: obscure,
      focusColor: AppColors.primaryGreen,
      fillColor: Colors.white,
      borderColor: AppColors.primaryGreen.withValues(alpha: .18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
