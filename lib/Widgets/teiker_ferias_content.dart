import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/models/Teikers.dart';

class TeikerFeriasContent extends StatelessWidget {
  const TeikerFeriasContent({
    super.key,
    required this.feriasPeriodos,
    required this.primaryColor,
    required this.onAddFerias,
    required this.onEditFerias,
    required this.onDeleteFerias,
  });

  final List<FeriasPeriodo> feriasPeriodos;
  final Color primaryColor;
  final VoidCallback onAddFerias;
  final void Function(int index, FeriasPeriodo periodo) onEditFerias;
  final void Function(int index, FeriasPeriodo periodo) onDeleteFerias;

  @override
  Widget build(BuildContext context) {
    final sorted = feriasPeriodos.asMap().entries.toList()
      ..sort((a, b) => b.value.inicio.compareTo(a.value.inicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sorted.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sorted.map((entry) {
              final index = entry.key;
              final periodo = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: .18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.beach_access_outlined,
                        color: primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _periodLabel(periodo),
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar período',
                            onPressed: () => onEditFerias(index, periodo),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.edit_outlined,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: 'Eliminar período',
                            onPressed: () => onDeleteFerias(index, periodo),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
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
                ),
              );
            }).toList(),
          )
        else
          const Text(
            'Ainda sem ferias registadas.',
            style: TextStyle(color: Colors.grey),
          ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Adicionar ferias',
          color: primaryColor,
          icon: Icons.beach_access,
          onPressed: onAddFerias,
        ),
      ],
    );
  }

  String _periodLabel(FeriasPeriodo periodo) {
    final start = DateFormat('dd MMM yyyy', 'pt_PT').format(periodo.inicio);
    final end = DateFormat('dd MMM yyyy', 'pt_PT').format(periodo.fim);
    if (DateUtils.isSameDay(periodo.inicio, periodo.fim)) {
      return start;
    }
    return '$start - $end';
  }
}
