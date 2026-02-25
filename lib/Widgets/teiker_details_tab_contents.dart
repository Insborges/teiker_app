import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/app_section_card.dart';
import 'package:teiker_app/Widgets/consulta_item_card.dart';
import 'package:teiker_app/Widgets/monthly_hours_overview_card.dart';
import 'package:teiker_app/Widgets/teiker_baixas_content.dart';
import 'package:teiker_app/Widgets/teiker_ferias_content.dart';
import 'package:teiker_app/Widgets/teiker_personal_info_content.dart';
import 'package:teiker_app/models/Teikers.dart';

class TeikerDetailsInfoTab extends StatelessWidget {
  const TeikerDetailsInfoTab({
    super.key,
    required this.teiker,
    required this.primaryColor,
    required this.hoursSectionTitle,
    required this.telemovelController,
    required this.phoneCountryIso,
    required this.onPhoneCountryChanged,
    required this.onSaveChanges,
    required this.hoursFuture,
  });

  final Teiker teiker;
  final Color primaryColor;
  final String hoursSectionTitle;
  final TextEditingController telemovelController;
  final String phoneCountryIso;
  final ValueChanged<String> onPhoneCountryChanged;
  final VoidCallback onSaveChanges;
  final Future<Map<DateTime, double>> hoursFuture;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Informações Pessoais',
            titleIcon: Icons.badge_outlined,
            titleColor: primaryColor,
            children: [
              TeikerPersonalInfoContent(
                birthDate: teiker.birthDate,
                telemovelController: telemovelController,
                phoneCountryIso: phoneCountryIso,
                onPhoneCountryChanged: onPhoneCountryChanged,
                primaryColor: primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 13),
          AppButton(
            text: 'Guardar Alterações',
            icon: Icons.save_rounded,
            color: primaryColor,
            onPressed: onSaveChanges,
          ),
          const SizedBox(height: 20),
          AppSectionCard(
            title: hoursSectionTitle,
            titleColor: primaryColor,
            titleIcon: Icons.bar_chart_rounded,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TeikerHoursInfoChip(
                      primaryColor: primaryColor,
                      icon: Icons.work_outline_rounded,
                      label: 'Regime',
                      value: teiker.workPercentageLabel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TeikerHoursInfoChip(
                      primaryColor: primaryColor,
                      icon: Icons.schedule_rounded,
                      label: 'Meta semanal',
                      value: '${teiker.weeklyTargetHours.toStringAsFixed(0)} h',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<Map<DateTime, double>>(
                future: hoursFuture,
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
                      'Não foi possível carregar as horas.',
                      style: TextStyle(color: Colors.redAccent),
                    );
                  }

                  return MonthlyHoursOverviewCard(
                    monthlyTotals: snapshot.data ?? const {},
                    primaryColor: primaryColor,
                    title: hoursSectionTitle,
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
    );
  }
}

class TeikerDetailsMarcacoesTab extends StatelessWidget {
  const TeikerDetailsMarcacoesTab({
    super.key,
    required this.primaryColor,
    required this.baixasPeriodos,
    required this.baixasDaysCount,
    required this.onAddBaixa,
    required this.onEditBaixa,
    required this.onDeleteBaixa,
    required this.consultas,
    required this.onEditConsulta,
    required this.onDeleteConsulta,
    required this.onAddConsulta,
    required this.feriasPeriodos,
    required this.feriasDaysCount,
    required this.onAddFerias,
    required this.onEditFerias,
    required this.onDeleteFerias,
  });

  final Color primaryColor;
  final List<BaixaPeriodo> baixasPeriodos;
  final int baixasDaysCount;
  final VoidCallback onAddBaixa;
  final Future<void> Function(int index, BaixaPeriodo periodo) onEditBaixa;
  final Future<void> Function(int index, BaixaPeriodo periodo) onDeleteBaixa;
  final List<Consulta> consultas;
  final Future<void> Function({Consulta? consulta, int? index}) onEditConsulta;
  final Future<void> Function(int index) onDeleteConsulta;
  final VoidCallback onAddConsulta;
  final List<FeriasPeriodo> feriasPeriodos;
  final int feriasDaysCount;
  final Future<void> Function() onAddFerias;
  final Future<void> Function(int index, FeriasPeriodo periodo) onEditFerias;
  final Future<void> Function(int index, FeriasPeriodo periodo) onDeleteFerias;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Baixas',
            titleIcon: Icons.healing_outlined,
            titleColor: primaryColor,
            titleTrailing: baixasPeriodos.isEmpty
                ? null
                : _TeikerDaysBadge(
                    primaryColor: primaryColor,
                    days: baixasDaysCount,
                  ),
            children: [
              TeikerBaixasContent(
                baixasPeriodos: baixasPeriodos,
                primaryColor: primaryColor,
                onAddBaixa: onAddBaixa,
                onEditBaixa: onEditBaixa,
                onDeleteBaixa: onDeleteBaixa,
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionCard(
            title: 'Consultas',
            titleIcon: Icons.event_note_outlined,
            titleColor: primaryColor,
            children: [
              if (consultas.isEmpty)
                const Text(
                  'Nenhuma consulta registada.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Column(
                  children: consultas.asMap().entries.map((entry) {
                    return ConsultaItemCard(
                      consulta: entry.value,
                      primaryColor: primaryColor,
                      onEdit: () => onEditConsulta(
                        consulta: entry.value,
                        index: entry.key,
                      ),
                      onDelete: () => onDeleteConsulta(entry.key),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Adicionar consulta',
                color: primaryColor,
                icon: Icons.medical_information,
                onPressed: onAddConsulta,
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionCard(
            title: 'Férias',
            titleIcon: Icons.beach_access_outlined,
            titleColor: primaryColor,
            titleTrailing: feriasPeriodos.isEmpty
                ? null
                : _TeikerDaysBadge(
                    primaryColor: primaryColor,
                    days: feriasDaysCount,
                  ),
            children: [
              TeikerFeriasContent(
                feriasPeriodos: feriasPeriodos,
                primaryColor: primaryColor,
                onAddFerias: onAddFerias,
                onEditFerias: onEditFerias,
                onDeleteFerias: onDeleteFerias,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TeikerHoursInfoChip extends StatelessWidget {
  const _TeikerHoursInfoChip({
    required this.primaryColor,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color primaryColor;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor.withValues(alpha: 0.85),
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
}

class _TeikerDaysBadge extends StatelessWidget {
  const _TeikerDaysBadge({required this.primaryColor, required this.days});

  final Color primaryColor;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: .2)),
      ),
      child: Text(
        '$days dias',
        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
