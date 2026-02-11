import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/cupertino_time_picker_sheet.dart';
import 'package:teiker_app/models/Clientes.dart';

class EventAddSheet extends StatefulWidget {
  final DateTime initialDate;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onAddEvent;
  final List<Clientes> clientes;

  const EventAddSheet({
    super.key,
    required this.initialDate,
    required this.primaryColor,
    required this.onAddEvent,
    required this.clientes,
  });

  @override
  _EventAddSheetState createState() => _EventAddSheetState();
}

class _EventAddSheetState extends State<EventAddSheet> {
  final TextEditingController _titleController = TextEditingController();
  late DateTime _sheetDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Clientes? _selectedCliente;

  @override
  void initState() {
    super.initState();
    _sheetDate = widget.initialDate;
  }

  void pickCupertinoTime(bool isStart) {
    final initialTime = isStart
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? TimeOfDay.now());

    showCupertinoTimePickerSheet(
      context,
      initialTime: initialTime,
      actionColor: widget.primaryColor,
      onChanged: (time) {
        setState(() {
          if (isStart) {
            _startTime = time;
          } else {
            _endTime = time;
          }
        });
      },
    );
  }

  Widget _timeInput(String label, TimeOfDay? time, bool isStart) {
    return InkWell(
      onTap: () => pickCupertinoTime(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.primaryColor),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: widget.primaryColor),
            const SizedBox(width: 8),
            Text(time != null ? time.format(context) : label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Adicionar Evento',
                      style: TextStyle(
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
                  label: 'Título',
                  controller: _titleController,
                  prefixIcon: Icons.edit,
                  focusColor: widget.primaryColor,
                  fillColor: Colors.grey.shade100,
                  borderColor: widget.primaryColor,
                ),
                const SizedBox(height: 12),
                if (widget.clientes.isNotEmpty) ...[
                  DropdownButtonFormField<Clientes>(
                    initialValue: _selectedCliente,
                    decoration: InputDecoration(
                      hintText: 'Selecionar cliente',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      prefixIcon: Icon(
                        Icons.people_outline,
                        color: widget.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: widget.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    items: widget.clientes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.nameCliente),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCliente = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _sheetDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: widget.primaryColor,
                            onPrimary: Colors.white,
                          ),
                          dialogTheme: const DialogThemeData(
                            backgroundColor: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _sheetDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.primaryColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: widget.primaryColor),
                        const SizedBox(width: 10),
                        Text(DateFormat('dd MMM yyyy').format(_sheetDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _timeInput('Início', _startTime, true)),
                    const SizedBox(width: 10),
                    Expanded(child: _timeInput('Fim', _endTime, false)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Adicionar Evento',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                      if (widget.clientes.isNotEmpty &&
                          _selectedCliente == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Seleciona um cliente.'),
                          ),
                        );
                        return;
                      }
                      final now = DateTime.now();
                      widget.onAddEvent({
                        'title': text,
                        'done': false,
                        'start': _startTime?.format(context) ?? '',
                        'end': _endTime?.format(context) ?? '',
                        'date': _sheetDate,
                        'clienteId': _selectedCliente?.uid,
                        'clienteName': _selectedCliente?.nameCliente,
                        'createdAt': now,
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
