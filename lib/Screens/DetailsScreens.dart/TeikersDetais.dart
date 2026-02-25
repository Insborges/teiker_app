import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/DatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/app_section_card.dart';
import 'package:teiker_app/Widgets/consulta_item_card.dart';
import 'package:teiker_app/Widgets/monthly_hours_overview_card.dart';
import 'package:teiker_app/Widgets/teiker_baixas_content.dart';
import 'package:teiker_app/Widgets/teiker_details_sheets.dart';
import 'package:teiker_app/Widgets/teiker_ferias_content.dart';
import 'package:teiker_app/Widgets/teiker_personal_info_content.dart';
import 'package:teiker_app/theme/app_colors.dart';
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
  final Color _primaryColor = AppColors.primaryGreen;
  static const String _hoursSectionTitle = 'Horas da Teiker';
  final MonthlyHoursOverviewService _hoursOverviewService =
      MonthlyHoursOverviewService();
  late TextEditingController _telemovelController;
  late List<FeriasPeriodo> _feriasPeriodos;
  late List<BaixaPeriodo> _baixasPeriodos;
  late String _phoneCountryIso;
  late Future<Map<DateTime, double>> _hoursFuture;
  late List<Consulta> _consultas;

  @override
  void initState() {
    super.initState();
    _telemovelController = TextEditingController(
      text: widget.teiker.telemovel.toString(),
    );
    _phoneCountryIso = widget.teiker.phoneCountryIso;

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
    _baixasPeriodos = List<BaixaPeriodo>.from(widget.teiker.baixasPeriodos);
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
      AppSnackBar.show(
        context,
        message: "Preencha todos os campos corretamente.",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    try {
      final lastFerias = _feriasPeriodos.isEmpty ? null : _feriasPeriodos.last;
      final updatedTeiker = widget.teiker.copyWith(
        telemovel: newTelemovel,
        phoneCountryIso: _phoneCountryIso,
        consultas: _consultas,
        feriasPeriodos: _feriasPeriodos,
        baixasPeriodos: _baixasPeriodos,
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

    try {
      setState(() {
        _feriasPeriodos.add(FeriasPeriodo(inicio: inicio, fim: fim));
      });
      await TeikerService().addFeriasPeriodo(widget.teiker.uid, inicio, fim);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Período de férias adicionado!",
        icon: Icons.check,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao adicionar férias: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _saveFeriasPeriodos() async {
    await TeikerService().saveFeriasPeriodos(
      widget.teiker.uid,
      _feriasPeriodos,
    );
  }

  Future<void> _editarFeriasPeriodo(int index, FeriasPeriodo periodo) async {
    final selectedDates = await DatePickerBottomSheet.show(
      context,
      initialStart: periodo.inicio,
      initialEnd: periodo.fim,
    );

    if (selectedDates == null || selectedDates.length != 2) return;
    final inicio = selectedDates[0];
    final fim = selectedDates[1];
    if (inicio == null || fim == null) return;

    try {
      setState(() {
        _feriasPeriodos[index] = FeriasPeriodo(inicio: inicio, fim: fim);
      });
      await _saveFeriasPeriodos();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Período de férias atualizado!",
        icon: Icons.edit_outlined,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao editar férias: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _eliminarFeriasPeriodo(int index, FeriasPeriodo periodo) async {
    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar período de férias',
      message:
          'Queres eliminar o período ${DateFormat('dd/MM', 'pt_PT').format(periodo.inicio)} - ${DateFormat('dd/MM', 'pt_PT').format(periodo.fim)}?',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );

    if (!shouldDelete) return;

    try {
      setState(() {
        _feriasPeriodos.removeAt(index);
      });
      await _saveFeriasPeriodos();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Período de férias eliminado.",
        icon: Icons.delete_outline,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao eliminar férias: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _adicionarBaixa() async {
    final lastBaixa = _baixasPeriodos.isEmpty ? null : _baixasPeriodos.last;
    final selectedDates = await DatePickerBottomSheet.show(
      context,
      initialStart: lastBaixa?.inicio,
      initialEnd: lastBaixa?.fim,
    );

    if (selectedDates == null || selectedDates.length != 2) return;
    final inicio = selectedDates[0];
    final fim = selectedDates[1];
    if (inicio == null || fim == null) return;

    final motivo = await _pickBaixaReason();
    if (motivo == null || motivo.trim().isEmpty) return;

    final novoPeriodo = BaixaPeriodo(
      inicio: inicio,
      fim: fim,
      motivo: motivo.trim(),
    );

    try {
      setState(() {
        _baixasPeriodos.add(novoPeriodo);
      });
      await TeikerService().addBaixaPeriodo(
        widget.teiker.uid,
        inicio,
        fim,
        motivo.trim(),
      );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Baixa registada com sucesso!",
        icon: Icons.healing_outlined,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao registar baixa: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _saveBaixasPeriodos() async {
    await TeikerService().saveBaixasPeriodos(
      widget.teiker.uid,
      _baixasPeriodos,
    );
  }

  Future<void> _editarBaixaPeriodo(int index, BaixaPeriodo periodo) async {
    final selectedDates = await DatePickerBottomSheet.show(
      context,
      initialStart: periodo.inicio,
      initialEnd: periodo.fim,
    );

    if (selectedDates == null || selectedDates.length != 2) return;
    final inicio = selectedDates[0];
    final fim = selectedDates[1];
    if (inicio == null || fim == null) return;

    final motivo = await _pickBaixaReason(initialReason: periodo.motivo);
    if (motivo == null || motivo.trim().isEmpty) return;

    try {
      setState(() {
        _baixasPeriodos[index] = BaixaPeriodo(
          inicio: inicio,
          fim: fim,
          motivo: motivo.trim(),
        );
      });
      await _saveBaixasPeriodos();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Período de baixa atualizado!",
        icon: Icons.edit_outlined,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao editar baixa: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _eliminarBaixaPeriodo(int index, BaixaPeriodo periodo) async {
    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar período de baixa',
      message:
          'Queres eliminar o período ${DateFormat('dd/MM', 'pt_PT').format(periodo.inicio)} - ${DateFormat('dd/MM', 'pt_PT').format(periodo.fim)}?',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );

    if (!shouldDelete) return;

    try {
      setState(() {
        _baixasPeriodos.removeAt(index);
      });
      await _saveBaixasPeriodos();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Período de baixa eliminado.",
        icon: Icons.delete_outline,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao eliminar baixa: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<String?> _pickBaixaReason({String initialReason = ''}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BaixaReasonSheet(
        primaryColor: _primaryColor,
        initialReason: initialReason,
      ),
    );
  }

  int _countFeriasDays(List<FeriasPeriodo> periodos) {
    final dayKeys = <DateTime>{};
    for (final periodo in periodos) {
      final start = DateTime(
        periodo.inicio.year,
        periodo.inicio.month,
        periodo.inicio.day,
      );
      final end = DateTime(
        periodo.fim.year,
        periodo.fim.month,
        periodo.fim.day,
      );
      var cursor = start;
      while (!cursor.isAfter(end)) {
        dayKeys.add(DateTime(cursor.year, cursor.month, cursor.day));
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return dayKeys.length;
  }

  int _countBaixasDays(List<BaixaPeriodo> periodos) {
    final dayKeys = <DateTime>{};
    for (final periodo in periodos) {
      final start = DateTime(
        periodo.inicio.year,
        periodo.inicio.month,
        periodo.inicio.day,
      );
      final end = DateTime(
        periodo.fim.year,
        periodo.fim.month,
        periodo.fim.day,
      );
      var cursor = start;
      while (!cursor.isAfter(end)) {
        dayKeys.add(DateTime(cursor.year, cursor.month, cursor.day));
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return dayKeys.length;
  }

  Future<void> _openConsultaSheet({Consulta? consulta, int? index}) async {
    final result = await showModalBottomSheet<Consulta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ConsultaSheet(consulta: consulta, primaryColor: _primaryColor);
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
    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar consulta',
      message:
          'Queres eliminar a consulta de ${DateFormat('dd/MM', 'pt_PT').format(consulta.data)}?',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );

    if (!shouldDelete) return;

    setState(() => _consultas.removeAt(index));
    await _saveConsultas(successMessage: "Consulta eliminada.");
  }

  Widget _hoursInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _primaryColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teiker = widget.teiker;

    return Scaffold(
      appBar: buildAppBar(teiker.nameTeiker, seta: true),
      body: DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _primaryColor.withValues(alpha: .2),
                  ),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: _primaryColor.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: _primaryColor,
                  unselectedLabelColor: Colors.black54,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Informações'),
                    Tab(text: 'Marcações'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionCard(
                            title: "Informações Pessoais",
                            titleIcon: Icons.badge_outlined,
                            titleColor: _primaryColor,
                            children: [
                              TeikerPersonalInfoContent(
                                birthDate: teiker.birthDate,
                                telemovelController: _telemovelController,
                                phoneCountryIso: _phoneCountryIso,
                                onPhoneCountryChanged: (iso) {
                                  setState(() => _phoneCountryIso = iso);
                                },
                                primaryColor: _primaryColor,
                              ),
                            ],
                          ),

                          const SizedBox(height: 13),
                          AppButton(
                            text: "Guardar Alterações",
                            icon: Icons.save_rounded,
                            color: _primaryColor,
                            onPressed: _guardarAlteracoes,
                          ),
                          const SizedBox(height: 20),
                          AppSectionCard(
                            title: _hoursSectionTitle,
                            titleColor: _primaryColor,
                            titleIcon: Icons.bar_chart_rounded,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _hoursInfoChip(
                                      icon: Icons.work_outline_rounded,
                                      label: 'Regime',
                                      value: teiker.workPercentageLabel,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _hoursInfoChip(
                                      icon: Icons.schedule_rounded,
                                      label: 'Meta semanal',
                                      value:
                                          '${teiker.weeklyTargetHours.toStringAsFixed(0)} h',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FutureBuilder<Map<DateTime, double>>(
                                future: _hoursFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
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
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionCard(
                            title: "Baixas",
                            titleIcon: Icons.healing_outlined,
                            titleColor: _primaryColor,
                            titleTrailing: _baixasPeriodos.isEmpty
                                ? null
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withValues(
                                        alpha: .08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _primaryColor.withValues(
                                          alpha: .2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '${_countBaixasDays(_baixasPeriodos)} dias',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                            children: [
                              TeikerBaixasContent(
                                baixasPeriodos: _baixasPeriodos,
                                primaryColor: _primaryColor,
                                onAddBaixa: _adicionarBaixa,
                                onEditBaixa: _editarBaixaPeriodo,
                                onDeleteBaixa: _eliminarBaixaPeriodo,
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
                                  children: _consultas.asMap().entries.map((
                                    entry,
                                  ) {
                                    return ConsultaItemCard(
                                      consulta: entry.value,
                                      primaryColor: _primaryColor,
                                      onEdit: () => _openConsultaSheet(
                                        consulta: entry.value,
                                        index: entry.key,
                                      ),
                                      onDelete: () =>
                                          _confirmDeleteConsulta(entry.key),
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
                                      color: _primaryColor.withValues(
                                        alpha: .08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _primaryColor.withValues(
                                          alpha: .2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '${_countFeriasDays(_feriasPeriodos)} dias',
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
                                onEditFerias: _editarFeriasPeriodo,
                                onDeleteFerias: _eliminarFeriasPeriodo,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
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
}
