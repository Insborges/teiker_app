import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/CurveAppBarClipper.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/SingleTimePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/app_pill_tab_bar.dart';
import 'package:teiker_app/Widgets/client_service_dialogs.dart';
import 'package:teiker_app/Widgets/client_details_tab_contents.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/client_invoice_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/models/client_invoice.dart';
import 'package:teiker_app/theme/app_colors.dart';
import '../../models/Clientes.dart';

class Clientsdetails extends StatefulWidget {
  final Clientes cliente;
  final VoidCallback? onSessionClosed;

  const Clientsdetails({
    super.key,
    required this.cliente,
    this.onSessionClosed,
  });

  @override
  _ClientsdetailsState createState() => _ClientsdetailsState();
}

class _ClientsdetailsState extends State<Clientsdetails> {
  static const List<String> _serviceCatalog = [
    'Shopping',
    'Laundry',
    'Preparação de refeições',
    'Passar a ferro',
    'Medicação',
    'Companhia',
    'Transporte',
    'Limpeza profunda',
  ];

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _moradaController;
  late TextEditingController _cidadeController;
  late TextEditingController _codigoPostalController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _orcamentoController;
  late Map<String, double> _appliedServicePrices;
  late String _serviceMonthKey;

  late double _horasCasa;
  late String _phoneCountryIso;

  AppUserRole? _role;
  List<String> _associatedTeikerNames = const <String>[];
  final WorkSessionService _workSessionService = WorkSessionService();
  final ClientInvoiceService _clientInvoiceService = ClientInvoiceService();
  final Set<String> _sharingInvoiceIds = <String>{};
  final Set<String> _deletingInvoiceIds = <String>{};
  bool _issuingInvoice = false;

  bool get _isAdmin => _role == AppUserRole.admin;
  bool get _isHr => _role == AppUserRole.hr;
  bool get _isPrivileged => _role?.isPrivileged == true;

  @override
  void initState() {
    super.initState();

    _role = AuthService().currentUserRole;

    _nameController = TextEditingController(text: widget.cliente.nameCliente);
    _moradaController = TextEditingController(
      text: widget.cliente.moradaCliente,
    );
    _cidadeController = TextEditingController(
      text: widget.cliente.cidadeCliente,
    );
    _codigoPostalController = TextEditingController(
      text: widget.cliente.codigoPostal,
    );
    _phoneController = TextEditingController(
      text: widget.cliente.telemovel.toString(),
    );
    _phoneCountryIso = widget.cliente.phoneCountryIso;
    _emailController = TextEditingController(text: widget.cliente.email);
    _orcamentoController = TextEditingController(
      text: widget.cliente.orcamento.toString(),
    );
    _serviceMonthKey = _monthKey(DateTime.now());
    final monthServices =
        widget.cliente.additionalServicePricesByMonth[_serviceMonthKey] ??
        widget.cliente.additionalServicePrices;
    _appliedServicePrices = Map<String, double>.fromEntries(
      monthServices.entries.where(
        (entry) => _serviceCatalog.contains(_serviceBaseName(entry.key)),
      ),
    );

    _horasCasa = widget.cliente.hourasCasa;
    _loadAssociatedTeikerNames();
    _checkPendingSessionReminder();
    _loadHorasParaTeiker();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _moradaController.dispose();
    _cidadeController.dispose();
    _codigoPostalController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _orcamentoController.dispose();
    super.dispose();
  }

  Map<String, double>? _collectServicePrices({required bool validate}) {
    return Map<String, double>.from(_appliedServicePrices);
  }

