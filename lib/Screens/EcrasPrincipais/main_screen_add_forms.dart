import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/address_autocomplete_field.dart';
import 'package:teiker_app/Widgets/app_color_palette_picker.dart';
import 'package:teiker_app/Widgets/phone_number_input_row.dart';
import 'package:teiker_app/models/teiker_workload.dart';
import 'package:teiker_app/theme/app_colors.dart';

class TeikerFormData {
  const TeikerFormData({
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

class ClienteFormData {
  const ClienteFormData({
    required this.name,
    required this.morada,
    required this.cidade,
    required this.codigoPostal,
    required this.telemovel,
    required this.phoneCountryIso,
    required this.email,
    required this.orcamento,
  });

  final String name;
  final String morada;
  final String cidade;
  final String codigoPostal;
  final int telemovel;
  final String phoneCountryIso;
  final String email;
  final double orcamento;
}

Future<TeikerFormData?> showAddTeikerFormSheet(BuildContext context) async {
  Color selectedCor = const Color(0xFF2D7A4B);
  int selectedWorkPercentage = TeikerWorkload.fullTime;
  String selectedPhoneCountryIso = 'PT';
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final telemovelController = TextEditingController();
  final birthDateController = TextEditingController();
  DateTime? selectedBirthDate;

  void showError(String message) {
    AppSnackBar.show(
      context,
      message: message,
      icon: Icons.error,
      background: Colors.red.shade700,
    );
  }

  try {
    return await _showFormSheet<TeikerFormData>(
      context,
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
                  'Email (opcional)',
                  emailController,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                _formInput(
                  'Password (se tiver email)',
                  passwordController,
                  obscure: true,
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

                    if (_hasEmpty([name, telemovel])) {
                      showError('Preencha os campos obrigatórios');
                      return;
                    }
                    if (selectedBirthDate == null) {
                      showError('Seleciona a data de nascimento');
                      return;
                    }
                    if (email.isNotEmpty && password.length < 6) {
                      showError(
                        'Se preencheres email, a password deve ter pelo menos 6 caracteres',
                      );
                      return;
                    }

                    if (!_isDigits(telemovel)) {
                      showError('Telemóvel inválido');
                      return;
                    }

                    FocusManager.instance.primaryFocus?.unfocus();
                    if (Navigator.canPop(sheetContext)) {
                      Navigator.of(sheetContext).pop(
                        TeikerFormData(
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

Future<ClienteFormData?> showAddClienteFormSheet(BuildContext context) async {
  String selectedPhoneCountryIso = 'PT';
  final nameController = TextEditingController();
  final moradaController = TextEditingController();
  final cidadeController = TextEditingController();
  final codigoPostalPrefixController = TextEditingController();
  final codigoPostalSuffixController = TextEditingController();
  final telemovelController = TextEditingController();
  final emailController = TextEditingController();
  final orcamentoController = TextEditingController();

  void showError(String message) {
    AppSnackBar.show(
      context,
      message: message,
      icon: Icons.error,
      background: Colors.red.shade700,
    );
  }

  try {
    return await _showFormSheet<ClienteFormData>(
      context,
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
                AddressAutocompleteField(
                  label: 'Morada',
                  addressController: moradaController,
                  cityController: cidadeController,
                  countryBias: const ['CH', 'PT'],
                  onPostalCodeSelected: (postalCode) {
                    _applyPostalCodeToSplitControllers(
                      postalCode,
                      prefixController: codigoPostalPrefixController,
                      suffixController: codigoPostalSuffixController,
                    );
                  },
                  focusColor: AppColors.primaryGreen,
                  fillColor: Colors.white,
                  borderColor: AppColors.primaryGreen.withValues(alpha: .18),
                ),
                const SizedBox(height: 10),
                _formInput('Cidade', cidadeController),
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
                        'Sufixo (até 4)',
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
                    final cidade = cidadeController.text.trim();
                    final codigoPostalPrefix = codigoPostalPrefixController.text
                        .trim();
                    final codigoPostalSuffix = codigoPostalSuffixController.text
                        .trim();
                    final telemovel = telemovelController.text.trim();
                    final email = emailController.text.trim();
                    final orcamento = orcamentoController.text.trim();

                    if (_hasEmpty([
                      name,
                      morada,
                      cidade,
                      codigoPostalPrefix,
                      orcamento,
                    ])) {
                      showError('Preencha todos os campos');
                      return;
                    }

                    if (telemovel.isEmpty && email.isEmpty) {
                      showError('Preencha o telemóvel ou o email');
                      return;
                    }

                    if (telemovel.isNotEmpty && !_isDigits(telemovel)) {
                      showError('Telemóvel inválido');
                      return;
                    }

                    if (!_isDigits(codigoPostalPrefix) ||
                        codigoPostalPrefix.length != 4) {
                      showError('Código postal inválido');
                      return;
                    }

                    if (codigoPostalSuffix.isNotEmpty &&
                        (!_isDigits(codigoPostalSuffix) ||
                            codigoPostalSuffix.length < 3 ||
                            codigoPostalSuffix.length > 4)) {
                      showError('Código postal inválido');
                      return;
                    }

                    final orc = double.tryParse(orcamento.replaceAll(',', '.'));
                    if (orc == null) {
                      showError('Orçamento inválido');
                      return;
                    }

                    FocusManager.instance.primaryFocus?.unfocus();
                    if (Navigator.canPop(sheetContext)) {
                      Navigator.of(sheetContext).pop(
                        ClienteFormData(
                          name: name,
                          morada: morada,
                          cidade: cidade,
                          codigoPostal: codigoPostalSuffix.isEmpty
                              ? codigoPostalPrefix
                              : '$codigoPostalPrefix-$codigoPostalSuffix',
                          telemovel: telemovel.isEmpty
                              ? 0
                              : int.parse(telemovel),
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
  } finally {
    _disposeControllersDeferred([
      nameController,
      moradaController,
      cidadeController,
      codigoPostalPrefixController,
      codigoPostalSuffixController,
      telemovelController,
      emailController,
      orcamentoController,
    ]);
  }
}

void _disposeControllersDeferred(Iterable<TextEditingController> controllers) {
  Future<void>.delayed(const Duration(milliseconds: 350), () {
    for (final controller in controllers) {
      try {
        controller.dispose();
      } catch (_) {}
    }
  });
}

Future<T?> _showFormSheet<T>(
  BuildContext context, {
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

void _applyPostalCodeToSplitControllers(
  String postalCode, {
  required TextEditingController prefixController,
  required TextEditingController suffixController,
}) {
  final normalized = postalCode.trim();
  if (normalized.isEmpty) return;

  final cleaned = normalized.replaceAll(RegExp(r'[^0-9-]'), '');
  if (cleaned.isEmpty) return;

  final hyphenMatch = RegExp(r'^(\d{4})-(\d{1,4})$').firstMatch(cleaned);
  if (hyphenMatch != null) {
    prefixController.text = hyphenMatch.group(1) ?? '';
    suffixController.text = hyphenMatch.group(2) ?? '';
    return;
  }

  final digitsOnly = cleaned.replaceAll('-', '');
  if (digitsOnly.length >= 4) {
    prefixController.text = digitsOnly.substring(0, 4);
    final suffix = digitsOnly.length > 4 ? digitsOnly.substring(4) : '';
    suffixController.text = suffix.length > 4 ? suffix.substring(0, 4) : suffix;
  }
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
