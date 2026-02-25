import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/SingleTimePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/models/Teikers.dart';

class BaixaReasonSheet extends StatefulWidget {
  const BaixaReasonSheet({
    super.key,
    required this.primaryColor,
    this.initialReason = '',
  });

  final Color primaryColor;
  final String initialReason;

  @override
  State<BaixaReasonSheet> createState() => _BaixaReasonSheetState();
}

class _BaixaReasonSheetState extends State<BaixaReasonSheet> {
  late final TextEditingController _motivoController;

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController(text: widget.initialReason);
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _save() {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Indica o motivo da baixa.',
        icon: Icons.info_outline,
        background: Colors.red.shade700,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, motivo);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppBottomSheetShell(
        title: 'Motivo da baixa',
        subtitle: 'Escreve o motivo para guardar o período.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Motivo',
              controller: _motivoController,
              focusColor: widget.primaryColor,
              prefixIcon: Icons.description_outlined,
              fillColor: Colors.grey.shade100,
              borderColor: widget.primaryColor,
              borderRadius: 12,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.primaryColor,
                      side: BorderSide(color: widget.primaryColor, width: 1.4),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class ConsultaSheet extends StatefulWidget {
  const ConsultaSheet({super.key, this.consulta, required this.primaryColor});

  final Consulta? consulta;
  final Color primaryColor;

  @override
  State<ConsultaSheet> createState() => _ConsultaSheetState();
}

class TeikerMarcacaoSheet extends StatefulWidget {
  const TeikerMarcacaoSheet({
    super.key,
    this.marcacao,
    required this.primaryColor,
  });

  final TeikerMarcacao? marcacao;
  final Color primaryColor;

  @override
  State<TeikerMarcacaoSheet> createState() => _TeikerMarcacaoSheetState();
}

class _TeikerMarcacaoSheetState extends State<TeikerMarcacaoSheet> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedHour;
  late TeikerMarcacaoTipo _selectedTipo;

  @override
  void initState() {
    super.initState();
    final baseDate = widget.marcacao?.data ?? DateTime.now();
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _selectedHour = TimeOfDay.fromDateTime(baseDate);
    _selectedTipo = widget.marcacao?.tipo ?? TeikerMarcacaoTipo.reuniaoTrabalho;
  }

  Future<void> _pickDate() async {
    final picked = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: _selectedDate,
      title: 'Selecionar data',
      subtitle: 'Escolhe o dia da marcação',
      confirmLabel: 'Confirmar',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await SingleTimePickerBottomSheet.show(
      context,
      initialTime: _selectedHour,
      title: 'Selecionar hora',
      subtitle: 'Escolhe a hora da marcação',
      confirmLabel: 'Confirmar',
    );
    if (picked == null) return;
    setState(() => _selectedHour = picked);
  }

  void _save() {
    final date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedHour.hour,
      _selectedHour.minute,
    );

    Navigator.pop(
      context,
      TeikerMarcacao(
        id:
            widget.marcacao?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        data: date,
        tipo: _selectedTipo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM yyyy', 'pt_PT').format(_selectedDate);
    final timeLabel = _selectedHour.format(context);

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
                  widget.marcacao == null
                      ? 'Adicionar marcação'
                      : 'Editar marcação',
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _tipoChip(TeikerMarcacaoTipo.reuniaoTrabalho),
                _tipoChip(TeikerMarcacaoTipo.acompanhamento),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _selectionChip(
                    icon: Icons.calendar_today,
                    label: dateLabel,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _selectionChip(
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
                  widget.marcacao == null ? 'Guardar marcação' : 'Guardar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipoChip(TeikerMarcacaoTipo tipo) {
    final selected = _selectedTipo == tipo;
    return InkWell(
      onTap: () => setState(() => _selectedTipo = tipo),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? widget.primaryColor.withValues(alpha: .12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? widget.primaryColor
                : widget.primaryColor.withValues(alpha: .25),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tipo == TeikerMarcacaoTipo.reuniaoTrabalho
                  ? Icons.groups_2_outlined
                  : Icons.support_agent_outlined,
              size: 18,
              color: widget.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              tipo.label,
              style: TextStyle(
                color: selected ? widget.primaryColor : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionChip({
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

class _ConsultaSheetState extends State<ConsultaSheet> {
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
      AppSnackBar.show(
        context,
        message: 'Adiciona uma breve descricao.',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
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
    final dateLabel = DateFormat('dd MMM yyyy', 'pt_PT').format(selectedDate);
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
                      ? 'Adicionar consulta'
                      : 'Editar consulta',
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
              label: 'Descricao',
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
                  widget.consulta == null ? 'Guardar consulta' : 'Guardar',
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
