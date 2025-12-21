import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/DatePickerBottomSheet.dart';
import '../../models/Clientes.dart';
import '../../models/Teikers.dart';
import '../../Widgets/AppBar.dart';
import '../../Widgets/AppButton.dart';
import '../../Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/TeikerService.dart';
import 'package:teiker_app/backend/auth_service.dart';

class TeikersDetails extends StatefulWidget {
  final Teiker teiker;
  const TeikersDetails({super.key, required this.teiker});

  @override
  State<TeikersDetails> createState() => _TeikersDetailsState();
}

class _TeikersDetailsState extends State<TeikersDetails> {
  final Color _primaryColor = const Color.fromARGB(255, 4, 76, 32);
  late TextEditingController _emailController;
  late TextEditingController _telemovelController;
  DateTime? _feriasInicio;
  DateTime? _feriasFim;
  final Map<String, Clientes> _clientes = {};
  late Future<Map<String, double>> _hoursFuture;
  late List<Consulta> _consultas;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.teiker.email);
    _telemovelController = TextEditingController(
      text: widget.teiker.telemovel.toString(),
    );

    _feriasInicio = widget.teiker.feriasInicio;
    _feriasFim = widget.teiker.feriasFim;
    _consultas = List<Consulta>.from(widget.teiker.consultas);
    _hoursFuture = _fetchTeikerHours(widget.teiker.uid);
    _loadClientes();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telemovelController.dispose();
    super.dispose();
  }

  void _guardarAlteracoes() async {
    final newTelemovel = int.tryParse(_telemovelController.text.trim());

    if (newTelemovel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos corretamente.")),
      );
      return;
    }

    try {
      final updatedTeiker = widget.teiker.copyWith(
        telemovel: newTelemovel,
        consultas: _consultas,
      );

      await TeikerService().updateTeiker(updatedTeiker);

      AppSnackBar.show(
        context,
        message: "Atualizações realizadas com sucesso!",
        icon: Icons.check_box_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      AppSnackBar.show(
        context,
        message: "Erro ao guardar alterações: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _saveConsultas({
    String successMessage = "Consulta guardada.",
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('teikers')
          .doc(widget.teiker.uid)
          .update({
        'consultas': _consultas.map((c) => c.toMap()).toList(),
      });

      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: successMessage,
        icon: Icons.event_available,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao guardar consulta: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _adicionarFerias() async {
    final selectedDates = await DatePickerBottomSheet.show(
      context,
      initialStart: _feriasInicio,
      initialEnd: _feriasFim,
    );

    if (selectedDates == null || selectedDates.length != 2) return;

    setState(() {
      _feriasInicio = selectedDates[0];
      _feriasFim = selectedDates[1];
    });

    await TeikerService().updateFerias(
      widget.teiker.uid,
      _feriasInicio,
      _feriasFim,
    );

    AppSnackBar.show(
      context,
      message: "Férias atualizadas!",
      icon: Icons.check,
      background: Colors.green.shade700,
    );
  }

  Future<void> _loadClientes() async {
    final all = await AuthService().getClientes();
    if (!mounted) return;
    setState(() {
      _clientes.addEntries(all.map((c) => MapEntry(c.uid, c)));
    });
  }

  Future<Map<String, double>> _fetchTeikerHours(String teikerId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
      docs = snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .get();

      docs = snapshot.docs.where((doc) {
        final start = (doc.data()['startTime'] as Timestamp?)?.toDate();
        return start != null &&
            !start.isBefore(monthStart) &&
            start.isBefore(nextMonth);
      });
    }

    final Map<String, double> hoursByCliente = {};

    for (final doc in docs) {
      final data = doc.data();
      final clienteId = data['clienteId'] as String?;
      if (clienteId == null) continue;

      double? duration = (data['durationHours'] as num?)?.toDouble();
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();

      duration ??= (start != null && end != null)
          ? end.difference(start).inMinutes / 60.0
          : null;

      if (duration != null) {
        final dur = duration;
        hoursByCliente.update(
          clienteId,
          (v) => v + dur,
          ifAbsent: () => dur,
        );
      }
    }

    return hoursByCliente;
  }

  Future<void> _openConsultaSheet({Consulta? consulta, int? index}) async {
    final result = await showModalBottomSheet<Consulta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        DateTime selectedDate = consulta?.data ?? DateTime.now();
        TimeOfDay selectedHour =
            TimeOfDay.fromDateTime(consulta?.data ?? DateTime.now());
        final descricaoCtrl = TextEditingController(
          text: consulta?.descricao ?? '',
        );

        Future<void> pickDate(StateSetter setSheetState) async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: _primaryColor,
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setSheetState(() => selectedDate = picked);
          }
        }

        Future<void> pickTime(StateSetter setSheetState) async {
          final picked = await showTimePicker(
            context: ctx,
            initialTime: selectedHour,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: _primaryColor,
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setSheetState(() => selectedHour = picked);
          }
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dateLabel =
                DateFormat("dd MMM yyyy", 'pt_PT').format(selectedDate);
            final timeLabel = selectedHour.format(context);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          consulta == null
                              ? "Adicionar consulta"
                              : "Editar consulta",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descricaoCtrl,
                      decoration: InputDecoration(
                        labelText: "Descrição",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        prefixIcon:
                            Icon(Icons.note_alt_outlined, color: _primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: _primaryColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _consultaChip(
                            icon: Icons.calendar_today,
                            label: dateLabel,
                            onTap: () => pickDate(setSheetState),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _consultaChip(
                            icon: Icons.access_time,
                            label: timeLabel,
                            onTap: () => pickTime(setSheetState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                        ),
                        onPressed: () {
                          final descricao = descricaoCtrl.text.trim();
                          if (descricao.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Adiciona uma breve descrição."),
                              ),
                            );
                            return;
                          }

                          final date = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedHour.hour,
                            selectedHour.minute,
                          );

                          Navigator.pop(
                            context,
                            Consulta(data: date, descricao: descricao),
                          );
                        },
                        label: Text(
                          consulta == null ? "Guardar consulta" : "Guardar",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      if (index == null) {
        _consultas.add(result);
      } else {
        _consultas[index] = result;
      }
    });

    await _saveConsultas(
      successMessage:
          index == null ? "Consulta adicionada." : "Consulta atualizada.",
    );
  }

  Future<void> _confirmDeleteConsulta(int index) async {
    final consulta = _consultas[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar consulta"),
        content: Text(
          "Queres eliminar a consulta de "
          "${DateFormat('dd/MM', 'pt_PT').format(consulta.data)}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _consultas.removeAt(index));
    await _saveConsultas(successMessage: "Consulta eliminada.");
  }

  Widget _consultaChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryColor.withOpacity(.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primaryColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teiker = widget.teiker;

    return Scaffold(
      appBar: buildAppBar(teiker.nameTeiker, seta: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Pessoal + Botão Guardar
            _buildSectionCard(
              title: "Informações Pessoais",
              children: [
                _buildInputField(
                  "Telemóvel",
                  _telemovelController,
                  Icons.phone,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: Icon(
                      Icons.save,
                      color: _primaryColor,
                    ),
                    label: Text(
                      "Guardar Alterações",
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _primaryColor,
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                    ),
                    onPressed: _guardarAlteracoes,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Horas (apenas texto)
            _buildSectionCard(
              title: "Horas",
              children: [
                FutureBuilder<Map<String, double>>(
                  future: _hoursFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
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
                      return const Text(
                        "Não foi possível carregar as horas.",
                        style: TextStyle(color: Colors.redAccent),
                      );
                    }

                    final data = snapshot.data ?? {};
                    if (data.isEmpty) {
                      return const Text(
                        "Sem horas registadas este mês.",
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    final total =
                        data.values.fold<double>(0, (prev, e) => prev + e);

                    return SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            "Este mês (h):",
                            "${total.toStringAsFixed(1)}h",
                          ),
                          const SizedBox(height: 8),
                          ...data.entries.map((entry) {
                            final clienteName =
                                _clientes[entry.key]?.nameCliente ??
                                    entry.key;
                            return _buildInfoRow(
                              "$clienteName:",
                              "${entry.value.toStringAsFixed(1)}h",
                              valueColor: Colors.black54,
                              valueWeight: FontWeight.w500,
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: "Consultas",
              children: [
                if (_consultas.isEmpty)
                  const Text(
                    "Nenhuma consulta registada.",
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Column(
                    children: _consultas
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildConsultaTile(
                            entry.value,
                            entry.key,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                AppButton(
                  text: "Adicionar consulta",
                  color: _primaryColor,
                  icon: Icons.medical_information,
                  onPressed: () => _openConsultaSheet(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Férias
            _buildSectionCard(
              title: "Férias",
              children: [
                if (_feriasInicio != null && _feriasFim != null)
                  Text(
                    "De ${_feriasInicio!.day}/${_feriasInicio!.month} "
                    "até ${_feriasFim!.day}/${_feriasFim!.month}",
                    style: const TextStyle(
                      color: Color.fromARGB(255, 4, 76, 32),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const Text(
                    "Ainda sem férias registadas.",
                    style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: "Adicionar férias",
                  color: _primaryColor,
                  icon: Icons.beach_access,
                  onPressed: _adicionarFerias,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Componentes auxiliares
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryColor),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _primaryColor,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _primaryColor,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color valueColor = const Color.fromARGB(255, 4, 76, 32),
    FontWeight valueWeight = FontWeight.w600,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: valueColor,
              fontWeight: valueWeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultaTile(Consulta consulta, int index) {
    final hora = DateFormat('HH:mm', 'pt_PT').format(consulta.data);
    final dia = DateFormat('dd MMM', 'pt_PT').format(consulta.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withOpacity(.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consulta.descricao.isNotEmpty
                      ? consulta.descricao
                      : "Consulta",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, color: _primaryColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "$dia · $hora",
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _consultaActionChip(
                      icon: Icons.edit_outlined,
                      label: "Editar",
                      onTap: () => _openConsultaSheet(
                        consulta: consulta,
                        index: index,
                      ),
                    ),
                    _consultaActionChip(
                      icon: Icons.delete_outline,
                      label: "Eliminar",
                      danger: true,
                      onTap: () => _confirmDeleteConsulta(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _consultaActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade700 : _primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: danger ? Colors.red.shade50 : _primaryColor.withOpacity(.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
