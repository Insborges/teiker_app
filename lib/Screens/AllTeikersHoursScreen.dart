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
        final adjustedMonthlyTotals = teiker.monthlyTotalsWithAdjustments(
          monthlyMaps[i],
        );
        adjustedMonthlyTotals.forEach((month, total) {
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
    return TeikerWorkload.monthlyHoursForPercentage(
      teiker.workPercentage,
      month,
    );
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

  double _periodBalance(_TeikerHoursSummary summary) {
    final base = _periodHours(summary) - _periodTarget(summary);
    if (!_showGeneralSummary) return base;
    return base + summary.teiker.hoursBalanceAdjustment;
  }

  List<_TeikerHoursSummary> _filteredSummaries() {
    final query = _searchController.text.trim().toLowerCase();
    final list = _summaries.where((item) {
      if (query.isEmpty) return true;
      return item.teiker.nameTeiker.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      final balanceA = _periodBalance(a);
      final balanceB = _periodBalance(b);
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isCompactPhone = width <= 380;
          final isTablet = width >= 720;
          final isDesktop = width >= 1120;
          final contentMaxWidth = isDesktop
              ? 1220.0
              : (isTablet ? 960.0 : 720.0);
          final horizontalPadding = isDesktop ? 24.0 : (isTablet ? 18.0 : 12.0);
          final gridColumns = isDesktop
              ? (width >= 1450 ? 3 : 2)
              : (isTablet ? 2 : 1);

          Widget body;
          if (_loading) {
            body = const Center(child: CircularProgressIndicator());
          } else if (_error != null) {
            body = _ScreenStateCard(
              icon: Icons.error_outline_rounded,
              title: 'Erro ao carregar',
              message: _error!,
              accent: Colors.red.shade700,
            );
          } else {
            body = Column(
              children: [
                _buildControlPanel(compact: isCompactPhone, wide: isTablet),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const _ScreenStateCard(
                          icon: Icons.people_outline_rounded,
                          title: 'Sem teikers para mostrar',
                          message:
                              'Ajusta a pesquisa ou aguarda novos registos.',
                          accent: AppColors.primaryGreen,
                        )
                      : gridColumns == 1
                      ? ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _buildTeikerHoursCard(
                              item,
                              compact: isCompactPhone,
                              wideLayout: false,
                            );
                          },
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridColumns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: isDesktop ? 178 : 188,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _buildTeikerHoursCard(
                              item,
                              compact: false,
                              wideLayout: true,
                            );
                          },
                        ),
                ),
              ],
            );
          }

          return SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    0,
                  ),
                  child: body,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlPanel({required bool compact, required bool wide}) {
    final periodLabel = _showGeneralSummary
        ? 'Resumo geral'
        : DateFormat('MMMM yyyy', 'pt_PT').format(_selectedMonth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: .12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'Pesquisar teiker',
                    margin: EdgeInsets.zero,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: _buildFilterWrap(
                    compact: compact,
                    wide: wide,
                    periodLabel: periodLabel,
                  ),
                ),
              ],
            )
          else ...[
            AppSearchBar(
              controller: _searchController,
              hintText: 'Pesquisar teiker',
              margin: EdgeInsets.zero,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _buildFilterWrap(
              compact: compact,
              wide: wide,
              periodLabel: periodLabel,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _showGeneralSummary
                ? 'Comparação anual acumulada por teiker.'
                : 'Comparação do mês selecionado face à meta de trabalho.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterWrap({
    required bool compact,
    required bool wide,
    required String periodLabel,
  }) {
    final labelStyle = TextStyle(
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w700,
    );

    return Align(
      alignment: wide ? Alignment.topRight : Alignment.centerLeft,
      child: Wrap(
        alignment: wide ? WrapAlignment.end : WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text(
              compact ? 'Mês' : 'Mês atual / selecionado',
              style: labelStyle,
            ),
            selected: !_showGeneralSummary,
            onSelected: (_) => setState(() => _showGeneralSummary = false),
          ),
          ChoiceChip(
            label: Text(compact ? 'Geral' : 'Resumo geral', style: labelStyle),
            selected: _showGeneralSummary,
            onSelected: (_) => setState(() => _showGeneralSummary = true),
          ),
          if (!_showGeneralSummary)
            ActionChip(
              label: Text(periodLabel, style: labelStyle),
              avatar: const Icon(
                Icons.calendar_month,
                size: 18,
                color: AppColors.primaryGreen,
              ),
              onPressed: _pickMonth,
            ),
        ],
      ),
    );
  }

  Widget _buildTeikerHoursCard(
    _TeikerHoursSummary item, {
    required bool compact,
    required bool wideLayout,
  }) {
    final hours = _periodHours(item);
    final target = _periodTarget(item);
    final balance = _periodBalance(item);

    return _TeikerHoursCard(
      teikerName: item.teiker.nameTeiker,
      workPercentage: item.teiker.workPercentage,
      weeklyTarget: TeikerWorkload.weeklyHoursForPercentage(
        item.teiker.workPercentage,
      ),
      hours: hours,
      target: target,
      balance: balance,
      compact: compact,
      wideLayout: wideLayout,
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
    required this.compact,
    required this.wideLayout,
  });

  final String teikerName;
  final int workPercentage;
  final double weeklyTarget;
  final double hours;
  final double target;
  final double balance;
  final bool compact;
  final bool wideLayout;

  @override
  Widget build(BuildContext context) {
    final positive = balance >= 0;
    final neutral = balance.abs() < 0.05;
    final accent = neutral
        ? Colors.grey.shade700
        : positive
        ? Colors.green.shade700
        : Colors.red.shade700;
    final balanceLabel = balance.abs() < 0.05
        ? 'Meta do mês atingida'
        : positive
        ? '${balance.toStringAsFixed(1)} h a mais'
        : '${balance.abs().toStringAsFixed(1)} h a menos';
    final primary = AppColors.primaryGreen;
    final titleStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: wideLayout ? 16 : (compact ? 14 : 15),
    );
    final metricLabelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: compact ? 11 : 12,
      color: Colors.grey.shade600,
    );
    final metricValueStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 12 : 13,
      color: Colors.black87,
    );

    return Container(
      padding: EdgeInsets.all(wideLayout ? 16 : (compact ? 10 : 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: .12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wideLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teikerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Meta semanal ${weeklyTarget.toStringAsFixed(0)}h • $workPercentage%',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _BalanceBadge(label: balanceLabel, color: accent),
              ],
            )
          else ...[
            Text(teikerName, style: titleStyle),
            const SizedBox(height: 8),
            _BalanceBadge(label: balanceLabel, color: accent, fullWidth: true),
          ],
          SizedBox(height: wideLayout ? 12 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HoursMetricChip(
                icon: Icons.schedule_rounded,
                label: 'Horas',
                value: '${hours.toStringAsFixed(1)}h',
                labelStyle: metricLabelStyle,
                valueStyle: metricValueStyle.copyWith(color: primary),
                compact: compact,
              ),
              _HoursMetricChip(
                icon: Icons.flag_outlined,
                label: 'Meta mês',
                value: '${target.toStringAsFixed(1)}h',
                labelStyle: metricLabelStyle,
                valueStyle: metricValueStyle,
                compact: compact,
              ),
              if (!wideLayout)
                _HoursMetricChip(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Meta semanal',
                  value:
                      '${weeklyTarget.toStringAsFixed(0)}h ($workPercentage%)',
                  labelStyle: metricLabelStyle,
                  valueStyle: metricValueStyle,
                  compact: compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({
    required this.label,
    required this.color,
    this.fullWidth = false,
  });

  final String label;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: fullWidth ? TextAlign.center : TextAlign.end,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}

class _HoursMetricChip extends StatelessWidget {
  const _HoursMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 118 : 132),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenStateCard extends StatelessWidget {
  const _ScreenStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
