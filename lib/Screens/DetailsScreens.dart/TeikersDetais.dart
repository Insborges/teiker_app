import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/DatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/SingleTimePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/Widgets/app_pill_tab_bar.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/teiker_marcacao_notes_dialog.dart';
import 'package:teiker_app/Widgets/teiker_details_sheets.dart';
import 'package:teiker_app/Widgets/teiker_details_tab_contents.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/utils/ferias_day_count.dart';
import 'package:teiker_app/work_sessions/application/monthly_hours_overview_service.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/teiker_document_service.dart';
import 'package:teiker_app/backend/teiker_marcacao_calendar_sync_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/models/teiker_document.dart';
import 'package:teiker_app/models/teiker_manual_hours_entry.dart';
import '../../models/Clientes.dart';
import '../../models/Teikers.dart';
import '../../Widgets/AppBar.dart';
import '../../Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/TeikerService.dart';

class TeikersDetails extends StatefulWidget {
  final Teiker teiker;
  final bool canEditPersonalInfo;
  final bool isAdminSelfProfile;
  final AppUserRole? specialProfileRole;
  final String? initialManualHoursEntryId;
  const TeikersDetails({
    super.key,
    required this.teiker,
    this.canEditPersonalInfo = true,
    this.isAdminSelfProfile = false,
    this.specialProfileRole,
    this.initialManualHoursEntryId,
  });

  @override
  State<TeikersDetails> createState() => _TeikersDetailsState();
}

class _TeikersDetailsState extends State<TeikersDetails> {
  final Color _primaryColor = AppColors.primaryGreen;
  static const String _hoursSectionTitle = 'Horas da Teiker';
  final MonthlyHoursOverviewService _hoursOverviewService =
      MonthlyHoursOverviewService();
  final AuthService _authService = AuthService();
  final TeikerMarcacaoCalendarSyncService _marcacaoCalendarSyncService =
      TeikerMarcacaoCalendarSyncService();
  final TeikerDocumentService _teikerDocumentService = TeikerDocumentService();
  final WorkSessionService _workSessionService = WorkSessionService();
  late TextEditingController _emailController;
  late TextEditingController _telemovelController;
  late DateTime? _birthDate;
  late List<FeriasPeriodo> _feriasPeriodos;
  late List<BaixaPeriodo> _baixasPeriodos;
  late String _phoneCountryIso;
  late Future<Map<DateTime, double>> _hoursFuture;
  late List<Consulta> _consultas;
  late List<TeikerMarcacao> _marcacoes;
  late String _savedEmail;
  bool _uploadingDocument = false;
  final Set<String> _deletingDocumentIds = <String>{};
  final Set<String> _openingDocumentIds = <String>{};

  bool get _canManageTeikerDocuments => _authService.currentUserRole.isAdmin;

  bool get _canAddTeikerHoursByAdmin => _authService.currentUserRole.isAdmin;

  bool get _isOwnTeikerProfile {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (currentUid == null || currentUid.isEmpty) return false;
    return currentUid == widget.teiker.uid.trim();
  }

  bool get _canAddTeikerHoursBySelf =>
      _authService.currentUserRole.isTeiker && _isOwnTeikerProfile;

  bool get _canAddManualHours =>
      _canAddTeikerHoursByAdmin || _canAddTeikerHoursBySelf;

  bool get _canEditManualHours => _canAddTeikerHoursByAdmin;

  bool get _showTeikerDocumentsCard => _authService.currentUserRole.isAdmin;

