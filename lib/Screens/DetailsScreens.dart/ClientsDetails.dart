import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/CurveAppBarClipper.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
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
        presentStart: start != null ? TimeOfDay.fromDateTime(start) : null,
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

    void pickCupertinoTime(
      BuildContext context,
      bool isStart,
      Function setModalState,
    ) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 260,
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF2F2F2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        color: Color.fromARGB(255, 4, 76, 32),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime.now(),
                    onDateTimeChanged: (newTime) {
                      setModalState(() {
                        final t = TimeOfDay.fromDateTime(newTime);
                        if (isStart) {
                          startTime = t;
                        } else {
                          endTime = t;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
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
                          onTap: () =>
                              pickCupertinoTime(context, true, setModalState),
                          child: _buildTimeInput("Hora de início", startTime),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () =>
                              pickCupertinoTime(context, false, setModalState),
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
            _buildTextField('Nome', _nameController),
            SizedBox(height: 12),
            _buildTextField('Morada', _moradaController),
            SizedBox(height: 12),
            _buildTextField('Código Postal', _codigoPostalController),
            SizedBox(height: 12),
            _buildTextField(
              'Telefone',
              _phoneController,
              keyboard: TextInputType.phone,
            ),
            SizedBox(height: 12),
            _buildTextField(
              'Email',
              _emailController,
              keyboard: TextInputType.emailAddress,
            ),
            SizedBox(height: 12),
            _buildTextField(
              'Preço/Hora',
              _orcamentoController,
              keyboard: TextInputType.number,
            ),
            SizedBox(height: 12),
            _buildHorasCard(_horasCasa),
            SizedBox(height: 8),
            AppButton(
              text: "Adicionar Horas",
              icon: Icons.timer,
              color: const Color.fromARGB(255, 4, 76, 32),
              onPressed: () => _abrirDialogAdicionarHoras(),
            ),
            SizedBox(height: 12),
            _buildOrcamentoCard(widget.cliente.orcamento, _horasCasa),

            SizedBox(height: 16),

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
    final fieldBorder = Colors.green.shade200;
    final fieldLabel = Colors.green.shade200;
    final fieldText = Colors.green.shade50;
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
                    labelColor: fieldLabel,
                    textColor: fieldText,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Morada',
                    _moradaController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    labelColor: fieldLabel,
                    textColor: fieldText,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Código Postal',
                    _codigoPostalController,
                    readOnly: true,
                    borderColor: fieldBorder,
                    labelColor: fieldLabel,
                    textColor: fieldText,
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
    Color? labelColor,
    Color? textColor,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboard,
      style: textColor != null
          ? TextStyle(color: textColor, fontWeight: FontWeight.w600)
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: labelColor != null
            ? TextStyle(color: labelColor, fontWeight: FontWeight.w600)
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey.shade400,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey.shade600,
            width: 1.4,
          ),
        ),
      ),
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
