import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/models/Clientes.dart';

class EventAddSheet extends StatefulWidget {
  const EventAddSheet({
    super.key,
    required this.initialDate,
    required this.primaryColor,
    required this.onAddEvent,
    required this.clientes,
    this.teikers = const [],
    this.sheetTitle = 'Adicionar Lembrete',
    this.titleLabel = 'Título',
    this.submitLabel = 'Adicionar',
    this.showClienteSelector = true,
    this.showTeikerSelector = false,
    this.eventTag,
  });

  final DateTime initialDate;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onAddEvent;
  final List<Clientes> clientes;
  final List<Map<String, String>> teikers;
  final String sheetTitle;
  final String titleLabel;
  final String submitLabel;
  final bool showClienteSelector;
  final bool showTeikerSelector;
  final String? eventTag;

  @override
  State<EventAddSheet> createState() => _EventAddSheetState();
}

class _EventAddSheetState extends State<EventAddSheet> {
  final TextEditingController _titleController = TextEditingController();
  late DateTime _sheetDate;
  Clientes? _selectedCliente;
  Map<String, String>? _selectedTeiker;

  @override
  void initState() {
    super.initState();
    _sheetDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: _sheetDate,
      title: 'Selecionar data',
      subtitle: 'Escolhe o dia',
      confirmLabel: 'Confirmar',
    );
    if (picked == null) return;
    setState(() {
      _sheetDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickCliente() async {
    final options = widget.clientes
        .map(
          (cliente) => _PickerOption(
            id: cliente.uid,
            label: cliente.nameCliente,
            subtitle: cliente.moradaCliente,
          ),
        )
        .toList();

    final picked = await showModalBottomSheet<_PickerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: .78,
        child: _SearchablePickerSheet(
          title: 'Selecionar cliente',
          subtitle: 'Procura e escolhe o cliente',
          searchHint: 'Pesquisar cliente',
          options: options,
          selectedId: _selectedCliente?.uid,
          primaryColor: widget.primaryColor,
        ),
      ),
    );

    if (picked == null) return;
    setState(() {
      _selectedCliente = widget.clientes.firstWhere((c) => c.uid == picked.id);
    });
  }

  Future<void> _pickTeiker() async {
    final options = widget.teikers
        .map(
          (teiker) => _PickerOption(
            id: teiker['uid'] ?? '',
            label: teiker['name'] ?? '',
          ),
        )
        .where(
          (option) => option.id.trim().isNotEmpty && option.label.isNotEmpty,
        )
        .toList();

    final picked = await showModalBottomSheet<_PickerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: .78,
        child: _SearchablePickerSheet(
          title: 'Selecionar teiker',
          subtitle: 'Escolhe a responsável do acontecimento',
          searchHint: 'Pesquisar teiker',
          options: options,
          selectedId: _selectedTeiker?['uid'],
          primaryColor: widget.primaryColor,
        ),
      ),
    );

    if (picked == null) return;
    setState(() {
      _selectedTeiker = {'uid': picked.id, 'name': picked.label};
    });
  }

  Widget _selectorField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.primaryColor.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: widget.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more_rounded, color: widget.primaryColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM yyyy', 'pt_PT').format(_sheetDate);

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.sheetTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: widget.titleLabel,
                  controller: _titleController,
                  prefixIcon: Icons.edit,
                  focusColor: widget.primaryColor,
                  fillColor: Colors.grey.shade100,
                  borderColor: widget.primaryColor.withValues(alpha: .25),
                ),
                if (widget.showClienteSelector) ...[
                  const SizedBox(height: 12),
                  _selectorField(
                    label: 'Cliente',
                    icon: Icons.people_outline,
                    value:
                        _selectedCliente?.nameCliente ?? 'Selecionar cliente',
                    onTap: _pickCliente,
                  ),
                ],
                if (widget.showTeikerSelector) ...[
                  const SizedBox(height: 12),
                  _selectorField(
                    label: 'Teiker',
                    icon: Icons.person_outline,
                    value: _selectedTeiker?['name'] ?? 'Selecionar teiker',
                    onTap: _pickTeiker,
                  ),
                ],
                const SizedBox(height: 12),
                _selectorField(
                  label: 'Data',
                  icon: Icons.calendar_today_outlined,
                  value: dateLabel,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.submitLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                    ),
                    onPressed: () {
                      final text = _titleController.text.trim();
                      if (text.isEmpty) return;

                      if (widget.showClienteSelector &&
                          _selectedCliente == null) {
                        AppSnackBar.show(
                          context,
                          message: 'Seleciona um cliente.',
                          icon: Icons.info_outline,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      if (widget.showTeikerSelector &&
                          _selectedTeiker == null) {
                        AppSnackBar.show(
                          context,
                          message: 'Seleciona uma teiker.',
                          icon: Icons.info_outline,
                          background: Colors.red.shade700,
                        );
                        return;
                      }

                      final now = DateTime.now();
                      widget.onAddEvent({
                        'title': text,
                        'done': false,
                        'start': '',
                        'end': '',
                        'date': _sheetDate,
                        'clienteId': _selectedCliente?.uid,
                        'clienteName': _selectedCliente?.nameCliente,
                        'teikerId': _selectedTeiker?['uid'],
                        'teikerName': _selectedTeiker?['name'],
                        'createdAt': now,
                        if (widget.eventTag != null) 'tag': widget.eventTag,
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerOption {
  const _PickerOption({required this.id, required this.label, this.subtitle});

  final String id;
  final String label;
  final String? subtitle;
}

class _SearchablePickerSheet extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.options,
    required this.selectedId,
    required this.primaryColor,
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<_PickerOption> options;
  final String? selectedId;
  final Color primaryColor;

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
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
