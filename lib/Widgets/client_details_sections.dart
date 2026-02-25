import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/models/client_invoice.dart';
import 'package:teiker_app/theme/app_colors.dart';

class ClientIssuedInvoicesCard extends StatelessWidget {
  const ClientIssuedInvoicesCard({
    super.key,
    required this.primaryColor,
    required this.borderColor,
    required this.invoicesStream,
    required this.sharingInvoiceIds,
    required this.deletingInvoiceIds,
    required this.onShareInvoice,
    required this.onDeleteInvoice,
    this.canShareInvoices = true,
    this.canDeleteInvoices = true,
  });

  final Color primaryColor;
  final Color borderColor;
  final Stream<List<ClientInvoice>> invoicesStream;
  final Set<String> sharingInvoiceIds;
  final Set<String> deletingInvoiceIds;
  final Future<void> Function(ClientInvoice invoice) onShareInvoice;
  final Future<void> Function(ClientInvoice invoice) onDeleteInvoice;
  final bool canShareInvoices;
  final bool canDeleteInvoices;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'pt_PT', symbol: 'CHF ');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return StreamBuilder<List<ClientInvoice>>(
      stream: invoicesStream,
      builder: (context, snapshot) {
        final invoices = snapshot.data ?? const <ClientInvoice>[];
        final totalIssued = invoices.fold<double>(
          0,
          (running, item) => running + item.total,
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Faturas emitidas',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    money.format(totalIssued),
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (snapshot.hasError)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Text(
                    'Nao foi possivel carregar as faturas emitidas.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (invoices.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borderColor.withValues(alpha: .8),
                    ),
                  ),
                  child: const Text(
                    'Ainda nao existem faturas para este cliente.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Column(
                  children: invoices
                      .map(
                        (invoice) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: borderColor.withValues(alpha: .85),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${invoice.clientName} • ${invoice.invoiceNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${dateFormat.format(invoice.invoiceDate)} • ${invoice.periodLabel}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  money.format(invoice.total),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (canShareInvoices) ...[
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 30,
                                    child: sharingInvoiceIds.contains(invoice.id)
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton(
                                            tooltip: 'Partilhar fatura',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                onShareInvoice(invoice),
                                            icon: Icon(
                                              Icons.share_outlined,
                                              color: primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                  ),
                                ],
                                if (canDeleteInvoices) ...[
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 30,
                                    child:
                                        deletingInvoiceIds.contains(invoice.id)
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton(
                                            tooltip: 'Apagar fatura',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                onDeleteInvoice(invoice),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ClientAdditionalServicesSection extends StatelessWidget {
  const ClientAdditionalServicesSection({
    super.key,
    required this.primaryColor,
    required this.borderColor,
    required this.serviceMonthLabel,
    required this.appliedServicePrices,
    required this.onRemoveAppliedService,
    required this.onAddService,
    this.readOnly = false,
  });

  final Color primaryColor;
  final Color borderColor;
  final String serviceMonthLabel;
  final Map<String, double> appliedServicePrices;
  final Future<void> Function(String serviceKey) onRemoveAppliedService;
  final VoidCallback onAddService;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final appliedEntries = appliedServicePrices.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_business_outlined, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Serviços adicionais',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Valores para $serviceMonthLabel',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          if (appliedEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withValues(alpha: .7)),
              ),
              child: const Text(
                'Ainda sem serviços adicionados neste mês.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: appliedEntries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: borderColor.withValues(alpha: .8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${entry.key} • ${entry.value.toStringAsFixed(2)} CHF',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!readOnly)
                                IconButton(
                                  tooltip: 'Remover serviço',
                                  onPressed: () =>
                                      onRemoveAppliedService(entry.key),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (!readOnly) ...[
            const SizedBox(height: 10),
            AppButton(
              text: 'Adicionar Serviço',
              icon: Icons.add_rounded,
              color: primaryColor,
              onPressed: onAddService,
              verticalPadding: 13,
            ),
          ],
        ],
      ),
    );
  }
}

class ClientOrcamentoSummaryCard extends StatelessWidget {
  const ClientOrcamentoSummaryCard({
    super.key,
    required this.orcamento,
    required this.horas,
    required this.servicePrices,
  });

  final double orcamento;
  final double horas;
  final Map<String, double> servicePrices;

  @override
  Widget build(BuildContext context) {
    final totalHoras = horas * orcamento;
    final totalServicos = servicePrices.values.fold<double>(
      0,
      (total, item) => total + item,
    );
    final totalFinal = totalHoras + totalServicos;
    const primary = AppColors.primaryGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: .16), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Resumo de Horas & Preços',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ),
              Text(
                '${totalFinal.toStringAsFixed(2)} CHF',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ClientFinancialRow(
            icon: Icons.timer_outlined,
            label: 'Total Horas (${horas.toStringAsFixed(1)}h)',
            value: '${totalHoras.toStringAsFixed(2)} CHF',
            primary: primary,
          ),
          const SizedBox(height: 8),
          _ClientFinancialRow(
            icon: Icons.add_business_outlined,
            label: 'Preço Serviço',
            value: '${totalServicos.toStringAsFixed(2)} CHF',
            primary: primary,
          ),
          const SizedBox(height: 8),
          _ClientFinancialRow(
            icon: Icons.payments_rounded,
            label: 'Preço/Hora (${orcamento.toStringAsFixed(2)} CHF)',
            value: '${totalFinal.toStringAsFixed(2)} CHF',
            primary: primary,
            strong: true,
          ),
          if (servicePrices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: servicePrices.entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value.toStringAsFixed(2)} CHF',
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientFinancialRow extends StatelessWidget {
  const _ClientFinancialRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.primary,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color primary;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: strong ? .10 : .06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: primary, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
