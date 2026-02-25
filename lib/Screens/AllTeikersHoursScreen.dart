import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/models/Teikers.dart';
import 'package:teiker_app/models/teiker_workload.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/work_sessions/application/monthly_hours_overview_service.dart';

class AllTeikersHoursScreen extends StatefulWidget {
  const AllTeikersHoursScreen({super.key});

  @override
  State<AllTeikersHoursScreen> createState() => _AllTeikersHoursScreenState();
}

class _AllTeikersHoursScreenState extends State<AllTeikersHoursScreen> {
  final MonthlyHoursOverviewService _overviewService =
      MonthlyHoursOverviewService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _showGeneralSummary = false;

  List<_TeikerHoursSummary> _summaries = const [];
  List<DateTime> _months = const [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final viewer = FirebaseAuth.instance.currentUser;
      final viewerRole = AppUserRoleResolver.fromEmail(viewer?.email);
      final snapshot = await FirebaseFirestore.instance
          .collection('teikers')
          .get();
      final teikers =
          snapshot.docs
              .map((doc) => Teiker.fromMap(doc.data(), doc.id))
              .where((t) => t.uid.trim().isNotEmpty)
              .where(
                (t) =>
                    !(viewerRole.isHr &&
                        viewer != null &&
                        t.uid.trim() == viewer.uid.trim()),
              )
              .toList()
            ..sort(
              (a, b) => a.nameTeiker.toLowerCase().compareTo(
                b.nameTeiker.toLowerCase(),
              ),
            );

      final monthlyMaps = await Future.wait(
        teikers.map(
          (t) => _overviewService.fetchMonthlyTotals(teikerId: t.uid),
        ),
      );

      final allMonths = <DateTime>{};
      final summaries = <_TeikerHoursSummary>[];
      for (var i = 0; i < teikers.length; i++) {
        final teiker = teikers[i];
        final monthTotals = <DateTime, double>{};
        monthlyMaps[i].forEach((month, total) {
          final normalized = DateTime(month.year, month.month);
          monthTotals[normalized] = total;
          allMonths.add(normalized);
        });

        summaries.add(
          _TeikerHoursSummary(teiker: teiker, monthlyTotals: monthTotals),
        );
      }

      final months = allMonths.toList()..sort((a, b) => b.compareTo(a));
      final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
      final selected = months.contains(currentMonth)
          ? currentMonth
          : (months.isNotEmpty ? months.first : currentMonth);

      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _months = months;
        _selectedMonth = selected;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar horas das teikers: $e';
        _loading = false;
      });
    }
  }

  double _monthlyTargetHours(Teiker teiker, DateTime month) {
    final weeklyTarget = TeikerWorkload.weeklyHoursForPercentage(
      teiker.workPercentage,
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return weeklyTarget * (daysInMonth / 7.0);
  }

  double _periodHours(_TeikerHoursSummary summary) {
    if (_showGeneralSummary) {
      return summary.monthlyTotals.values.fold<double>(0, (a, b) => a + b);
    }
    return summary.monthlyTotals[_selectedMonth] ?? 0;
  }

  double _periodTarget(_TeikerHoursSummary summary) {
    if (_showGeneralSummary) {
      return summary.monthlyTotals.keys.fold<double>(
        0,
        (total, month) => total + _monthlyTargetHours(summary.teiker, month),
      );
    }
    return _monthlyTargetHours(summary.teiker, _selectedMonth);
  }

  List<_TeikerHoursSummary> _filteredSummaries() {
    final query = _searchController.text.trim().toLowerCase();
    final list = _summaries.where((item) {
      if (query.isEmpty) return true;
      return item.teiker.nameTeiker.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      final balanceA = _periodHours(a) - _periodTarget(a);
      final balanceB = _periodHours(b) - _periodTarget(b);
      return balanceB.compareTo(balanceA);
    });
    return list;
  }

  Future<void> _pickMonth() async {
    if (_months.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            itemCount: _months.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final month = _months[index];
              final selected = month == _selectedMonth;
              return ListTile(
                title: Text(
                  DateFormat('MMMM yyyy', 'pt_PT').format(month),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                trailing: selected
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primaryGreen,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedMonth = month;
                    _showGeneralSummary = false;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSummaries();

    return Scaffold(
      appBar: buildAppBar(
        'Horas das Teikers',
        seta: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                AppSearchBar(
                  controller: _searchController,
                  hintText: 'Pesquisar teiker',
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  onChanged: (_) => setState(() {}),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Mês atual / selecionado'),
                        selected: !_showGeneralSummary,
                        onSelected: (_) =>
                            setState(() => _showGeneralSummary = false),
                      ),
                      ChoiceChip(
                        label: const Text('Resumo geral'),
                        selected: _showGeneralSummary,
                        onSelected: (_) =>
                            setState(() => _showGeneralSummary = true),
                      ),
                      if (!_showGeneralSummary)
                        ActionChip(
                          label: Text(
                            _months.isEmpty
                                ? DateFormat(
                                    'MMMM yyyy',
                                    'pt_PT',
                                  ).format(_selectedMonth)
                                : DateFormat(
                                    'MMMM yyyy',
                                    'pt_PT',
                                  ).format(_selectedMonth),
                          ),
                          avatar: const Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                          onPressed: _pickMonth,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Sem teikers para mostrar.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final hours = _periodHours(item);
                            final target = _periodTarget(item);
                            final balance = hours - target;
                            return _TeikerHoursCard(
                              teikerName: item.teiker.nameTeiker,
                              workPercentage: item.teiker.workPercentage,
                              weeklyTarget:
                                  TeikerWorkload.weeklyHoursForPercentage(
                                    item.teiker.workPercentage,
                                  ),
                              hours: hours,
                              target: target,
                              balance: balance,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _TeikerHoursSummary {
  const _TeikerHoursSummary({
    required this.teiker,
    required this.monthlyTotals,
  });

  final Teiker teiker;
  final Map<DateTime, double> monthlyTotals;
}

class _TeikerHoursCard extends StatelessWidget {
  const _TeikerHoursCard({
    required this.teikerName,
    required this.workPercentage,
    required this.weeklyTarget,
    required this.hours,
    required this.target,
    required this.balance,
  });

  final String teikerName;
  final int workPercentage;
  final double weeklyTarget;
  final double hours;
  final double target;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final positive = balance >= 0;
    final accent = positive ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: .12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teikerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${positive ? '+' : ''}${balance.toStringAsFixed(1)}h',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Horas: ${hours.toStringAsFixed(1)}h • Meta mês: ${target.toStringAsFixed(1)}h',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Meta semanal: ${weeklyTarget.toStringAsFixed(0)}h ($workPercentage%)',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
