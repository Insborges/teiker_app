import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/theme/app_colors.dart';

class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

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
      final end = (data['endTime'] as Timestamp?)?.toDate();
      if (end == null || !end.isAfter(start)) return null;
      duration = end.difference(start).inMinutes / 60.0;
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
        ],
      ),
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
