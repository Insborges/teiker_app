import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/DatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/app_section_card.dart';
import 'package:teiker_app/Widgets/consulta_item_card.dart';
import 'package:teiker_app/Widgets/monthly_hours_overview_card.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/SingleTimePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/teiker_ferias_content.dart';
import 'package:teiker_app/Widgets/teiker_personal_info_content.dart';
import 'package:teiker_app/work_sessions/application/monthly_hours_overview_service.dart';
import '../../models/Teikers.dart';
import '../../Widgets/AppBar.dart';
import '../../Widgets/AppButton.dart';
import '../../Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/TeikerService.dart';

class TeikersDetails extends StatefulWidget {
  final Teiker teiker;
  const TeikersDetails({super.key, required this.teiker});

  @override
  State<TeikersDetails> createState() => _TeikersDetailsState();
}

class _TeikersDetailsState extends State<TeikersDetails> {
  final Color _primaryColor = const Color.fromARGB(255, 4, 76, 32);
  static const String _hoursSectionTitle = 'Horas da Teiker';
  final MonthlyHoursOverviewService _hoursOverviewService =
      MonthlyHoursOverviewService();
  late TextEditingController _telemovelController;
  late List<FeriasPeriodo> _feriasPeriodos;
  late Future<Map<DateTime, double>> _hoursFuture;
  late List<Consulta> _consultas;

  @override
  void initState() {
    super.initState();
    _telemovelController = TextEditingController(
      text: widget.teiker.telemovel.toString(),
    );

    _feriasPeriodos = List<FeriasPeriodo>.from(widget.teiker.feriasPeriodos);
    if (_feriasPeriodos.isEmpty &&
        widget.teiker.feriasInicio != null &&
        widget.teiker.feriasFim != null) {
      _feriasPeriodos = [
        FeriasPeriodo(
          inicio: widget.teiker.feriasInicio!,
          fim: widget.teiker.feriasFim!,
        ),
      ];
    }
    _consultas = List<Consulta>.from(widget.teiker.consultas);
    _hoursFuture = _hoursOverviewService.fetchMonthlyTotals(
      teikerId: widget.teiker.uid,
    );
  }

