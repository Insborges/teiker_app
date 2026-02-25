import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/client_invoice_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/client_invoice.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';

class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  final AuthService _authService = AuthService();
  final ClientInvoiceService _clientInvoiceService = ClientInvoiceService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _sharingInvoiceKeys = <String>{};
  final Set<String> _deletingInvoiceKeys = <String>{};

  List<Clientes> _clientes = const [];
  List<_WorkSessionEntry> _allSessions = const [];
  List<_ClienteInvoiceSummary> _summaries = const [];

  bool _loading = true;
  String? _error;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  List<int> _availableYears = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String get _selectedMonthKey =>
      _monthKey(DateTime(_selectedYear, _selectedMonth, 1));

  String _invoiceActionKey(ClientInvoice invoice) =>
      '${invoice.clientId}:${invoice.id}';

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final clientes = await _authService.getClientes(includeArchived: true);
      final sessionSnapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .get();

      final sessions = <_WorkSessionEntry>[];
      for (final doc in sessionSnapshot.docs) {
        final parsed = _parseSession(doc.data());
        if (parsed != null) {
          sessions.add(parsed);
        }
      }

      final years = <int>{DateTime.now().year};
      for (final session in sessions) {
        years.add(session.start.year);
      }
      for (final cliente in clientes) {
        for (final monthKey in cliente.additionalServicePricesByMonth.keys) {
          if (monthKey.length < 4) continue;
          final year = int.tryParse(monthKey.substring(0, 4));
          if (year != null) years.add(year);
        }
      }
      final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
      if (!sortedYears.contains(_selectedYear)) {
        _selectedYear = sortedYears.first;
      }

      _clientes = clientes;
      _allSessions = sessions;
      _availableYears = sortedYears;
      _rebuildSummaries();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar faturas: $e';
      });
    }
  }

  _WorkSessionEntry? _parseSession(Map<String, dynamic> data) {
    final clienteId = (data['clienteId'] as String?)?.trim() ?? '';
    if (clienteId.isEmpty) return null;

    final start = (data['startTime'] as Timestamp?)?.toDate();
    if (start == null) return null;

    double? duration = (data['durationHours'] as num?)?.toDouble();
    if (duration == null) {
      final rawStored = (data['rawDurationHours'] as num?)?.toDouble();
      if (rawStored != null) {
        final storedMultiplier = (data['durationMultiplier'] as num?)
            ?.toDouble();
        duration = storedMultiplier != null && storedMultiplier > 0
            ? rawStored * storedMultiplier
            : FixedHolidayHoursPolicy.applyToHours(
                workDate: start,
                rawHours: rawStored,
              );
      }
    }
    if (duration == null) {
      final end = (data['endTime'] as Timestamp?)?.toDate();
      if (end == null || !end.isAfter(start)) return null;
      duration = FixedHolidayHoursPolicy.applyToHours(
        workDate: start,
        rawHours: end.difference(start).inMinutes / 60.0,
      );
    }

    return _WorkSessionEntry(
      clienteId: clienteId,
      start: start,
      hours: duration,
    );
  }

  void _rebuildSummaries() {
    final monthStart = DateTime(_selectedYear, _selectedMonth, 1);
    final nextMonth = DateTime(_selectedYear, _selectedMonth + 1, 1);

    final hoursByClient = <String, double>{};
    final sessionsByClient = <String, int>{};

    for (final session in _allSessions) {
      final start = session.start;
      if (start.isBefore(monthStart) || !start.isBefore(nextMonth)) continue;
      hoursByClient.update(
        session.clienteId,
        (value) => value + session.hours,
        ifAbsent: () => session.hours,
      );
      sessionsByClient.update(
        session.clienteId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final monthKey = _monthKey(monthStart);
    final currentMonthKey = _monthKey(DateTime.now());

    final summaries = _clientes.map((cliente) {
      final monthlyServices =
          cliente.additionalServicePricesByMonth[monthKey] ??
          (monthKey == currentMonthKey
              ? cliente.additionalServicePrices
              : const <String, double>{});
      final serviceTotal = monthlyServices.values.fold<double>(
        0,
        (runningTotal, item) => runningTotal + item,
      );
      final hours = hoursByClient[cliente.uid] ?? 0;
      final hoursTotal = hours * cliente.orcamento;
      return _ClienteInvoiceSummary(
        cliente: cliente,
        sessionsCount: sessionsByClient[cliente.uid] ?? 0,
        totalHours: hours,
        hourlyRate: cliente.orcamento,
        hoursTotal: hoursTotal,
        servicePrices: monthlyServices,
        servicesTotal: serviceTotal,
      );
    }).toList();

    _summaries = summaries;
  }

  List<_ClienteInvoiceSummary> get _visibleSummaries {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _summaries.where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.cliente.nameCliente.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      final totalCompare = b.totalValue.compareTo(a.totalValue);
      if (totalCompare != 0) return totalCompare;
      return a.cliente.nameCliente.toLowerCase().compareTo(
        b.cliente.nameCliente.toLowerCase(),
      );
    });

    return filtered;
  }

  String _monthLabel(int month) {
    return DateFormat('MMMM', 'pt_PT').format(DateTime(2024, month));
  }

  Future<void> _shareInvoiceFromSummary(ClientInvoice invoice) async {
    final key = _invoiceActionKey(invoice);
    if (_sharingInvoiceKeys.contains(key)) return;

    setState(() => _sharingInvoiceKeys.add(key));
    try {
      await _clientInvoiceService.shareInvoiceDocument(invoice);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Fatura ${invoice.invoiceNumber} pronta para partilha.',
        icon: Icons.share_outlined,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao partilhar fatura: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _sharingInvoiceKeys.remove(key));
      }
    }
  }

  Future<void> _deleteInvoiceFromSummary(ClientInvoice invoice) async {
    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar fatura',
      message:
          'Tens a certeza que queres eliminar a fatura ${invoice.invoiceNumber}? Esta ação é permanente.',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );

    if (!shouldDelete) return;

    final key = _invoiceActionKey(invoice);
    if (_deletingInvoiceKeys.contains(key)) return;

    setState(() => _deletingInvoiceKeys.add(key));
    try {
      await _clientInvoiceService.deleteInvoice(
        clientId: invoice.clientId,
        invoiceId: invoice.id,
      );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Fatura ${invoice.invoiceNumber} eliminada.',
        icon: Icons.delete_outline_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao eliminar fatura: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _deletingInvoiceKeys.remove(key));
      }
    }
  }

  Widget _buildSelector<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: .14),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(_ClienteInvoiceSummary summary) {
    final money = NumberFormat.currency(locale: 'pt_PT', symbol: 'CHF ');
    final serviceEntries = summary.servicePrices.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.cliente.nameCliente,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Text(
                money.format(summary.totalValue),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Horas: ${summary.totalHours.toStringAsFixed(1)}h x ${summary.hourlyRate.toStringAsFixed(2)} = ${money.format(summary.hoursTotal)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Servicos adicionais: ${money.format(summary.servicesTotal)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (serviceEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: serviceEntries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.key}: ${money.format(entry.value)}',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${summary.sessionsCount} registo(s) neste mes',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildAssociatedInvoicesSection(summary, money),
        ],
      ),
    );
  }

  Widget _buildAssociatedInvoicesSection(
    _ClienteInvoiceSummary summary,
    NumberFormat money,
  ) {
    final selectedMonthKey = _selectedMonthKey;
    final dateFormat = DateFormat('dd/MM/yyyy');

    bool matchesSelectedMonth(ClientInvoice invoice) {
      if (invoice.periodMonthKey.trim() == selectedMonthKey) return true;
      final date = invoice.invoiceDate;
      return date.year == _selectedYear && date.month == _selectedMonth;
    }

    return StreamBuilder<List<ClientInvoice>>(
      stream: _clientInvoiceService.watchClientInvoices(summary.cliente.uid),
      builder: (context, snapshot) {
        final invoices =
            (snapshot.data ?? const <ClientInvoice>[])
                .where(matchesSelectedMonth)
                .toList()
              ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: .10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Faturas associadas',
                      style: TextStyle(
                        color: AppColors.primaryGreen.withValues(alpha: .95),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '${invoices.length}',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.hasError)
                const Text(
                  'Não foi possível carregar as faturas deste cliente.',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (invoices.isEmpty)
                const Text(
                  'Sem faturas emitidas neste mês.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Column(
                  children: invoices.map((invoice) {
                    final key = _invoiceActionKey(invoice);
                    final sharing = _sharingInvoiceKeys.contains(key);
                    final deleting = _deletingInvoiceKeys.contains(key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(
                              alpha: .12,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice.invoiceNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dateFormat.format(invoice.invoiceDate)} • ${invoice.periodLabel}',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              money.format(invoice.total),
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: sharing
                                  ? const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Partilhar fatura',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: deleting
                                          ? null
                                          : () => _shareInvoiceFromSummary(
                                              invoice,
                                            ),
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        size: 16,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: deleting
                                  ? const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Eliminar fatura',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: sharing
                                          ? null
                                          : () => _deleteInvoiceFromSummary(
                                              invoice,
                                            ),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat(
      'MMMM yyyy',
      'pt_PT',
    ).format(DateTime(_selectedYear, _selectedMonth)).toUpperCase();
    final visible = _visibleSummaries;
    final globalTotal = visible.fold<double>(
      0,
      (runningTotal, item) => runningTotal + item.totalValue,
    );

    return Scaffold(
      appBar: buildAppBar(
        'Faturas por cliente',
        seta: true,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                AppSearchBar(
                  controller: _searchController,
                  hintText: 'Pesquisar cliente',
                  onChanged: (_) => setState(() {}),
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSelector<int>(
                          value: _selectedYear,
                          items: _availableYears
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text('Ano $year'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedYear = value;
                              _rebuildSummaries();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSelector<int>(
                          value: _selectedMonth,
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(_monthLabel(index + 1)),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedMonth = value;
                              _rebuildSummaries();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            monthTitle,
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'pt_PT',
                            symbol: 'CHF ',
                          ).format(globalTotal),
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(
                          child: Text(
                            'Sem resultados.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            return _buildSummaryCard(visible[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _WorkSessionEntry {
  const _WorkSessionEntry({
    required this.clienteId,
    required this.start,
    required this.hours,
  });

  final String clienteId;
  final DateTime start;
  final double hours;
}

class _ClienteInvoiceSummary {
  const _ClienteInvoiceSummary({
    required this.cliente,
    required this.sessionsCount,
    required this.totalHours,
    required this.hourlyRate,
    required this.hoursTotal,
    required this.servicePrices,
    required this.servicesTotal,
  });

  final Clientes cliente;
  final int sessionsCount;
  final double totalHours;
  final double hourlyRate;
  final double hoursTotal;
  final Map<String, double> servicePrices;
  final double servicesTotal;

  double get totalValue => hoursTotal + servicesTotal;
}
