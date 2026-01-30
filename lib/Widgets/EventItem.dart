import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class EventItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final Color selectedColor;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;
  final bool showHours; // NOVO: controla se mostra horas
  final bool readOnly;
  final String? tag;

  const EventItem({
    super.key,
    required this.event,
    required this.selectedColor,
    required this.onDelete,
    required this.onToggleDone,
    this.showHours = true, // padrão true para compatibilidade
    this.readOnly = false,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = event['done'] ?? false;
    final tagText = tag ?? event['tag'] as String?;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 5,
            height: 36,
            decoration: BoxDecoration(
              color: isDone ? selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        event['title'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              isDone ? Colors.green.shade900 : Colors.black87,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (tagText != null) _tagChip(tagText),
                  ],
                ),
                if (showHours) ...[
                  const SizedBox(height: 3),
                  if (event['subtitle'] != null)
                    Text(
                      event['subtitle'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  if (event['subtitle'] != null) const SizedBox(height: 2),
                  Text(
                    "${event['start'] ?? ''}${(event['start'] != null && (event['end'] ?? '') != '') ? ' — ' : ''}${event['end'] ?? ''}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!readOnly)
            GestureDetector(
              onTap: onToggleDone,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isDone
                    ? Icon(
                        Icons.check_circle,
                        color: selectedColor,
                        size: 24,
                        key: const ValueKey('done'),
                      )
                    : Icon(
                        Icons.check_circle_outline,
                        color: selectedColor,
                        size: 22,
                        key: const ValueKey('todo'),
                      ),
              ),
            ),
        ],
      ),
    );

    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Slidable(
        key: ValueKey(event),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              icon: Icons.delete,
              label: 'Eliminar',
              backgroundColor: Colors.red.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: card,
      ),
    );
  }

  Widget _tagChip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selectedColor.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selectedColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
