import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/app_section_card.dart';
import 'package:teiker_app/Widgets/consulta_item_card.dart';
import 'package:teiker_app/Widgets/monthly_hours_overview_card.dart';
import 'package:teiker_app/Widgets/teiker_baixas_content.dart';
import 'package:teiker_app/Widgets/teiker_ferias_content.dart';
import 'package:teiker_app/Widgets/teiker_personal_info_content.dart';
import 'package:teiker_app/models/Teikers.dart';
import 'package:teiker_app/models/teiker_document.dart';
import 'package:teiker_app/models/teiker_manual_hours_entry.dart';

class TeikerDetailsInfoTab extends StatelessWidget {
  const TeikerDetailsInfoTab({
    super.key,
    required this.teiker,
    required this.birthDate,
    required this.primaryColor,
    required this.hoursSectionTitle,
    required this.emailController,
    required this.telemovelController,
    required this.canEditPersonalInfo,
    required this.showHoursSection,
    required this.canAddManualHours,
    required this.canEditManualHours,
    required this.phoneCountryIso,
    required this.onPhoneCountryChanged,
    required this.onEditBirthDate,
    required this.onSaveChanges,
    required this.hoursFuture,
    required this.onAddManualHours,
    required this.onEditManualHours,
    required this.manualHoursEntriesStream,
    this.highlightedManualHoursEntryId,
    required this.showDocumentsCard,
    required this.canManageDocuments,
    required this.uploadingDocument,
    required this.documentsStream,
    required this.deletingDocumentIds,
    required this.onAddDocument,
    required this.onOpenDocument,
    required this.onDeleteDocument,
  });

