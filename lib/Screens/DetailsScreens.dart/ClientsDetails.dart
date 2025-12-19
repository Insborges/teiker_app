import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import '../../models/Clientes.dart';

class Clientsdetails extends StatefulWidget {
  final Clientes cliente;

  const Clientsdetails({super.key, required this.cliente});

  @override
  _ClientsdetailsState createState() => _ClientsdetailsState();
}

class _ClientsdetailsState extends State<Clientsdetails> {
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _moradaController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _orcamentoController;

  late double _horasCasa;

  List<Map<String, dynamic>> teikersList = [];
  List<String> selectedTeikers = [];

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
    _phoneController = TextEditingController(
      text: widget.cliente.telemovel.toString(),
    );
    _emailController = TextEditingController(text: widget.cliente.email);
    _orcamentoController = TextEditingController(
      text: widget.cliente.orcamento.toString(),
    );

    _horasCasa = widget.cliente.hourasCasa;

    _loadTeikers();
    selectedTeikers = List<String>.from(widget.cliente.teikersIds);

    _checkPendingSessionReminder();
  }

  Future<void> _loadTeikers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teikers')
        .get();

    final data = snapshot.docs.map((d) {
      final m = d.data();

      return {
        "uid": d.id,
        "name": m["name"] ?? m["nameTeiker"] ?? "Sem nome", // fallback seguro
      };
    }).toList();

    setState(() {
      teikersList = data;
    });
  }

  Future<void> _checkPendingSessionReminder() async {
    if (isAdmin == true) return;

    final pending = await _workSessionService.findOpenSession(
      widget.cliente.uid,
    );

    if (pending == null) return;

    final timestamp = pending['startTime'] as Timestamp?;
    final start = timestamp?.toDate();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSnackBar.show(
        context,
        message: "Existe um registo por terminar para esta casa.",
        icon: Icons.notification_important,
        background: Colors.orange.shade700,
      );

      _abrirDialogAdicionarHoras(
        pendingSessionId: pending['id'] as String?,
        presentStart: start != null ? TimeOfDay.fromDateTime(start) : null,
        defaultDate: start,
      );
    });
  }

  Future<void> _guardarHoras(
    DateTime inicio,
    DateTime fim, {
    String? pendingSessionId,
  }) async {
    try {
      double total;
      if (pendingSessionId != null) {
        total = await _workSessionService.closePendingSession(
          clienteId: widget.cliente.uid,
          sessionId: pendingSessionId,
          start: inicio,
          end: fim,
        );
      } else {
        total = await _workSessionService.addManualSession(
          clienteId: widget.cliente.uid,
          start: inicio,
          end: fim,
        );
      }

      setState(() {
        _horasCasa = total;
        widget.cliente.hourasCasa = total;
      });

      AppSnackBar.show(
        context,
        message: "Horas registadas. Total do mês: ${total.toStringAsFixed(2)}h",
        icon: Icons.save,
        background: Colors.green.shade700,
      );
    } catch (e) {
      AppSnackBar.show(
        context,
        message: "Erro a guardar horas: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  //Dialog "Adicionar Horas"
  void _abrirDialogAdicionarHoras({
    String? pendingSessionId,
    TimeOfDay? presentStart,
    TimeOfDay? presentEnd,
    DateTime? defaultDate,
  }) {
    TimeOfDay? startTime;
    TimeOfDay? endTime;

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
                                  if (startTime == null || endTime == null) {
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
                                    startTime!.hour,
                                    startTime.minute,
                                  );
                                  final endDate = DateTime(
                                    baseDate.year,
                                    baseDate.month,
                                    baseDate.day,
                                    endTime!.hour,
                                    endTime.minute,
                                  );

                                  if (!endDate.isAfter(startDate)) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "A hora de fim deve ser posterior à hora de inicio. ",
                                      icon: Icons.info,
                                      background: Colors.orange.shade700,
                                    );
                                  }
                                  await _guardarHoras(
                                    startDate,
                                    endDate,
                                    pendingSessionId: pendingSessionId,
                                  );

                                  if (mounted) {
                                    Navigator.pop(context, true);
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
      telemovel: int.tryParse(_phoneController.text) ?? 0,
      email: _emailController.text,
      orcamento: double.tryParse(_orcamentoController.text) ?? 0,
      hourasCasa: _horasCasa,
      teikersIds: selectedTeikers,
    );

    try {
      // 1️⃣ Atualiza o cliente
      await AuthService().updateCliente(updated);

      final teikersRef = FirebaseFirestore.instance.collection('teikers');

      // 2️⃣ Adiciona cliente às Teikers selecionadas
      for (String teikerId in selectedTeikers) {
        await teikersRef.doc(teikerId).update({
          'clientesIds': FieldValue.arrayUnion([updated.uid]),
        });
      }

      // 3️⃣ Remove cliente das Teikers desmarcadas
      final desmarcadas = widget.cliente.teikersIds
          .where((id) => !selectedTeikers.contains(id))
          .toList();

      for (String teikerId in desmarcadas) {
        await teikersRef.doc(teikerId).update({
          'clientesIds': FieldValue.arrayRemove([updated.uid]),
        });
      }

      // 4️⃣ Feedback ao utilizador
      AppSnackBar.show(
        context,
        message: "Dados atualizados com sucesso!",
        icon: Icons.save,
        background: Colors.green.shade700,
      );

      // 5️⃣ Atualiza estado local do cliente para manter sincronia
      setState(() {
        widget.cliente.teikersIds = List.from(selectedTeikers);
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

  void emitirFaturas() {
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
          TextButton(
            onPressed: () {
              atualizarDadosCliente();
              Navigator.pop(context, true);
            },
            child: Row(
              children: [
                Icon(Icons.save, color: Colors.white),
                SizedBox(width: 5),
                Text('Guardar', style: TextStyle(color: Colors.white)),
              ],
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
            _buildTeikersSelector(),
            SizedBox(height: 16),
            _buildHorasCard(_horasCasa),
            SizedBox(height: 8),
            _buildOrcamentoCard(widget.cliente.orcamento),

            SizedBox(height: 16),

            // BOTÃO PARA ADICIONAR HORAS
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
    return Scaffold(
      appBar: buildAppBar(widget.cliente.nameCliente, seta: true),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMapCard(widget.cliente.moradaCliente),
            SizedBox(height: 12),
            _buildTextField('Nome', _nameController, readOnly: true),
            SizedBox(height: 12),

            _buildTextField('Morada', _moradaController, readOnly: true),

            SizedBox(height: 20),

            AppButton(
              text: "Adicionar Horas",
              icon: Icons.timer,
              color: Color.fromARGB(255, 4, 76, 32),
              onPressed: () => _abrirDialogAdicionarHoras(),
            ),
          ],
        ),
      ),
    );
  }

  //Mapa(mostra morada)
  Widget _buildMapCard(String endereco) {
    final mapUrl =
        'https://maps.googleapis.com/maps/api/staticmap?center=${Uri.encodeComponent(endereco)}&zoom=15&size=600x300&markers=color:red%7C${Uri.encodeComponent(endereco)}&key={APIKEY}';

    return Container(
      width: double.infinity,
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(mapUrl, fit: BoxFit.cover),
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
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
  Widget _buildOrcamentoCard(double? orcamento /*String? tipo*/) {
    if (orcamento == null) return const SizedBox.shrink();

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
          Text(
            'Orçamento: ${orcamento.toStringAsFixed(2)} CHF',
            /*${tipo ?? ""}*/
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeikersSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Teikers Associadas",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),

          if (teikersList.isEmpty) const Text("Sem teikers."),
          if (teikersList.isNotEmpty)
            ...teikersList.map((t) {
              final id = t['uid'];

              return CheckboxListTile(
                value: selectedTeikers.contains(id),
                title: Text(t['name']),
                activeColor: const Color.fromARGB(255, 4, 76, 32),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selectedTeikers.add(id);
                    } else {
                      selectedTeikers.remove(id);
                    }
                  });
                },
              );
            }),
        ],
      ),
    );
  }
}
