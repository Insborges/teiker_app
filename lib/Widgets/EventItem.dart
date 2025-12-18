import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class EventItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final Color selectedColor;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;
  final bool showHours; // NOVO: controla se mostra horas

  const EventItem({
    super.key,
    required this.event,
    required this.selectedColor,
    required this.onDelete,
    required this.onToggleDone,
    this.showHours = true, // padrão true para compatibilidade
  });

  @override
  Widget build(BuildContext context) {
    final isDone = event['done'] ?? false;

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
        child: AnimatedContainer(
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
              // Stripe
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
              // Title & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDone ? Colors.green.shade900 : Colors.black87,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (showHours) ...[
                      const SizedBox(height: 3),
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
              // Trailing icon
              if (!event['isFerias']) // não mostrar botão de done para férias
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
        ),
      ),
    );
  }
}
