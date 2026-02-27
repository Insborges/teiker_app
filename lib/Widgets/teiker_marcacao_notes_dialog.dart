import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/backend/reunioes_template_service.dart';

class TeikerMarcacaoNotesDialog {
  const TeikerMarcacaoNotesDialog._();

  static Future<void> show({
    required BuildContext context,
    required Color primaryColor,
    required String tipoMarcacao,
    required String teikerName,
    required DateTime dataHoraMarcacao,
    required String initialNote,
    required String writerName,
    required AppUserRole writerRole,
    required Future<void> Function(String note) onSaveNote,
    Future<void> Function()? onEditMarcacao,
    Future<void> Function()? onDeleteMarcacao,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _TeikerMarcacaoNotesDialogView(
        hostContext: context,
        primaryColor: primaryColor,
        tipoMarcacao: tipoMarcacao,
        teikerName: teikerName,
        dataHoraMarcacao: dataHoraMarcacao,
        initialNote: initialNote,
        writerName: writerName,
        writerRole: writerRole,
        onSaveNote: onSaveNote,
        onEditMarcacao: onEditMarcacao,
        onDeleteMarcacao: onDeleteMarcacao,
      ),
    );
  }

  static Widget _metaRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeikerMarcacaoNotesDialogView extends StatefulWidget {
  const _TeikerMarcacaoNotesDialogView({
    required this.hostContext,
    required this.primaryColor,
    required this.tipoMarcacao,
    required this.teikerName,
    required this.dataHoraMarcacao,
    required this.initialNote,
    required this.writerName,
    required this.writerRole,
    required this.onSaveNote,
    this.onEditMarcacao,
    this.onDeleteMarcacao,
  });

  final BuildContext hostContext;
  final Color primaryColor;
  final String tipoMarcacao;
  final String teikerName;
  final DateTime dataHoraMarcacao;
  final String initialNote;
  final String writerName;
  final AppUserRole writerRole;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function()? onEditMarcacao;
  final Future<void> Function()? onDeleteMarcacao;

  @override
  State<_TeikerMarcacaoNotesDialogView> createState() =>
      _TeikerMarcacaoNotesDialogViewState();
}

class _TeikerMarcacaoNotesDialogViewState
    extends State<_TeikerMarcacaoNotesDialogView> {
  late final TextEditingController _notesController;
  final ReunioesTemplateService _templateService = ReunioesTemplateService();

  bool _saving = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _writerSuffix() {
    if (widget.writerRole.isAdmin) return 'Owner Teiker';
    if (widget.writerRole.isHr) return 'Recursos Humanos';
    return 'Teiker';
  }

  String _normalizedWriterName() {
    final trimmed = widget.writerName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (widget.writerRole.isAdmin) return 'Admin';
    if (widget.writerRole.isHr) return 'Recursos Humanos';
    return 'Teiker';
  }

  Future<void> _closeAndRun(Future<void> Function()? action) async {
    if (action == null) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await action();
  }

  Future<void> _saveOnly({bool closeAfterSave = false}) async {
    final note = _notesController.text.trim();
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await widget.onSaveNote(note);
      if (!mounted) return;
      AppSnackBar.show(
        widget.hostContext,
        message: 'Anotação guardada.',
        icon: Icons.check_rounded,
        background: Colors.green.shade700,
      );
      if (closeAfterSave && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        widget.hostContext,
        message: 'Erro ao guardar anotação: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _generateTemplate() async {
    final note = _notesController.text.trim();
    if (note.isEmpty) {
      AppSnackBar.show(
        widget.hostContext,
        message: 'Escreve a anotação antes de gerar o template.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _generating = true);
    try {
      final renderObject = context.findRenderObject();
      final shareOrigin = renderObject is RenderBox
          ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
          : null;

      await widget.onSaveNote(note);
      await _templateService.shareTemplate(
        nomeTeiker: widget.teikerName,
        nota: note,
        quemEscreveuNota: '${_normalizedWriterName()} - ${_writerSuffix()}',
        dataHora: widget.dataHoraMarcacao,
        tipoMarcacao: widget.tipoMarcacao,
        sharePositionOrigin: shareOrigin,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        widget.hostContext,
        message: 'Erro ao gerar template: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'dd/MM/yyyy HH:mm',
      'pt_PT',
    ).format(widget.dataHoraMarcacao);
    final maxBodyHeight = MediaQuery.sizeOf(context).height * .58;
    final busy = _saving || _generating;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F3),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: widget.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anotação da Marcação',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.tipoMarcacao} • ${widget.teikerName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar marcação',
                    onPressed: (busy || widget.onEditMarcacao == null)
                        ? null
                        : () => _closeAndRun(widget.onEditMarcacao),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Eliminar marcação',
                    onPressed: (busy || widget.onDeleteMarcacao == null)
                        ? null
                        : () => _closeAndRun(widget.onDeleteMarcacao),
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.primaryColor.withValues(alpha: .14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TeikerMarcacaoNotesDialog._metaRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Teiker',
                              value: widget.teikerName,
                              color: widget.primaryColor,
                            ),
                            const SizedBox(height: 8),
                            TeikerMarcacaoNotesDialog._metaRow(
                              icon: Icons.schedule_rounded,
                              label: 'Data e hora',
                              value: dateLabel,
                              color: widget.primaryColor,
                            ),
                            const SizedBox(height: 8),
                            TeikerMarcacaoNotesDialog._metaRow(
                              icon: Icons.badge_outlined,
                              label: 'Quem escreve',
                              value:
                                  '${_normalizedWriterName()} - ${_writerSuffix()}',
                              color: widget.primaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Nota',
                        controller: _notesController,
                        prefixIcon: Icons.notes_rounded,
                        prefixIconAlignTop: true,
                        focusColor: widget.primaryColor,
                        fillColor: Colors.white,
                        borderColor: widget.primaryColor.withValues(alpha: .2),
                        borderRadius: 14,
                        maxLines: 8,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : _saveOnly,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: widget.primaryColor,
                                side: BorderSide(
                                  color: widget.primaryColor.withValues(
                                    alpha: .35,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              label: const Text('Guardar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: busy ? null : _generateTemplate,
                              icon: _generating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.description_outlined),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              label: const Text('Gerar Template'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
