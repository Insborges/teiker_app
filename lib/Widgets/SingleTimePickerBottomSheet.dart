import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/theme/app_colors.dart';

class SingleTimePickerBottomSheet {
  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay? initialTime,
    String title = 'Selecionar hora',
    String subtitle = 'Escolhe a hora',
    String confirmLabel = 'Confirmar',
  }) async {
    return await showModalBottomSheet<TimeOfDay?>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SingleTimePickerSheet(
          initialTime: initialTime,
          title: title,
          subtitle: subtitle,
          confirmLabel: confirmLabel,
        );
      },
    );
  }
}

class _SingleTimePickerSheet extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String title;
  final String subtitle;
  final String confirmLabel;

  const _SingleTimePickerSheet({
    this.initialTime,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  @override
  State<_SingleTimePickerSheet> createState() => _SingleTimePickerSheetState();
}

class _SingleTimePickerSheetState extends State<_SingleTimePickerSheet> {
  late TimeOfDay selectedTime;

  @override
  void initState() {
    super.initState();
    selectedTime = widget.initialTime ?? TimeOfDay.now();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    return AppBottomSheetShell(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: initialDateTime,
              onDateTimeChanged: (newTime) {
                setState(() {
                  selectedTime = TimeOfDay.fromDateTime(newTime);
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _timeChip('Hora', selectedTime),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreenHex,
                ),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedTime),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenHex,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _timeChip(String label, TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return AppLabeledValueChip(label: label, value: '$hour:$minute');
  }
}