  @override
  void dispose() {
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
      final lastFerias = _feriasPeriodos.isEmpty ? null : _feriasPeriodos.last;
      final updatedTeiker = widget.teiker.copyWith(
        telemovel: newTelemovel,
        consultas: _consultas,
        feriasPeriodos: _feriasPeriodos,
        feriasInicio: lastFerias?.inicio,
        feriasFim: lastFerias?.fim,
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
          .update({'consultas': _consultas.map((c) => c.toMap()).toList()});

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
    final lastPeriodo = _feriasPeriodos.isEmpty ? null : _feriasPeriodos.last;
    final selectedDates = await DatePickerBottomSheet.show(
      context,
      initialStart: lastPeriodo?.inicio,
      initialEnd: lastPeriodo?.fim,
    );

    if (selectedDates == null || selectedDates.length != 2) return;
    final inicio = selectedDates[0];
    final fim = selectedDates[1];
    if (inicio == null || fim == null) return;

    setState(() {
      _feriasPeriodos.add(FeriasPeriodo(inicio: inicio, fim: fim));
    });

    await TeikerService().addFeriasPeriodo(widget.teiker.uid, inicio, fim);

    AppSnackBar.show(
      context,
      message: "Período de férias adicionado!",
      icon: Icons.check,
      background: Colors.green.shade700,
    );
  }

  Future<void> _openConsultaSheet({Consulta? consulta, int? index}) async {
    final result = await showModalBottomSheet<Consulta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ConsultaSheet(consulta: consulta, primaryColor: _primaryColor);
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
      successMessage: index == null
          ? "Consulta adicionada."
          : "Consulta atualizada.",
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
            AppSectionCard(
              title: "Informações Pessoais",
              titleIcon: Icons.badge_outlined,
              titleColor: _primaryColor,
              children: [
                TeikerPersonalInfoContent(
                  telemovelController: _telemovelController,
                  primaryColor: _primaryColor,
                  onSave: _guardarAlteracoes,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Horas (apenas texto)
            AppSectionCard(
              title: _hoursSectionTitle,
              titleColor: _primaryColor,
              titleIcon: Icons.bar_chart_rounded,
              children: [
                FutureBuilder<Map<DateTime, double>>(
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

                    return MonthlyHoursOverviewCard(
                      monthlyTotals: snapshot.data ?? const {},
                      primaryColor: _primaryColor,
                      title: _hoursSectionTitle,
                      showHeader: false,
                      emptyMessage: 'Sem horas registadas.',
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            AppSectionCard(
              title: "Consultas",
              titleIcon: Icons.event_note_outlined,
              titleColor: _primaryColor,
              children: [
                if (_consultas.isEmpty)
                  const Text(
                    "Nenhuma consulta registada.",
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Column(
                    children: _consultas.asMap().entries.map((entry) {
                      return ConsultaItemCard(
                        consulta: entry.value,
                        primaryColor: _primaryColor,
                        onEdit: () => _openConsultaSheet(
                          consulta: entry.value,
                          index: entry.key,
                        ),
                        onDelete: () => _confirmDeleteConsulta(entry.key),
                      );
                    }).toList(),
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

            AppSectionCard(
              title: "Férias",
              titleIcon: Icons.beach_access_outlined,
              titleColor: _primaryColor,
              titleTrailing: _feriasPeriodos.isEmpty
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _primaryColor.withValues(alpha: .2),
                        ),
                      ),
                      child: Text(
                        '${_feriasPeriodos.length}',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              children: [
                TeikerFeriasContent(
                  feriasPeriodos: _feriasPeriodos,
                  primaryColor: _primaryColor,
                  onAddFerias: _adicionarFerias,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultaSheet extends StatefulWidget {
  final Consulta? consulta;
  final Color primaryColor;

  const _ConsultaSheet({this.consulta, required this.primaryColor});

  @override
  State<_ConsultaSheet> createState() => _ConsultaSheetState();
}

class _ConsultaSheetState extends State<_ConsultaSheet> {
  late DateTime selectedDate;
  late TimeOfDay selectedHour;
  late TextEditingController descricaoCtrl;

  @override
  void initState() {
    super.initState();
    final baseDate = widget.consulta?.data ?? DateTime.now();
    selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    selectedHour = TimeOfDay.fromDateTime(baseDate);
    descricaoCtrl = TextEditingController(
      text: widget.consulta?.descricao ?? '',
    );
  }

  @override
  void dispose() {
    descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: selectedDate,
      title: 'Selecionar data',
      subtitle: 'Escolhe o dia',
      confirmLabel: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await SingleTimePickerBottomSheet.show(
      context,
      initialTime: selectedHour,
      title: 'Selecionar hora',
      subtitle: 'Escolhe a hora',
      confirmLabel: 'Confirmar',
    );
    if (picked != null) {
      setState(() => selectedHour = picked);
    }
  }

  void _save() {
    final descricao = descricaoCtrl.text.trim();
    if (descricao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona uma breve descricao.')),
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

    Navigator.pop(context, Consulta(data: date, descricao: descricao));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat("dd MMM yyyy", 'pt_PT').format(selectedDate);
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
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.consulta == null
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
            AppTextField(
              label: "Descricao",
              controller: descricaoCtrl,
              focusColor: widget.primaryColor,
              prefixIcon: Icons.note_alt_outlined,
              fillColor: Colors.grey.shade100,
              borderColor: widget.primaryColor,
              borderRadius: 14,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _consultaChip(
                    icon: Icons.calendar_today,
                    label: dateLabel,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _consultaChip(
                    icon: Icons.access_time,
                    label: timeLabel,
                    onTap: _pickTime,
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
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                onPressed: _save,
                label: Text(
                  widget.consulta == null ? "Guardar consulta" : "Guardar",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          border: Border.all(color: widget.primaryColor.withValues(alpha: .3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: widget.primaryColor),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
