import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:teiker_app/theme/app_colors.dart';

Future<void> showCupertinoTimePickerSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
  required ValueChanged<TimeOfDay> onChanged,
  Color actionColor = AppColors.primaryGreen,
}) {
  final now = DateTime.now();
  final initialDateTime = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );

  return showCupertinoModalPopup<void>(
    context: context,
    builder: (modalContext) => Container(
      height: 260,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF2F2F2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(modalContext),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: actionColor,
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
                initialDateTime: initialDateTime,
                onDateTimeChanged: (newTime) {
                  onChanged(TimeOfDay.fromDateTime(newTime));
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
