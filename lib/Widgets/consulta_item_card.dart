import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/models/Teikers.dart';

class ConsultaItemCard extends StatelessWidget {
  const ConsultaItemCard({
    super.key,
    required this.consulta,
    required this.primaryColor,
    required this.onEdit,
    required this.onDelete,
  });

  final Consulta consulta;
  final Color primaryColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm', 'pt_PT').format(consulta.data);
    final dia = DateFormat('dd MMM yyyy', 'pt_PT').format(consulta.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_outlined, color: primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dia · $hora',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (consulta.descricao.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    consulta.descricao.trim(),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Editar consulta',
                onPressed: onEdit,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Eliminar consulta',
                onPressed: onDelete,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade700,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
