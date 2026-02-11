import 'package:flutter/material.dart';

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info,
    Color background = Colors.black87,
    Duration? duration,
    int? durationMs,
  }) {
    // Prioridade para durationMs se existir
    final effectiveDuration = durationMs != null
        ? Duration(milliseconds: durationMs)
        : (duration ?? const Duration(seconds: 2));

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: effectiveDuration,
      ),
    );
  }
}
