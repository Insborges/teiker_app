import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventAddSheet extends StatefulWidget {
  final DateTime initialDate;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onAddEvent;

  const EventAddSheet({
    super.key,
    required this.initialDate,
    required this.primaryColor,
    required this.onAddEvent,
  });

  @override
  _EventAddSheetState createState() => _EventAddSheetState();
}

class _EventAddSheetState extends State<EventAddSheet> {
  final TextEditingController _titleController = TextEditingController();
  late DateTime _sheetDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _sheetDate = widget.initialDate;
  }

  void pickCupertinoTime(bool isStart) {
    showCupertinoModalPopup(
      context: context,
      builder: (builder) => Container(
        height: 260,
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF2F2F2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime.now(),
                  onDateTimeChanged: (DateTime newTime) {
                    setState(() {
                      final t = TimeOfDay.fromDateTime(newTime);
                      if (isStart) {
                        _startTime = t;
                      } else {
                        _endTime = t;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Título do evento...',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    prefixIcon: Icon(Icons.edit, color: widget.primaryColor),
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
                ),
                const SizedBox(height: 12),
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
                          ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
                      widget.onAddEvent({
                        'title': text,
                        'done': false,
                        'start': _startTime?.format(context) ?? '',
                        'end': _endTime?.format(context) ?? '',
                        'date': _sheetDate,
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
