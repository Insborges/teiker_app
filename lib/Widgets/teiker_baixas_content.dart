import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/models/Teikers.dart';

class TeikerBaixasContent extends StatelessWidget {
  const TeikerBaixasContent({
    super.key,
    required this.baixasPeriodos,
    required this.primaryColor,
    required this.onAddBaixa,
    required this.onEditBaixa,
    required this.onDeleteBaixa,
  });

  final List<BaixaPeriodo> baixasPeriodos;
  final Color primaryColor;
  final VoidCallback onAddBaixa;
  final void Function(int index, BaixaPeriodo periodo) onEditBaixa;
  final void Function(int index, BaixaPeriodo periodo) onDeleteBaixa;

  @override
  Widget build(BuildContext context) {
    final sorted = baixasPeriodos.asMap().entries.toList()
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.healing_outlined,
                        color: primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _periodLabel(periodo),
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (periodo.motivo.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                periodo.motivo.trim(),
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
                            tooltip: 'Editar baixa',
                            onPressed: () => onEditBaixa(index, periodo),
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
                            tooltip: 'Eliminar baixa',
                            onPressed: () => onDeleteBaixa(index, periodo),
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
            'Ainda sem períodos de baixa.',
            style: TextStyle(color: Colors.grey),
          ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Inserir baixa',
          color: primaryColor,
          icon: Icons.healing_outlined,
          onPressed: onAddBaixa,
        ),
      ],
    );
  }

  String _periodLabel(BaixaPeriodo periodo) {
    final start = DateFormat('dd MMM yyyy', 'pt_PT').format(periodo.inicio);
    final end = DateFormat('dd MMM yyyy', 'pt_PT').format(periodo.fim);
    return '$start - $end';
  }
}
