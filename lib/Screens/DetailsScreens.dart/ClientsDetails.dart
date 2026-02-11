import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/cupertino_time_picker_sheet.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/CurveAppBarClipper.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/monthly_hours_overview_card.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/work_sessions/application/monthly_hours_overview_service.dart';
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
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _moradaController;
  late TextEditingController _codigoPostalController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _orcamentoController;

  late double _horasCasa;

  bool? isAdmin;
  final WorkSessionService _workSessionService = WorkSessionService();
  final MonthlyHoursOverviewService _hoursOverviewService =
      MonthlyHoursOverviewService();
  late Future<Map<DateTime, double>> _hoursOverviewFuture;

  @override
  void initState() {
    super.initState();

    isAdmin = AuthService().isCurrentUserAdmin;

    _nameController = TextEditingController(text: widget.cliente.nameCliente);
    _moradaController = TextEditingController(
      text: widget.cliente.moradaCliente,
    );
    _codigoPostalController = TextEditingController(
      text: widget.cliente.codigoPostal,
    );
    _phoneController = TextEditingController(
      text: widget.cliente.telemovel.toString(),
    );
    _emailController = TextEditingController(text: widget.cliente.email);
    _orcamentoController = TextEditingController(
      text: widget.cliente.orcamento.toString(),
    );

    _horasCasa = widget.cliente.hourasCasa;
    _hoursOverviewFuture = _buildHoursOverviewFuture();

    _checkPendingSessionReminder();
    _loadHorasParaTeiker();
  }

  Future<void> _loadHorasParaTeiker() async {
    if (isAdmin == true) return;
    final total = await _workSessionService.calculateMonthlyTotalForCurrentUser(
      clienteId: widget.cliente.uid,
      referenceDate: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _horasCasa = total);
  }

  Future<Map<DateTime, double>> _buildHoursOverviewFuture() {
    final currentUserId = FirebaseService().currentUser?.uid;
    final teikerId = isAdmin == true ? null : currentUserId;
    return _hoursOverviewService.fetchMonthlyTotals(
      teikerId: teikerId,
      clienteId: widget.cliente.uid,
    );
  }

  void _refreshHoursOverview() {
    setState(() {
      _hoursOverviewFuture = _buildHoursOverviewFuture();
    });
  }

  Future<void> _checkPendingSessionReminder() async {
    if (isAdmin == true) return;

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
                          onTap: () => showCupertinoTimePickerSheet(
                            context,
                            initialTime: startTime ?? TimeOfDay.now(),
                            onChanged: (time) {
                              setModalState(() {
                                startTime = time;
                              });
                            },
                          ),
                          child: _buildTimeInput("Hora de início", startTime),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => showCupertinoTimePickerSheet(
                            context,
                            initialTime: endTime ?? TimeOfDay.now(),
                            onChanged: (time) {
                              setModalState(() {
                                endTime = time;
                              });
                            },
                          ),
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
                                onPressed: () => Navigator.pop(context),
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
                                    final displayTotal = isAdmin == true
                                        ? total
                                        : await _workSessionService
                                              .calculateMonthlyTotalForCurrentUser(
                                                clienteId: widget.cliente.uid,
                                                referenceDate: startDate,
                                              );
                                    setState(() {
                                      _horasCasa = displayTotal;
                                      if (isAdmin == true) {
                                        widget.cliente.hourasCasa = total;
                                      }
                                    });
                                    _refreshHoursOverview();
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
    final updated = Clientes(
      uid: widget.cliente.uid,
      nameCliente: _nameController.text,
      moradaCliente: _moradaController.text,
      codigoPostal: _codigoPostalController.text,
      telemovel: int.tryParse(_phoneController.text) ?? 0,
      email: _emailController.text,
      orcamento: double.tryParse(_orcamentoController.text) ?? 0,
      hourasCasa: _horasCasa,
      teikersIds: widget.cliente.teikersIds,
      isArchived: widget.cliente.isArchived,
      archivedBy: widget.cliente.archivedBy,
      archivedAt: widget.cliente.archivedAt,
    );

    try {
      // 1️⃣ Atualiza o cliente
      await AuthService().updateCliente(updated);

      // 4️⃣ Feedback ao utilizador
      AppSnackBar.show(
        context,
        message: "Dados atualizados com sucesso!",
        icon: Icons.save,
        background: Colors.green.shade700,
      );

      // 5️⃣ Atualiza estado local do cliente para manter sincronia
      setState(() {
        widget.cliente.teikersIds = List.from(widget.cliente.teikersIds);
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
    final today = DateTime.now();
    final selectedDate = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: DateTime(today.year, today.month, today.day),
      title: 'Qual e a data de emissao da fatura?',
      subtitle: 'Escolhe o dia',
      confirmLabel: 'Emitir',
    );

    if (selectedDate == null) return;

    AppSnackBar.show(
      context,
      message: "Fatura Emitida(ainda em desenvolvimento)",
      icon: Icons.file_download_done,
      background: Colors.green.shade700,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isAdmin == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return isAdmin! ? _buildAdminLayout() : _buildTeikerLayout();
  }

  //Admin Layout
  Widget _buildAdminLayout() {
    const adminPrimary = Color.fromARGB(255, 4, 76, 32);
    final adminBorder = adminPrimary.withValues(alpha: .22);

    return Scaffold(
      appBar: buildAppBar(
        widget.cliente.nameCliente,
        seta: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 4, 76, 32),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                atualizarDadosCliente();
                Navigator.pop(context, true);
              },
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              'Nome',
              _nameController,
              borderColor: adminBorder,
              focusColor: adminPrimary,
              fillColor: Colors.white,
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Morada',
              _moradaController,
              borderColor: adminBorder,
              focusColor: adminPrimary,
              fillColor: Colors.white,
              prefixIcon: Icons.home_outlined,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Código Postal',
              _codigoPostalController,
              borderColor: adminBorder,
              focusColor: adminPrimary,
              fillColor: Colors.white,
              prefixIcon: Icons.local_post_office_outlined,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Telefone',
              _phoneController,
              keyboard: TextInputType.phone,
              borderColor: adminBorder,
              focusColor: adminPrimary,
              fillColor: Colors.white,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Email',
              _emailController,
              keyboard: TextInputType.emailAddress,
              borderColor: adminBorder,
              focusColor: adminPrimary,
              fillColor: Colors.white,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Preço/Hora',
              _orcamentoController,
              keyboard: TextInputType.number,
              borderColor: adminBorder,
              focusColor: adminPrimary,
              fillColor: Colors.white,
              prefixIcon: Icons.payments_outlined,
            ),
            const SizedBox(height: 12),
            _buildHorasCard(_horasCasa),
            const SizedBox(height: 12),
            _buildMonthlyHoursSection(),
            const SizedBox(height: 8),
            AppButton(
              text: "Adicionar Horas",
              icon: Icons.timer,
              color: const Color.fromARGB(255, 4, 76, 32),
              onPressed: () => _abrirDialogAdicionarHoras(),
            ),
            const SizedBox(height: 12),
            _buildOrcamentoCard(widget.cliente.orcamento, _horasCasa),

            const SizedBox(height: 16),

            // Emitir faturas
            AppButton(
              text: "Emitir Faturas",
              icon: Icons.file_copy,
              color: Color.fromARGB(255, 4, 76, 32),
              onPressed: () => emitirFaturas(),
            ),
          ],
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
    const double buttonHeight = 52;
    const double curveHeight = 340;

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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.person, color: Colors.white, size: 100),
                  ),
                  const SizedBox(height: 6),
                  _buildTextField(
                    'Nome',
                    _nameController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.person_outline,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Morada',
                    _moradaController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.home_outlined,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Código Postal',
                    _codigoPostalController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    prefixIcon: Icons.local_post_office_outlined,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                    fillColor: fieldFill,
                  ),
                  const SizedBox(height: buttonHeight / 2),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
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

  //TextField (tem também só ler)
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    Color? borderColor,
    Color? focusColor,
    Color? labelColor,
    Color? textColor,
    Color fillColor = Colors.white,
    IconData? prefixIcon,
  }) {
    return AppTextField(
      label: label,
      controller: controller,
      prefixIcon: prefixIcon,
      readOnly: readOnly,
      keyboard: keyboard,
      focusColor: focusColor ?? borderColor ?? Colors.grey.shade600,
      fillColor: fillColor,
      borderColor: borderColor ?? Colors.grey.shade400,
      enableInteractiveSelection: !readOnly,
      style: textColor != null
          ? TextStyle(color: textColor, fontWeight: FontWeight.w600)
          : null,
      labelStyle: labelColor != null
          ? TextStyle(color: labelColor, fontWeight: FontWeight.w600)
          : null,
      borderRadius: 12,
    );
  }

  //Card das horas
  Widget _buildHorasCard(double horas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: horas >= 40 ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: horas >= 40
              ? Colors.green
              : const Color.fromARGB(255, 185, 64, 55),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: horas >= 40
                ? Colors.green
                : const Color.fromARGB(255, 185, 64, 55),
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Horas na casa: ${horas.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: horas >= 40 ? Colors.green.shade900 : Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyHoursSection() {
    return FutureBuilder<Map<DateTime, double>>(
      future: _hoursOverviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: const Text(
              'Não foi possível carregar o histórico de horas.',
              style: TextStyle(color: Colors.redAccent),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: .14),
            ),
          ),
          child: MonthlyHoursOverviewCard(
            monthlyTotals: snapshot.data ?? const {},
            primaryColor: const Color.fromARGB(255, 4, 76, 32),
            title: 'Horas por mês',
            emptyMessage: 'Sem horas registadas para esta casa.',
          ),
        );
      },
    );
  }

  //Card Orçamento
  Widget _buildOrcamentoCard(double? orcamento, double horas) {
    if (orcamento == null) return const SizedBox.shrink();
    final total = horas * orcamento;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade700, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: Colors.green.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preço/Hora: ${orcamento.toStringAsFixed(2)} CHF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total (${horas.toStringAsFixed(1)}h): ${total.toStringAsFixed(2)} CHF',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