  @override
  void initState() {
    super.initState();
    _savedEmail = widget.teiker.email.trim().toLowerCase();
    _emailController = TextEditingController(text: widget.teiker.email);
    _telemovelController = TextEditingController(
      text: widget.teiker.telemovel > 0
          ? widget.teiker.telemovel.toString()
          : '',
    );
    _birthDate = widget.teiker.birthDate;
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
    _marcacoes = List<TeikerMarcacao>.from(widget.teiker.marcacoes)
      ..sort((a, b) => a.data.compareTo(b.data));
    _hoursFuture = _hoursOverviewService.fetchMonthlyTotals(
      teikerId: widget.teiker.uid,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telemovelController.dispose();
    super.dispose();
  }

  void _guardarAlteracoes() async {
    if (!widget.canEditPersonalInfo) {
      AppSnackBar.show(
        context,
        message: "A Recursos Humanos não altera os dados pessoais da teiker.",
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final normalizedEmail = _emailController.text.trim().toLowerCase();
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
    if (normalizedEmail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      AppSnackBar.show(
        context,
        message: "Email inválido.",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    try {
      final lastFerias = _feriasPeriodos.isEmpty ? null : _feriasPeriodos.last;
      final updatedTeiker = widget.teiker.copyWith(
        email: normalizedEmail,
        telemovel: newTelemovel,
        birthDate: _birthDate,
        phoneCountryIso: _phoneCountryIso,
        consultas: _consultas,
        marcacoes: _marcacoes,
        feriasPeriodos: _feriasPeriodos,
        baixasPeriodos: _baixasPeriodos,
        feriasInicio: lastFerias?.inicio,
        feriasFim: lastFerias?.fim,
      );

      final result = await _authService.updateTeikerProfileByAdmin(
        teiker: updatedTeiker,
        previousEmail: _savedEmail,
      );
      _savedEmail = normalizedEmail;

      AppSnackBar.show(
        context,
        message:
            result.warningMessage ?? "Atualizações realizadas com sucesso!",
        icon: result.warningMessage == null
            ? Icons.check_box_rounded
            : Icons.info_outline_rounded,
        background: result.warningMessage == null
            ? Colors.green.shade700
            : Colors.orange.shade700,
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

  Future<void> _saveMarcacoesTeiker({
    String successMessage = 'Marcação guardada.',
    bool showSuccessSnack = true,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('teikers')
          .doc(widget.teiker.uid);
      if (widget.specialProfileRole != null) {
        await docRef.set(
          widget.teiker.copyWith(marcacoes: _marcacoes).toMap(),
          SetOptions(merge: true),
        );
      } else {
        await docRef.update({
          'marcacoes': _marcacoes.map((m) => m.toMap()).toList(),
        });
      }

      if (!mounted) return;
      if (showSuccessSnack) {
        AppSnackBar.show(
          context,
          message: successMessage,
          icon: Icons.event_available_rounded,
          background: Colors.green.shade700,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao guardar marcação: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _updateMarcacaoCalendarDocs(TeikerMarcacao marcacao) async {
    await _marcacaoCalendarSyncService.updateCalendarDocs(
      teikerId: widget.teiker.uid,
      teikerName: widget.teiker.nameTeiker,
      marcacao: marcacao,
    );
  }

  Future<void> _deleteMarcacaoCalendarDocs(TeikerMarcacao marcacao) async {
    await _marcacaoCalendarSyncService.deleteCalendarDocs(
      teikerId: widget.teiker.uid,
      marcacao: marcacao,
    );
  }

  ({String name, AppUserRole role}) _currentMarcacaoNoteWriter() {
    final user = FirebaseAuth.instance.currentUser;
    final role = AppUserRoleResolver.fromEmail(user?.email);

    if (role.isDeveloper) {
      return (name: AppUserRoleResolver.developerName, role: role);
    }

    final displayName = (user?.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return (name: displayName, role: role);
    }

    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return (name: localPart, role: role);
      }
    }

    if (role.isAdmin) return (name: 'Admin', role: role);
    if (role.isHr) return (name: 'Recursos Humanos', role: role);
    return (name: widget.teiker.nameTeiker, role: role);
  }

  Future<void> _saveMarcacaoNote({
    required int index,
    required String note,
  }) async {
    if (index < 0 || index >= _marcacoes.length) return;
    final current = _marcacoes[index];
    final updated = current.copyWith(nota: note.trim());
    await _updateMarcacaoCalendarDocs(updated);

    if (!mounted) return;
    setState(() {
      _marcacoes[index] = updated;
      _marcacoes.sort((a, b) => a.data.compareTo(b.data));
    });
    await _saveMarcacoesTeiker(
      successMessage: 'Anotação atualizada.',
      showSuccessSnack: false,
    );
  }

  Future<void> _openMarcacaoNotesDialog(int index) async {
    if (index < 0 || index >= _marcacoes.length) return;
    final marcacao = _marcacoes[index];
    final writer = _currentMarcacaoNoteWriter();
    final canManageMarcacao = writer.role.isPrivileged;

    await TeikerMarcacaoNotesDialog.show(
      context: context,
      primaryColor: _primaryColor,
      tipoMarcacao: marcacao.tipo.label,
      teikerName: widget.teiker.nameTeiker,
      dataHoraMarcacao: marcacao.data,
      initialNote: marcacao.nota,
      writerName: writer.name,
      writerRole: writer.role,
      onSaveNote: (note) => _saveMarcacaoNote(index: index, note: note),
      onEditMarcacao: canManageMarcacao
          ? () => _openMarcacaoSheet(marcacao: marcacao, index: index)
          : null,
      onDeleteMarcacao: canManageMarcacao
          ? () => _confirmDeleteMarcacao(index)
          : null,
    );
  }

  Future<void> _openMarcacaoSheet({
    TeikerMarcacao? marcacao,
    int? index,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final role = AppUserRoleResolver.fromEmail(currentUser?.email);
    if (!role.isPrivileged) {
      AppSnackBar.show(
        context,
        message: 'Só Admin/RH pode adicionar marcações.',
        icon: Icons.lock_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final result = await showModalBottomSheet<TeikerMarcacao>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TeikerMarcacaoSheet(primaryColor: _primaryColor, marcacao: marcacao),
    );

    if (result == null) return;
    final isEditing = marcacao != null && index != null;

    if (isEditing) {
      final updated = result.copyWith(
        id: marcacao.id,
        createdAt: marcacao.createdAt,
        createdById: marcacao.createdById,
        createdByName: marcacao.createdByName,
        reminderId: marcacao.reminderId,
        adminReminderId: marcacao.adminReminderId,
      );

      try {
        await _updateMarcacaoCalendarDocs(updated);
        setState(() {
          _marcacoes[index] = updated;
          _marcacoes.sort((a, b) => a.data.compareTo(b.data));
        });
        await _saveMarcacoesTeiker(successMessage: 'Marcação atualizada.');
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: "Erro ao atualizar marcação: $e",
          icon: Icons.error_outline,
          background: Colors.red.shade700,
        );
      }
      return;
    }

    final creatorName = role.isDeveloper
        ? AppUserRoleResolver.developerName
        : role.isAdmin
        ? 'Admin'
        : 'Recursos Humanos';
    final createdAt = DateTime.now();
    final firestore = FirebaseFirestore.instance;
    final reminderRef = firestore
        .collection('reminders')
        .doc(widget.teiker.uid)
        .collection('items')
        .doc();
    final adminRef = firestore.collection('admin_reminders').doc();

    final startLabel = DateFormat('HH:mm', 'pt_PT').format(result.data);
    final tag = result.tipo.label;
    final reminderPayload = <String, dynamic>{
      'title': tag,
      'description': result.nota,
      'nota': result.nota,
      'date': Timestamp.fromDate(result.data),
      'start': startLabel,
      'end': '',
      'done': false,
      'resolved': false,
      'tag': tag,
      'clienteId': null,
      'clienteName': null,
      'teikerId': widget.teiker.uid,
      'teikerName': widget.teiker.nameTeiker,
      'createdById': currentUser?.uid,
      'createdByName': creatorName,
      'createdByRole': role.name,
      'seenByUserIds': const <String>[],
      'responses': const <Map<String, dynamic>>[],
      'createdAt': Timestamp.fromDate(createdAt),
      'adminReminderId': adminRef.id,
    };

    final adminPayload = <String, dynamic>{
      ...reminderPayload,
      'sourceUserId': widget.teiker.uid,
      'sourceReminderId': reminderRef.id,
    };

    try {
      final batch = firestore.batch();
      batch.set(reminderRef, reminderPayload);
      batch.set(adminRef, adminPayload);
      await batch.commit();

      final saved = result.copyWith(
        id: reminderRef.id,
        createdAt: createdAt,
        createdById: currentUser?.uid,
        createdByName: creatorName,
        reminderId: reminderRef.id,
        adminReminderId: adminRef.id,
      );

      setState(() {
        _marcacoes.add(saved);
        _marcacoes.sort((a, b) => a.data.compareTo(b.data));
      });

      await _saveMarcacoesTeiker(successMessage: 'Marcação adicionada.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao adicionar marcação: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _confirmDeleteMarcacao(int index) async {
    if (index < 0 || index >= _marcacoes.length) return;
    final marcacao = _marcacoes[index];
    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar marcação',
      message:
          'Queres eliminar a marcação de ${DateFormat('dd/MM', 'pt_PT').format(marcacao.data)} às ${DateFormat('HH:mm', 'pt_PT').format(marcacao.data)}?',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );

    if (!shouldDelete) return;

    try {
      await _deleteMarcacaoCalendarDocs(marcacao);
      setState(() {
        _marcacoes.removeAt(index);
      });
      await _saveMarcacoesTeiker(successMessage: 'Marcação eliminada.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro ao eliminar marcação: $e",
        icon: Icons.error_outline,
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
    return countFeriasBusinessDays(periodos);
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

  Future<void> _pickBirthDate() async {
    if (!widget.canEditPersonalInfo) return;

    final picked = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: _birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      title: 'Data de nascimento',
      subtitle: 'Escolhe a nova data de nascimento',
      confirmLabel: 'Usar data',
    );
    if (picked == null) return;

    setState(() {
      _birthDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<List<Clientes>> _loadManualHoursClientes({
    bool includeArchived = false,
  }) async {
    final clientes = await _authService.getClientes(
      includeArchived: includeArchived,
    );
    final teikerId = widget.teiker.uid.trim();
    final linkedClientIds = widget.teiker.clientesIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final linked = clientes.where((cliente) {
      final clienteId = cliente.uid.trim();
      return linkedClientIds.contains(clienteId) ||
          cliente.teikersIds.map((id) => id.trim()).contains(teikerId);
    }).toList();

    final available = linked.isNotEmpty ? linked : clientes;
    available.sort(
      (a, b) =>
          a.nameCliente.toLowerCase().compareTo(b.nameCliente.toLowerCase()),
    );
    return available;
  }

  Stream<List<TeikerManualHoursEntry>> _watchManualHoursEntries() {
    final cutoff = DateTime(2026, 4, 1);
    return FirebaseFirestore.instance
        .collection('teikers')
        .doc(widget.teiker.uid)
        .collection('manual_hours_entries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .map((doc) => TeikerManualHoursEntry.fromMap(doc.data(), doc.id))
              .where((entry) => !entry.workDate.isBefore(cutoff))
              .toList();
          entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return entries;
        });
  }

  Future<void> _openAddManualHoursSheet() async {
    if (!_canAddManualHours) {
      AppSnackBar.show(
        context,
        message: 'Não tens permissão para adicionar horas nesta teiker.',
        icon: Icons.lock_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    List<Clientes> clientes;
    try {
      clientes = await _loadManualHoursClientes();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Não foi possível carregar os clientes: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    if (!mounted) return;
    if (clientes.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Não há clientes disponíveis para associar estas horas.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final result = await showModalBottomSheet<_AdminManualHoursInput>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminManualHoursSheet(
        primaryColor: _primaryColor,
        teikerName: widget.teiker.nameTeiker,
        clientes: clientes,
      ),
    );
    if (result == null) return;

    try {
      if (_canAddTeikerHoursByAdmin) {
        await _workSessionService.addManualSessionForTeikerByAdmin(
          clienteId: result.cliente.uid,
          teikerId: widget.teiker.uid,
          start: result.start,
          end: result.end,
        );
      } else {
        await _workSessionService.addManualSessionForCurrentTeikerProfile(
          clienteId: result.cliente.uid,
          clienteName: result.cliente.nameCliente,
          start: result.start,
          end: result.end,
        );
      }

      if (!mounted) return;
      setState(() {
        _hoursFuture = _hoursOverviewService.fetchMonthlyTotals(
          teikerId: widget.teiker.uid,
        );
      });
      final dateLabel = DateFormat('dd/MM/yyyy', 'pt_PT').format(result.start);
      AppSnackBar.show(
        context,
        message: _canAddTeikerHoursByAdmin
            ? 'Horas de $dateLabel registadas para esta teiker.'
            : 'Horas de $dateLabel registadas e enviadas para a admin.',
        icon: Icons.save_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro a guardar horas: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Clientes _placeholderCliente(String clienteId) {
    return Clientes(
      uid: clienteId,
      nameCliente: clienteId.isEmpty ? 'Cliente' : clienteId,
      moradaCliente: '',
      cidadeCliente: '',
      codigoPostal: '',
      hourasCasa: 0,
      telemovel: 0,
      email: '',
      orcamento: 0,
      teikersIds: const [],
    );
  }

  double _durationForSessionData(Map<String, dynamic> data) {
    final stored = (data['durationHours'] as num?)?.toDouble();
    if (stored != null) return stored;

    final raw = (data['rawDurationHours'] as num?)?.toDouble();
    if (raw != null) {
      final multiplier = (data['durationMultiplier'] as num?)?.toDouble();
      return multiplier != null && multiplier > 0 ? raw * multiplier : raw;
    }

    final start = (data['startTime'] as Timestamp?)?.toDate();
    final end = (data['endTime'] as Timestamp?)?.toDate();
    if (start == null || end == null || !end.isAfter(start)) return 0;
    return end.difference(start).inMinutes / 60.0;
  }

  Future<List<_EditableWorkSession>> _loadEditableHourSessions(
    List<Clientes> clientes,
  ) async {
    final clientsById = {for (final cliente in clientes) cliente.uid: cliente};
    final snapshot = await FirebaseFirestore.instance
        .collection('workSessions')
        .where('teikerId', isEqualTo: widget.teiker.uid)
        .get();

    final sessions = <_EditableWorkSession>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final clienteId = (data['clienteId'] as String?)?.trim() ?? '';
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();
      if (clienteId.isEmpty || start == null || end == null) continue;

      final cliente = clientsById[clienteId] ?? _placeholderCliente(clienteId);
      sessions.add(
        _EditableWorkSession(
          id: doc.id,
          cliente: cliente,
          start: start,
          end: end,
          durationHours: _durationForSessionData(data),
        ),
      );
    }

    sessions.sort((a, b) => b.start.compareTo(a.start));
    return sessions;
  }

  Future<void> _openEditManualHoursSheet() async {
    if (!_canAddTeikerHoursByAdmin) {
      AppSnackBar.show(
        context,
        message: 'Só a admin pode alterar horas de uma teiker.',
        icon: Icons.lock_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    List<Clientes> clientes;
    List<_EditableWorkSession> sessions;
    try {
      clientes = await _loadManualHoursClientes(includeArchived: true);
      sessions = await _loadEditableHourSessions(clientes);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Não foi possível carregar os registos: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    if (!mounted) return;
    if (sessions.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Ainda não há horas para alterar nesta teiker.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final clientIds = clientes.map((cliente) => cliente.uid).toSet();
    final editableClientes = [...clientes];
    for (final session in sessions) {
      if (clientIds.add(session.cliente.uid)) {
        editableClientes.add(session.cliente);
      }
    }

    final selectedSession = await showModalBottomSheet<_EditableWorkSession>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditableHoursPickerSheet(
        primaryColor: _primaryColor,
        teikerName: widget.teiker.nameTeiker,
        sessions: sessions,
      ),
    );
    if (selectedSession == null || !mounted) return;

    final result = await showModalBottomSheet<_AdminManualHoursInput>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminManualHoursSheet(
        primaryColor: _primaryColor,
        teikerName: widget.teiker.nameTeiker,
        clientes: editableClientes,
        initialCliente: selectedSession.cliente,
        initialStart: selectedSession.start,
        initialEnd: selectedSession.end,
        title: 'Alterar horas',
        submitLabel: 'Atualizar',
      ),
    );
    if (result == null) return;

    try {
      await _workSessionService.updateManualSessionForTeikerByAdmin(
        sessionId: selectedSession.id,
        clienteId: result.cliente.uid,
        teikerId: widget.teiker.uid,
        start: result.start,
        end: result.end,
      );

      if (!mounted) return;
      setState(() {
        _hoursFuture = _hoursOverviewService.fetchMonthlyTotals(
          teikerId: widget.teiker.uid,
        );
      });
      AppSnackBar.show(
        context,
        message: 'Registo de horas atualizado.',
        icon: Icons.edit_calendar_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro a atualizar horas: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
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

  Future<void> _addTeikerDocument() async {
    if (!_canManageTeikerDocuments) return;
    if (_uploadingDocument) return;

    File? file;
    try {
      file = await _pickDocumentFile();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Não foi possível selecionar o ficheiro: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }
    if (file == null) return;
    if (!file.existsSync()) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Ficheiro não encontrado.',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    setState(() => _uploadingDocument = true);
    try {
      await _teikerDocumentService.uploadDocument(
        teikerId: widget.teiker.uid,
        file: file,
      );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Documento associado com sucesso.',
        icon: Icons.upload_file_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao associar documento: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingDocument = false);
      }
    }
  }

  Future<File?> _pickDocumentFile() async {
    if (Platform.isMacOS) {
      final fromMacDialog = await _pickWithMacSystemDialog();
      if (fromMacDialog != null) return fromMacDialog;
    }
    return _pickWithFileSelector();
  }

  Future<File?> _pickWithFileSelector() async {
    final selected = await openFile(confirmButtonText: 'Selecionar');
    if (selected == null || selected.path.trim().isEmpty) {
      return null;
    }
    return File(selected.path);
  }

  Future<File?> _pickWithMacSystemDialog() async {
    final result = await Process.run('osascript', const [
      '-e',
      'POSIX path of (choose file with prompt "Selecionar documento")',
    ]);

    if (result.exitCode != 0) {
      return null;
    }

    final rawPath = '${result.stdout}'.trim();
    if (rawPath.isEmpty) {
      return null;
    }

    return File(rawPath);
  }

  Future<void> _openTeikerDocument(TeikerDocument document) async {
    if (_openingDocumentIds.contains(document.id)) return;

    setState(() => _openingDocumentIds.add(document.id));
    try {
      await _teikerDocumentService.openDocument(document);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Não foi possível abrir o documento: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _openingDocumentIds.remove(document.id));
      }
    }
  }

  Future<void> _deleteTeikerDocument(TeikerDocument document) async {
    if (!_canManageTeikerDocuments) return;
    if (_deletingDocumentIds.contains(document.id)) return;

    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Remover documento',
      message:
          'Queres remover o documento "${document.fileName}" desta teiker?',
      confirmLabel: 'Remover',
      confirmColor: Colors.red.shade700,
    );
    if (!shouldDelete) return;

    setState(() => _deletingDocumentIds.add(document.id));
    try {
      await _teikerDocumentService.deleteDocument(
        teikerId: widget.teiker.uid,
        document: document,
      );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Documento removido.',
        icon: Icons.delete_outline_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao remover documento: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _deletingDocumentIds.remove(document.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teiker = widget.teiker;
    final showMarcacoesTab = !widget.isAdminSelfProfile;

    return Scaffold(
      appBar: buildAppBar(teiker.nameTeiker, seta: true),
      body: DefaultTabController(
        length: showMarcacoesTab ? 2 : 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppPillTabBar(
                primaryColor: _primaryColor,
                tabs: [
                  const Tab(text: 'Informações'),
                  if (showMarcacoesTab) const Tab(text: 'Marcações'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    TeikerDetailsInfoTab(
                      teiker: teiker,
                      birthDate: _birthDate,
                      primaryColor: _primaryColor,
                      hoursSectionTitle: _hoursSectionTitle,
                      emailController: _emailController,
                      telemovelController: _telemovelController,
                      canEditPersonalInfo: widget.canEditPersonalInfo,
                      showHoursSection: true,
                      canAddManualHours: _canAddManualHours,
                      canEditManualHours: _canEditManualHours,
                      phoneCountryIso: _phoneCountryIso,
                      onPhoneCountryChanged: (iso) {
                        setState(() => _phoneCountryIso = iso);
                      },
                      onEditBirthDate: _pickBirthDate,
                      onSaveChanges: _guardarAlteracoes,
                      hoursFuture: _hoursFuture,
                      onAddManualHours: _openAddManualHoursSheet,
                      onEditManualHours: _openEditManualHoursSheet,
                      manualHoursEntriesStream: _watchManualHoursEntries(),
                      highlightedManualHoursEntryId:
                          widget.initialManualHoursEntryId,
                      showDocumentsCard:
                          _showTeikerDocumentsCard &&
                          !widget.isAdminSelfProfile,
                      canManageDocuments:
                          _canManageTeikerDocuments &&
                          !widget.isAdminSelfProfile,
                      uploadingDocument: _uploadingDocument,
                      documentsStream: _teikerDocumentService
                          .watchTeikerDocuments(widget.teiker.uid),
                      deletingDocumentIds: _deletingDocumentIds,
                      onAddDocument: _addTeikerDocument,
                      onOpenDocument: _openTeikerDocument,
                      onDeleteDocument: _deleteTeikerDocument,
                    ),
                    if (showMarcacoesTab)
                      TeikerDetailsMarcacoesTab(
                        primaryColor: _primaryColor,
                        showBaixas: true,
                        showConsultas: true,
                        showFerias: true,
                        marcacoes: _marcacoes,
                        onAddMarcacao: _openMarcacaoSheet,
                        onOpenMarcacaoNotes: _openMarcacaoNotesDialog,
                        onEditMarcacao: _openMarcacaoSheet,
                        onDeleteMarcacao: _confirmDeleteMarcacao,
                        baixasPeriodos: _baixasPeriodos,
                        baixasDaysCount: _countBaixasDays(_baixasPeriodos),
                        onAddBaixa: () => _adicionarBaixa(),
                        onEditBaixa: _editarBaixaPeriodo,
                        onDeleteBaixa: _eliminarBaixaPeriodo,
                        consultas: _consultas,
                        onEditConsulta: _openConsultaSheet,
                        onDeleteConsulta: _confirmDeleteConsulta,
                        onAddConsulta: () => _openConsultaSheet(),
                        feriasPeriodos: _feriasPeriodos,
                        feriasDaysCount: _countFeriasDays(_feriasPeriodos),
                        onAddFerias: _adicionarFerias,
                        onEditFerias: _editarFeriasPeriodo,
                        onDeleteFerias: _eliminarFeriasPeriodo,
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

class _AdminManualHoursInput {
  const _AdminManualHoursInput({
    required this.cliente,
    required this.start,
    required this.end,
  });

  final Clientes cliente;
  final DateTime start;
  final DateTime end;
}

class _EditableWorkSession {
  const _EditableWorkSession({
    required this.id,
    required this.cliente,
    required this.start,
    required this.end,
    required this.durationHours,
  });

  final String id;
  final Clientes cliente;
  final DateTime start;
  final DateTime end;
  final double durationHours;
}

class _AdminManualHoursSheet extends StatefulWidget {
  const _AdminManualHoursSheet({
    required this.primaryColor,
    required this.teikerName,
    required this.clientes,
    this.initialCliente,
    this.initialStart,
    this.initialEnd,
    this.title = 'Adicionar horas',
    this.submitLabel = 'Guardar',
  });

  final Color primaryColor;
  final String teikerName;
  final List<Clientes> clientes;
  final Clientes? initialCliente;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final String title;
  final String submitLabel;

  @override
  State<_AdminManualHoursSheet> createState() => _AdminManualHoursSheetState();
}

class _AdminManualHoursSheetState extends State<_AdminManualHoursSheet> {
  late Clientes _selectedCliente;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _selectedCliente = widget.initialCliente ?? widget.clientes.first;
    final initialStart = widget.initialStart;
    final initialEnd = widget.initialEnd;
    if (initialStart != null) {
      _selectedDate = DateTime(
        initialStart.year,
        initialStart.month,
        initialStart.day,
      );
      _startTime = TimeOfDay.fromDateTime(initialStart);
    }
    if (initialEnd != null) {
      _endTime = TimeOfDay.fromDateTime(initialEnd);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'pt_PT').format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Selecionar';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final picked = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      title: 'Dia das horas',
      subtitle: 'Escolhe o dia trabalhado',
      confirmLabel: 'Usar dia',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await SingleTimePickerBottomSheet.show(
      context,
      initialTime: _startTime ?? TimeOfDay.now(),
      title: 'Hora de início',
      subtitle: 'Escolhe a hora inicial',
      confirmLabel: 'Usar hora',
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await SingleTimePickerBottomSheet.show(
      context,
      initialTime: _endTime ?? TimeOfDay.now(),
      title: 'Hora de fim',
      subtitle: 'Escolhe a hora final',
      confirmLabel: 'Usar hora',
    );
    if (picked == null) return;
    setState(() => _endTime = picked);
  }

  Future<void> _pickCliente() async {
    final options = widget.clientes
        .map(
          (cliente) => _ManualHoursPickerOption(
            id: cliente.uid,
            label: cliente.nameCliente,
            subtitle: cliente.moradaCliente,
          ),
        )
        .toList();

    final picked = await showModalBottomSheet<_ManualHoursPickerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: .78,
        child: _ManualHoursSearchablePickerSheet(
          title: 'Selecionar cliente',
          subtitle: 'Procura e escolhe o cliente',
          searchHint: 'Pesquisar cliente',
          options: options,
          selectedId: _selectedCliente.uid,
          primaryColor: widget.primaryColor,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (picked == null) return;
    setState(() {
      _selectedCliente = widget.clientes.firstWhere(
        (cliente) => cliente.uid == picked.id,
        orElse: () => _selectedCliente,
      );
    });
  }

  void _submit() {
    final startTime = _startTime;
    final endTime = _endTime;
    if (startTime == null || endTime == null) {
      AppSnackBar.show(
        context,
        message: 'Escolhe a hora de início e a hora de fim.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final start = _combine(_selectedDate, startTime);
    final end = _combine(_selectedDate, endTime);
    final now = DateTime.now();
    if (start.isAfter(now) || end.isAfter(now)) {
      AppSnackBar.show(
        context,
        message: 'Não podes adicionar horas no futuro.',
        icon: Icons.info_outline,
        background: Colors.red.shade700,
      );
      return;
    }
    if (!end.isAfter(start)) {
      AppSnackBar.show(
        context,
        message: 'A hora de fim deve ser posterior à hora de início.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    Navigator.of(context).pop(
      _AdminManualHoursInput(cliente: _selectedCliente, start: start, end: end),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: widget.title,
      subtitle: 'Registar horas para ${widget.teikerName}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManualHoursSelectorField(
            label: 'Cliente',
            value: _selectedCliente.nameCliente,
            icon: Icons.people_outline,
            primaryColor: widget.primaryColor,
            onTap: _pickCliente,
          ),
          const SizedBox(height: 12),
          _ManualHoursPickerTile(
            label: 'Dia',
            value: _formatDate(_selectedDate),
            icon: Icons.calendar_month_outlined,
            primaryColor: widget.primaryColor,
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ManualHoursPickerTile(
                  label: 'Início',
                  value: _formatTime(_startTime),
                  icon: Icons.play_circle_outline,
                  primaryColor: widget.primaryColor,
                  onTap: _pickStartTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ManualHoursPickerTile(
                  label: 'Fim',
                  value: _formatTime(_endTime),
                  icon: Icons.stop_circle_outlined,
                  primaryColor: widget.primaryColor,
                  onTap: _pickEndTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Cancelar',
                  outline: true,
                  color: widget.primaryColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  text: widget.submitLabel,
                  icon: Icons.save_rounded,
                  color: widget.primaryColor,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableHoursPickerSheet extends StatelessWidget {
  const _EditableHoursPickerSheet({
    required this.primaryColor,
    required this.teikerName,
    required this.sessions,
  });

  final Color primaryColor;
  final String teikerName;
  final List<_EditableWorkSession> sessions;

  String _formatSessionDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'pt_PT').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'pt_PT').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: 'Alterar horas',
      subtitle: 'Escolhe o registo de $teikerName que queres corrigir',
      child: SizedBox(
        height: 460,
        child: ListView.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final session = sessions[index];
            return InkWell(
              onTap: () => Navigator.of(context).pop(session),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: .16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_calendar, color: primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.cliente.nameCliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatSessionDate(session.start)} • ${_formatTime(session.start)} - ${_formatTime(session.end)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${session.durationHours.toStringAsFixed(1)} h',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: primaryColor),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManualHoursPickerOption {
  const _ManualHoursPickerOption({
    required this.id,
    required this.label,
    this.subtitle,
  });

  final String id;
  final String label;
  final String? subtitle;
}

class _ManualHoursSelectorField extends StatelessWidget {
  const _ManualHoursSelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.expand_more_rounded, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualHoursSearchablePickerSheet extends StatefulWidget {
  const _ManualHoursSearchablePickerSheet({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.options,
    required this.selectedId,
    required this.primaryColor,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<_ManualHoursPickerOption> options;
  final String? selectedId;
  final Color primaryColor;
  final VoidCallback? onBack;

  @override
  State<_ManualHoursSearchablePickerSheet> createState() =>
      _ManualHoursSearchablePickerSheetState();
}

class _ManualHoursSearchablePickerSheetState
    extends State<_ManualHoursSearchablePickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.options.where((option) {
      if (query.isEmpty) return true;
      return option.label.toLowerCase().contains(query) ||
          (option.subtitle ?? '').toLowerCase().contains(query);
    }).toList();

    return AppBottomSheetShell(
      title: widget.title,
      subtitle: widget.subtitle,
      leading: widget.onBack == null
          ? null
          : IconButton(
              onPressed: widget.onBack,
              icon: Icon(
                Icons.chevron_left_rounded,
                color: widget.primaryColor,
              ),
              splashRadius: 22,
              visualDensity: VisualDensity.compact,
            ),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            AppTextField(
              label: widget.searchHint,
              controller: _searchController,
              prefixIcon: Icons.search,
              focusColor: widget.primaryColor,
              borderColor: widget.primaryColor.withValues(alpha: .25),
              fillColor: Colors.grey.shade100,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Sem resultados.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final selected = option.id == widget.selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, option),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? widget.primaryColor.withValues(alpha: .12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? widget.primaryColor
                                    : widget.primaryColor.withValues(
                                        alpha: .15,
                                      ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (option.subtitle != null &&
                                          option.subtitle!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          option.subtitle!,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.chevron_right_rounded,
                                  color: selected
                                      ? widget.primaryColor
                                      : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualHoursPickerTile extends StatelessWidget {
  const _ManualHoursPickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