  Future<void> _loadAssociatedTeikerNames() async {
    if (!_isAdmin) {
      if (!mounted) return;
      setState(() => _associatedTeikerNames = const <String>[]);
      return;
    }

    final ids = widget.cliente.teikersIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _associatedTeikerNames = const <String>[]);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teikers')
          .get();
      final byId = <String, String>{};
      for (final doc in snapshot.docs) {
        final raw = (doc.data()['name'] as String?)?.trim();
        byId[doc.id] = (raw == null || raw.isEmpty) ? doc.id : raw;
      }
      final names = ids.map((id) => byId[id] ?? id).toList()..sort();
      if (!mounted) return;
      setState(() => _associatedTeikerNames = names);
    } catch (_) {
      if (!mounted) return;
      setState(() => _associatedTeikerNames = ids);
    }
  }

  String _serviceBaseName(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return '';

    final bySuffix = RegExp(r'^(.*?)[xX]\s*\d+$').firstMatch(trimmed);
    if (bySuffix != null) {
      return (bySuffix.group(1) ?? '').trim();
    }

    final byParenthesis = RegExp(r'^(.*?)\(\d+\s*[xX]\)$').firstMatch(trimmed);
    if (byParenthesis != null) {
      return (byParenthesis.group(1) ?? '').trim();
    }

    return trimmed;
  }

  int _serviceQuantityFromKey(String rawKey) {
    final trimmed = rawKey.trim();
    final bySuffix = RegExp(r'^[\s\S]*?[xX]\s*(\d+)$').firstMatch(trimmed);
    if (bySuffix != null) {
      final quantity = int.tryParse(bySuffix.group(1) ?? '');
      if (quantity != null && quantity > 0) return quantity;
    }

    final byParenthesis = RegExp(
      r'^[\s\S]*?\((\d+)\s*[xX]\)$',
    ).firstMatch(trimmed);
    if (byParenthesis != null) {
      final quantity = int.tryParse(byParenthesis.group(1) ?? '');
      if (quantity != null && quantity > 0) return quantity;
    }

    return 1;
  }

  String _serviceKeyWithQuantity(String baseName, int quantity) {
    if (quantity <= 1) return baseName;
    return '$baseName x$quantity';
  }

  MapEntry<String, double>? _findServiceEntryByBaseName(String baseName) {
    final normalizedBase = baseName.trim().toLowerCase();
    for (final entry in _appliedServicePrices.entries) {
      if (_serviceBaseName(entry.key).toLowerCase() == normalizedBase) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _persistAdditionalServices() async {
    final monthly = Map<String, Map<String, double>>.from(
      widget.cliente.additionalServicePricesByMonth,
    );
    monthly[_serviceMonthKey] = Map<String, double>.from(_appliedServicePrices);

    await FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.cliente.uid)
        .update({
          'additionalServicePrices': Map<String, double>.from(
            _appliedServicePrices,
          ),
          'additionalServicePricesByMonth': monthly,
        });

    widget.cliente.additionalServicePrices = Map<String, double>.from(
      _appliedServicePrices,
    );
    widget.cliente.additionalServicePricesByMonth = monthly;
  }

  Future<void> _removeAppliedService(String service) async {
    setState(() {
      _appliedServicePrices.remove(service);
    });
    try {
      await _persistAdditionalServices();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao guardar serviço removido: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _openAddServiceDialog() async {
    if (_serviceCatalog.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Sem serviços disponíveis para adicionar.',
        icon: Icons.info_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    final options = _serviceCatalog
        .map((service) => ServicePickerOption(id: service, label: service))
        .toList();

    final picked = await showModalBottomSheet<ServicePickerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: .78,
        child: ServiceSearchPickerSheet(
          title: 'Selecionar serviço',
          subtitle: 'Procura e escolhe o serviço',
          searchHint: 'Pesquisar serviço',
          options: options,
          selectedId: null,
          primaryColor: AppColors.primaryGreen,
        ),
      ),
    );

    if (!mounted) return;
    if (picked == null) return;

    final selectedService = picked.id;
    final price = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServicePriceSheet(
        serviceName: selectedService,
        primaryColor: AppColors.primaryGreen,
        initialPrice: () {
          final existing = _findServiceEntryByBaseName(selectedService);
          if (existing == null) return null;
          final quantity = _serviceQuantityFromKey(existing.key);
          return existing.value / quantity;
        }(),
      ),
    );

    if (!mounted) return;
    if (price == null) return;
    setState(() {
      final existing = _findServiceEntryByBaseName(selectedService);
      if (existing == null) {
        _appliedServicePrices[selectedService] = price;
      } else {
        final previousQuantity = _serviceQuantityFromKey(existing.key);
        final nextQuantity = previousQuantity + 1;
        final nextTotal = existing.value + price;
        _appliedServicePrices.remove(existing.key);
        _appliedServicePrices[_serviceKeyWithQuantity(
              selectedService,
              nextQuantity,
            )] =
            nextTotal;
      }
    });
    try {
      await _persistAdditionalServices();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao guardar serviço: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String get _serviceMonthLabel =>
      DateFormat('MMMM yyyy', 'pt_PT').format(DateTime.now());

  Future<void> _loadHorasParaTeiker() async {
    if (_isPrivileged) return;
    final total = await _workSessionService.calculateMonthlyTotalForCurrentUser(
      clienteId: widget.cliente.uid,
      referenceDate: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _horasCasa = total);
  }

  Future<void> _checkPendingSessionReminder() async {
    if (_isPrivileged) return;

    final pending = await _workSessionService.findOpenSession(
      widget.cliente.uid,
    );

    if (pending == null) return;

    final start = pending.startTime;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSnackBar.show(
        context,
        message: "Existe um registo por terminar para esta casa.",
        icon: Icons.notification_important,
        background: Colors.orange.shade700,
      );

      _abrirDialogAdicionarHoras(
        pendingSessionId: pending.id,
        presentStart: TimeOfDay.fromDateTime(start),
        defaultDate: start,
      );
    });
  }

  Future<double> _guardarHoras(
    DateTime inicio,
    DateTime fim, {
    String? pendingSessionId,
  }) async {
    if (pendingSessionId != null) {
      return _workSessionService.closePendingSession(
        clienteId: widget.cliente.uid,
        sessionId: pendingSessionId,
        end: fim,
      );
    }

    return _workSessionService.addManualSession(
      clienteId: widget.cliente.uid,
      start: inicio,
      end: fim,
    );
  }

  //Dialog "Adicionar Horas"
  void _abrirDialogAdicionarHoras({
    String? pendingSessionId,
    TimeOfDay? presentStart,
    TimeOfDay? presentEnd,
    DateTime? defaultDate,
  }) {
    TimeOfDay? startTime = presentStart;
    TimeOfDay? endTime = presentEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Registar Horas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked =
                                await SingleTimePickerBottomSheet.show(
                                  context,
                                  initialTime: startTime ?? TimeOfDay.now(),
                                  title: 'Hora de início',
                                  subtitle: 'Escolhe a hora inicial',
                                  confirmLabel: 'Confirmar',
                                );
                            if (picked == null) return;
                            setModalState(() => startTime = picked);
                          },
                          child: _buildTimeInput("Hora de início", startTime),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked =
                                await SingleTimePickerBottomSheet.show(
                                  context,
                                  initialTime: endTime ?? TimeOfDay.now(),
                                  title: 'Hora de fim',
                                  subtitle: 'Escolhe a hora final',
                                  confirmLabel: 'Confirmar',
                                );
                            if (picked == null) return;
                            setModalState(() => endTime = picked);
                          },
                          child: _buildTimeInput("Hora de fim", endTime),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                text: "Cancelar",
                                outline: true,
                                color: const Color.fromARGB(255, 4, 76, 32),
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  if (Navigator.canPop(context)) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                text: "Guardar",
                                color: const Color.fromARGB(255, 4, 76, 32),
                                onPressed: () async {
                                  final startValue = startTime;
                                  final endValue = endTime;

                                  if (startValue == null || endValue == null) {
                                    AppSnackBar.show(
                                      context,
                                      message: "Preenche as duas horas.",
                                      icon: Icons.info,
                                      background: Colors.orange.shade700,
                                    );
                                    return;
                                  }

                                  final baseDate =
                                      defaultDate ?? DateTime.now();
                                  final startDate = DateTime(
                                    baseDate.year,
                                    baseDate.month,
                                    baseDate.day,
                                    startValue.hour,
                                    startValue.minute,
                                  );
                                  final endDate = DateTime(
                                    baseDate.year,
                                    baseDate.month,
                                    baseDate.day,
                                    endValue.hour,
                                    endValue.minute,
                                  );
                                  final now = DateTime.now();

                                  if (startDate.isAfter(now) ||
                                      endDate.isAfter(now)) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "Não podes adicionar antes da hora",
                                      icon: Icons.info_outline,
                                      background: Colors.red.shade700,
                                    );
                                    return;
                                  }

                                  if (!endDate.isAfter(startDate)) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "A hora de fim deve ser posterior à hora de inicio. ",
                                      icon: Icons.info,
                                      background: Colors.orange.shade700,
                                    );
                                    return;
                                  }
                                  try {
                                    final total = await _guardarHoras(
                                      startDate,
                                      endDate,
                                      pendingSessionId: pendingSessionId,
                                    );
                                    final displayTotal = _isPrivileged
                                        ? total
                                        : await _workSessionService
                                              .calculateMonthlyTotalForCurrentUser(
                                                clienteId: widget.cliente.uid,
                                                referenceDate: startDate,
                                              );
                                    setState(() {
                                      _horasCasa = displayTotal;
                                      if (_isPrivileged) {
                                        widget.cliente.hourasCasa = total;
                                      }
                                    });
                                    widget.onSessionClosed?.call();

                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "Horas registadas. Total do mês: ${displayTotal.toStringAsFixed(2)}h",
                                      icon: Icons.save,
                                      background: Colors.green.shade700,
                                    );

                                    if (mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (e) {
                                    AppSnackBar.show(
                                      context,
                                      message: "Erro a guardar horas: $e",
                                      icon: Icons.error,
                                      background: Colors.red.shade700,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void atualizarDadosCliente() async {
    final additionalServicePrices = _collectServicePrices(validate: true);
    if (additionalServicePrices == null) return;
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (phone.isEmpty && email.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Preenche o telemóvel ou o email.',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    if (phone.isNotEmpty && int.tryParse(phone) == null) {
      AppSnackBar.show(
        context,
        message: 'Telemóvel inválido.',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    final additionalServicePricesByMonth =
        Map<String, Map<String, double>>.from(
          widget.cliente.additionalServicePricesByMonth,
        );
    additionalServicePricesByMonth[_serviceMonthKey] = Map<String, double>.from(
      additionalServicePrices,
    );

    final updated = Clientes(
      uid: widget.cliente.uid,
      nameCliente: _nameController.text,
      moradaCliente: _moradaController.text,
      cidadeCliente: _cidadeController.text,
      codigoPostal: _codigoPostalController.text,
      telemovel: int.tryParse(phone) ?? 0,
      phoneCountryIso: _phoneCountryIso,
      additionalServicePrices: additionalServicePrices,
      additionalServicePricesByMonth: additionalServicePricesByMonth,
      email: email,
      orcamento: double.tryParse(_orcamentoController.text) ?? 0,
      hourasCasa: _horasCasa,
      teikersIds: widget.cliente.teikersIds,
      isArchived: widget.cliente.isArchived,
      archivedBy: widget.cliente.archivedBy,
      archivedAt: widget.cliente.archivedAt,
    );

    try {
      await AuthService().updateCliente(updated);

      AppSnackBar.show(
        context,
        message: "Dados atualizados com sucesso!",
        icon: Icons.save,
        background: Colors.green.shade700,
      );

      setState(() {
        widget.cliente.nameCliente = _nameController.text;
        widget.cliente.moradaCliente = _moradaController.text;
        widget.cliente.cidadeCliente = _cidadeController.text;
        widget.cliente.codigoPostal = _codigoPostalController.text;
        widget.cliente.telemovel = int.tryParse(phone) ?? 0;
        widget.cliente.phoneCountryIso = _phoneCountryIso;
        widget.cliente.email = email;
        widget.cliente.orcamento =
            double.tryParse(_orcamentoController.text.replaceAll(',', '.')) ??
            0;
        widget.cliente.hourasCasa = _horasCasa;
        widget.cliente.teikersIds = List.from(widget.cliente.teikersIds);
        widget.cliente.additionalServicePrices = Map<String, double>.from(
          additionalServicePrices,
        );
        widget.cliente.additionalServicePricesByMonth =
            Map<String, Map<String, double>>.from(
              additionalServicePricesByMonth,
            );
      });
    } catch (e) {
      AppSnackBar.show(
        context,
        message: "Erro ao atualizar dados: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> emitirFaturas() async {
    if (_issuingInvoice) return;

    final today = DateTime.now();
    final selectedDate = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: DateTime(today.year, today.month, today.day),
      title: 'Qual e a data de emissao da fatura?',
      subtitle: 'Escolhe o dia',
      confirmLabel: 'Emitir',
    );

    if (selectedDate == null) return;

    setState(() => _issuingInvoice = true);
    try {
      final result = await _clientInvoiceService.issueInvoice(
        cliente: widget.cliente,
        invoiceDate: selectedDate,
      );

      if (!mounted) return;
      AppSnackBar.show(
        context,
        message:
            'Fatura ${result.invoice.invoiceNumber} emitida. Partilha no card abaixo.',
        icon: Icons.file_download_done,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro a emitir fatura: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _issuingInvoice = false);
      }
    }
  }

  Future<void> _shareInvoice(
    ClientInvoice invoice, {
    File? preGeneratedFile,
  }) async {
    if (_sharingInvoiceIds.contains(invoice.id)) return;

    setState(() => _sharingInvoiceIds.add(invoice.id));
    try {
      await _clientInvoiceService.shareInvoiceDocument(
        invoice,
        preGeneratedFile: preGeneratedFile,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Nao foi possivel partilhar a fatura: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _sharingInvoiceIds.remove(invoice.id));
      }
    }
  }

  Future<void> _deleteInvoice(ClientInvoice invoice) async {
    if (_deletingInvoiceIds.contains(invoice.id)) return;

    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Apagar fatura?',
      message:
          'A fatura ${invoice.invoiceNumber} vai ser removida do histórico deste cliente.',
      confirmLabel: 'Apagar',
      confirmColor: Colors.red.shade700,
    );
    if (!confirmed) return;

    setState(() => _deletingInvoiceIds.add(invoice.id));
    try {
      await _clientInvoiceService.deleteInvoice(
        clientId: widget.cliente.uid,
        invoiceId: invoice.id,
      );

      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Fatura ${invoice.invoiceNumber} apagada.',
        icon: Icons.delete_outline_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Nao foi possivel apagar a fatura: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _deletingInvoiceIds.remove(invoice.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isPrivileged ? _buildAdminLayout() : _buildTeikerLayout();
  }

  //Admin Layout
  Widget _buildAdminLayout() {
    const adminPrimary = Color.fromARGB(255, 4, 76, 32);
    final adminBorder = adminPrimary.withValues(alpha: .22);
    final currentPricePerHour =
        double.tryParse(_orcamentoController.text.replaceAll(',', '.')) ??
        widget.cliente.orcamento;
    final currentServicePrices = Map<String, double>.from(
      _appliedServicePrices,
    );

    return Scaffold(
      appBar: buildAppBar(widget.cliente.nameCliente, seta: true),
      body: DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppPillTabBar(
                primaryColor: adminPrimary,
                borderColor: adminBorder,
                tabs: const [
                  Tab(text: 'Horas & Preços'),
                  Tab(text: 'Informações'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    ClientDetailsAdminHoursTab(
                      primaryColor: adminPrimary,
                      borderColor: adminBorder,
                      currentPricePerHour: currentPricePerHour,
                      horasCasa: _horasCasa,
                      currentServicePrices: currentServicePrices,
                      onAddHoras: _abrirDialogAdicionarHoras,
                      canAddHoras: !_isHr,
                      issuingInvoice: _issuingInvoice,
                      onEmitirFaturas: emitirFaturas,
                      canEmitirFaturas: _isAdmin,
                      invoicesStream: _clientInvoiceService.watchClientInvoices(
                        widget.cliente.uid,
                      ),
                      sharingInvoiceIds: _sharingInvoiceIds,
                      deletingInvoiceIds: _deletingInvoiceIds,
                      onShareInvoice: _shareInvoice,
                      onDeleteInvoice: _deleteInvoice,
                      canShareInvoices: true,
                      canDeleteInvoices: _isAdmin,
                      serviceMonthLabel: _serviceMonthLabel,
                      appliedServicePrices: _appliedServicePrices,
                      onRemoveAppliedService: _removeAppliedService,
                      onAddService: _openAddServiceDialog,
                      canManageAdditionalServices: _isAdmin,
                    ),
                    ClientDetailsAdminInfoTab(
                      primaryColor: adminPrimary,
                      borderColor: adminBorder,
                      nameController: _nameController,
                      moradaController: _moradaController,
                      cidadeController: _cidadeController,
                      codigoPostalController: _codigoPostalController,
                      phoneController: _phoneController,
                      phoneCountryIso: _phoneCountryIso,
                      onPhoneCountryChanged: (iso) {
                        setState(() => _phoneCountryIso = iso);
                      },
                      emailController: _emailController,
                      orcamentoController: _orcamentoController,
                      onSave: atualizarDadosCliente,
                      readOnly: !_isAdmin,
                      associatedTeikerNames: _associatedTeikerNames,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //Layout Teiker
  Widget _buildTeikerLayout() {
    final primary = const Color.fromARGB(255, 4, 76, 32);
    const fieldBorder = AppColors.creamBackground;
    final fieldLabel = AppColors.creamBackground.withValues(alpha: .88);
    const fieldText = AppColors.creamBackground;
    final fieldFill = AppColors.creamBackground.withValues(alpha: .14);
    const double buttonHeight = 56;
    const double curveHeight = 410;

    return Scaffold(
      appBar: buildAppBar(widget.cliente.nameCliente, seta: true),
      body: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: curveHeight,
              child: ClipPath(
                clipper: CurvedCalendarClipper(),
                child: Container(color: primary),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.person, color: Colors.white, size: 100),
                  ),
                  const SizedBox(height: 10),
                  ClientDetailsStyledField(
                    label: 'Nome',
                    controller: _nameController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.person_outline,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: 12),
                  ClientDetailsStyledField(
                    label: 'Rua',
                    controller: _moradaController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.home_outlined,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: 12),
                  ClientDetailsStyledField(
                    label: 'Código Postal',
                    controller: _codigoPostalController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.local_post_office_outlined,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: 12),
                  ClientDetailsStyledField(
                    label: 'Cidade',
                    controller: _cidadeController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.location_city_outlined,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: buttonHeight + 12),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              // metade do botão dentro da área verde e metade fora
              top: curveHeight - (buttonHeight / 2),
              child: SizedBox(
                height: buttonHeight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.timer, size: 20),
                  label: const Text(
                    'Adicionar Horas',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () => _abrirDialogAdicionarHoras(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput(String label, TimeOfDay? time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 4, 76, 32),
          width: 1.3,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Color.fromARGB(255, 4, 76, 32)),
          const SizedBox(width: 12),
          Text(
            time == null ? label : "$label: ${time.format(context)}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