  final Teiker teiker;
  final DateTime? birthDate;
  final Color primaryColor;
  final String hoursSectionTitle;
  final TextEditingController emailController;
  final TextEditingController telemovelController;
  final bool canEditPersonalInfo;
  final bool showHoursSection;
  final bool canAddManualHours;
  final bool canEditManualHours;
  final String phoneCountryIso;
  final ValueChanged<String> onPhoneCountryChanged;
  final Future<void> Function() onEditBirthDate;
  final VoidCallback onSaveChanges;
  final Future<Map<DateTime, double>> hoursFuture;
  final Future<void> Function() onAddManualHours;
  final Future<void> Function() onEditManualHours;
  final Stream<List<TeikerManualHoursEntry>> manualHoursEntriesStream;
  final String? highlightedManualHoursEntryId;
  final bool showDocumentsCard;
  final bool canManageDocuments;
  final bool uploadingDocument;
  final Stream<List<TeikerDocument>> documentsStream;
  final Set<String> deletingDocumentIds;
  final Future<void> Function() onAddDocument;
  final Future<void> Function(TeikerDocument document) onOpenDocument;
  final Future<void> Function(TeikerDocument document) onDeleteDocument;

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
                birthDate: birthDate,
                emailController: emailController,
                telemovelController: telemovelController,
                readOnly: !canEditPersonalInfo,
                phoneCountryIso: phoneCountryIso,
                onPhoneCountryChanged: onPhoneCountryChanged,
                onEditBirthDate: onEditBirthDate,
                primaryColor: primaryColor,
              ),
            ],
          ),
          if (canEditPersonalInfo) ...[
            const SizedBox(height: 13),
            AppButton(
              text: 'Guardar Alterações',
              icon: Icons.save_rounded,
              color: primaryColor,
              onPressed: onSaveChanges,
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 12),
          if (showHoursSection)
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
                        value:
                            '${teiker.weeklyTargetHours.toStringAsFixed(0)} h',
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
                      monthlyTotals: teiker.monthlyTotalsWithAdjustments(
                        snapshot.data ?? const {},
                      ),
                      primaryColor: primaryColor,
                      workPercentage: teiker.workPercentage,
                      balanceAdjustmentHours: teiker.hoursBalanceAdjustment,
                      title: hoursSectionTitle,
                      showHeader: false,
                      emptyMessage: 'Sem horas registadas.',
                    );
                  },
                ),
                if (canAddManualHours || canEditManualHours) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (canAddManualHours)
                        Expanded(
                          child: AppButton(
                            text: 'Adicionar Horas',
                            icon: Icons.add_alarm_rounded,
                            color: primaryColor,
                            onPressed: () => onAddManualHours(),
                          ),
                        ),
                      if (canAddManualHours && canEditManualHours)
                        const SizedBox(width: 10),
                      if (canEditManualHours)
                        Expanded(
                          child: AppButton(
                            text: 'Alterar Horas',
                            icon: Icons.edit_calendar_rounded,
                            color: primaryColor,
                            outline: true,
                            onPressed: () => onEditManualHours(),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          if (showHoursSection) const SizedBox(height: 12),
          AppSectionCard(
            title: 'Horas Acrescentadas',
            titleColor: primaryColor,
            titleIcon: Icons.history_toggle_off_rounded,
            children: [
              StreamBuilder<List<TeikerManualHoursEntry>>(
                stream: manualHoursEntriesStream,
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

                  final entries =
                      snapshot.data ?? const <TeikerManualHoursEntry>[];
                  if (entries.isEmpty) {
                    return Text(
                      'Ainda não há horas acrescentadas por esta via.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final entry in entries) ...[
                        _ManualHoursEntryCard(
                          entry: entry,
                          primaryColor: primaryColor,
                          highlighted:
                              highlightedManualHoursEntryId != null &&
                              highlightedManualHoursEntryId == entry.id,
                        ),
                        if (entry != entries.last) const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
          if (showHoursSection) const SizedBox(height: 12),
          if (showDocumentsCard) ...[
            _TeikerDocumentsCard(
              primaryColor: primaryColor,
              documentsStream: documentsStream,
              canManageDocuments: canManageDocuments,
              uploadingDocument: uploadingDocument,
              deletingDocumentIds: deletingDocumentIds,
              onAddDocument: onAddDocument,
              onOpenDocument: onOpenDocument,
              onDeleteDocument: onDeleteDocument,
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ManualHoursEntryCard extends StatefulWidget {
  const _ManualHoursEntryCard({
    required this.entry,
    required this.primaryColor,
    required this.highlighted,
  });

  final TeikerManualHoursEntry entry;
  final Color primaryColor;
  final bool highlighted;

  @override
  State<_ManualHoursEntryCard> createState() => _ManualHoursEntryCardState();
}

class _ManualHoursEntryCardState extends State<_ManualHoursEntryCard> {
  @override
  void initState() {
    super.initState();
    _ensureVisibleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ManualHoursEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.highlighted && widget.highlighted) {
      _ensureVisibleIfNeeded();
    }
  }

  void _ensureVisibleIfNeeded() {
    if (!widget.highlighted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final primaryColor = widget.primaryColor;
    final highlighted = widget.highlighted;
    final workDate = DateFormat('dd/MM/yyyy', 'pt_PT').format(entry.workDate);
    final start = DateFormat('HH:mm', 'pt_PT').format(entry.startTime);
    final end = DateFormat('HH:mm', 'pt_PT').format(entry.endTime);
    final createdAt = DateFormat(
      'dd/MM/yyyy HH:mm',
      'pt_PT',
    ).format(entry.createdAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? primaryColor.withValues(alpha: 0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? primaryColor.withValues(alpha: 0.40)
              : Colors.grey.shade200,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.clienteName.isEmpty ? 'Cliente' : entry.clienteName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${entry.durationHours.toStringAsFixed(1)} h',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Dia trabalhado: $workDate',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Horas lançadas: $start - $end',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Acrescentado em: $createdAt',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeikerDocumentsCard extends StatelessWidget {
  const _TeikerDocumentsCard({
    required this.primaryColor,
    required this.documentsStream,
    required this.canManageDocuments,
    required this.uploadingDocument,
    required this.deletingDocumentIds,
    required this.onAddDocument,
    required this.onOpenDocument,
    required this.onDeleteDocument,
  });

  final Color primaryColor;
  final Stream<List<TeikerDocument>> documentsStream;
  final bool canManageDocuments;
  final bool uploadingDocument;
  final Set<String> deletingDocumentIds;
  final Future<void> Function() onAddDocument;
  final Future<void> Function(TeikerDocument document) onOpenDocument;
  final Future<void> Function(TeikerDocument document) onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_PT');

    return AppSectionCard(
      title: 'Documentos da Teiker',
      titleColor: primaryColor,
      titleIcon: Icons.folder_shared_outlined,
      children: [
        if (canManageDocuments) ...[
          AppButton(
            text: uploadingDocument
                ? 'A enviar ficheiro...'
                : 'Adicionar Ficheiro',
            icon: Icons.upload_file_rounded,
            color: primaryColor,
            enabled: !uploadingDocument,
            onPressed: () => onAddDocument(),
          ),
          const SizedBox(height: 10),
        ],
        StreamBuilder<List<TeikerDocument>>(
          stream: documentsStream,
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
                'Não foi possível carregar os documentos.',
                style: TextStyle(color: Colors.redAccent),
              );
            }

            final documents = snapshot.data ?? const <TeikerDocument>[];
            if (documents.isEmpty) {
              return const Text(
                'Sem documentos associados a esta teiker.',
                style: TextStyle(color: Colors.grey),
              );
            }

            return Column(
              children: documents.map((document) {
                final isDeleting = deletingDocumentIds.contains(document.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: .18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                document.fileName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateFormat.format(document.uploadedAt)} • ${_formatFileSize(document.sizeBytes)}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Abrir / Transferir',
                          icon: Icon(
                            Icons.download_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                          onPressed: () => onOpenDocument(document),
                        ),
                        if (canManageDocuments)
                          isDeleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Remover ficheiro',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () => onDeleteDocument(document),
                                ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _formatFileSize(int sizeBytes) {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }
}

class TeikerDetailsMarcacoesTab extends StatelessWidget {
  const TeikerDetailsMarcacoesTab({
    super.key,
    required this.primaryColor,
    required this.marcacoes,
    required this.onAddMarcacao,
    required this.onOpenMarcacaoNotes,
    required this.onEditMarcacao,
    required this.onDeleteMarcacao,
    this.showBaixas = true,
    this.showConsultas = true,
    this.showFerias = true,
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
  final List<TeikerMarcacao> marcacoes;
  final VoidCallback onAddMarcacao;
  final Future<void> Function(int index) onOpenMarcacaoNotes;
  final Future<void> Function({TeikerMarcacao? marcacao, int? index})
  onEditMarcacao;
  final Future<void> Function(int index) onDeleteMarcacao;
  final bool showBaixas;
  final bool showConsultas;
  final bool showFerias;
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
    final sortedMarcacoes = List<TeikerMarcacao>.from(marcacoes)
      ..sort((a, b) => a.data.compareTo(b.data));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Reuniões / Acompanhamentos',
            titleIcon: Icons.groups_2_outlined,
            titleColor: primaryColor,
            children: [
              if (marcacoes.isEmpty)
                const Text(
                  'Nenhuma marcação registada.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Column(
                  children: sortedMarcacoes
                      .map(
                        (marcacao) => _TeikerMarcacaoListTile(
                          marcacao: marcacao,
                          primaryColor: primaryColor,
                          onTap: () => onOpenMarcacaoNotes(
                            sortedMarcacoes.indexOf(marcacao),
                          ),
                          onEdit: () => onEditMarcacao(
                            marcacao: marcacao,
                            index: sortedMarcacoes.indexOf(marcacao),
                          ),
                          onDelete: () => onDeleteMarcacao(
                            sortedMarcacoes.indexOf(marcacao),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Adicionar marcação',
                color: primaryColor,
                icon: Icons.add_task_rounded,
                onPressed: onAddMarcacao,
              ),
            ],
          ),
          if (showBaixas) ...[
            const SizedBox(height: 20),
            AppSectionCard(
              title: 'Baixas',
              titleIcon: Icons.healing_outlined,
              titleColor: primaryColor,
              titleTrailing: baixasPeriodos.isEmpty
                  ? null
                  : _TeikerDaysBadge(
                      primaryColor: primaryColor,
                      days: baixasDaysCount,
                      label: baixasDaysCount == 1 ? 'dia' : 'dias',
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
          ],
          if (showConsultas) ...[
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
          ],
          if (showFerias) ...[
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
                      label: feriasDaysCount == 1 ? 'dia útil' : 'dias úteis',
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
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TeikerMarcacaoListTile extends StatelessWidget {
  const _TeikerMarcacaoListTile({
    required this.marcacao,
    required this.primaryColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final TeikerMarcacao marcacao;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dia = DateFormat('dd MMM yyyy', 'pt_PT').format(marcacao.data);
    final hora = DateFormat('HH:mm', 'pt_PT').format(marcacao.data);
    final isReuniao = marcacao.tipo == TeikerMarcacaoTipo.reuniaoTrabalho;
    final nota = marcacao.nota.trim();

    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: .1),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withValues(alpha: .18)),
            ),
            child: Icon(
              isReuniao
                  ? Icons.groups_2_outlined
                  : Icons.support_agent_outlined,
              color: primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      '$dia · $hora',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _typePill(marcacao.tipo.label),
                  ],
                ),
                if (nota.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: .035),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: .10),
                      ),
                    ),
                    child: Text(
                      nota,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: primaryColor.withValues(alpha: .45),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _typePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primaryColor.withValues(alpha: .2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
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
  const _TeikerDaysBadge({
    required this.primaryColor,
    required this.days,
    this.label = 'dias',
  });

  final Color primaryColor;
  final int days;
  final String label;

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
        '$days $label',
        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
