import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/TeikersDetais.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/backend/TeikerService.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/work_sessions/application/monthly_teiker_hours_service.dart';
import '../models/Teikers.dart';

enum _TeikerSort { az, hoursDesc }

class TeikersInfoScreen extends StatefulWidget {
  const TeikersInfoScreen({super.key});

  @override
  State<TeikersInfoScreen> createState() => _TeikersInfoScreenState();
}

class _TeikersInfoScreenState extends State<TeikersInfoScreen> {
  final Map<String, Future<Map<String, double>>> _hoursCache = {};
  final Map<String, double> _totalHoursCache = {};
  final MonthlyTeikerHoursService _monthlyHoursService =
      MonthlyTeikerHoursService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Teiker>> _teikersStream;
  late final String? _currentUserUid;
  late final bool _isAdmin;
  late final bool _isHr;
  late final bool _isPrivileged;

  bool _showFilters = false;
  bool _selectionMode = false;
  _TeikerSort _sort = _TeikerSort.az;
  final Set<String> _selectedTeikers = {};

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    _isAdmin = _authService.isCurrentUserAdmin;
    _isHr = _authService.isCurrentUserHr;
    _isPrivileged = _authService.isCurrentUserPrivileged;
    _teikersStream = TeikerService().streamTeikers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, double>> _getTeikerHours(String teikerId) {
    return _hoursCache.putIfAbsent(
      teikerId,
      () => _monthlyHoursService.fetchHoursByCliente(teikerId: teikerId),
    );
  }

  void _preloadHoursTotals(List<Teiker> teikers) {
    for (final teiker in teikers) {
      if (_totalHoursCache.containsKey(teiker.uid)) continue;

      _getTeikerHours(teiker.uid)
          .then((monthly) {
            if (!mounted) return;
            final total = monthly.values.fold<double>(0, (a, b) => a + b);
            if (_totalHoursCache[teiker.uid] == total) return;
            setState(() => _totalHoursCache[teiker.uid] = total);
          })
          .catchError((_) {
            if (!mounted) return;
            if (_totalHoursCache.containsKey(teiker.uid)) return;
            setState(() => _totalHoursCache[teiker.uid] = 0);
          });
    }
  }

  Future<void> _refreshTeikers() async {
    if (!mounted) return;
    setState(() {
      _hoursCache.clear();
      _totalHoursCache.clear();
      _selectedTeikers.clear();
    });
  }

  AppBar _buildTeikersAppBar() {
    return buildAppBar(
      'As Teikers',
      actions: [
        IconButton(
          onPressed: _refreshTeikers,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Atualizar',
        ),
      ],
    );
  }

  void _toggleSelected(String teikerId) {
    setState(() {
      if (_selectedTeikers.contains(teikerId)) {
        _selectedTeikers.remove(teikerId);
      } else {
        _selectedTeikers.add(teikerId);
      }
    });
  }

  Future<void> _deleteSelected(List<Teiker> teikers) async {
    if (_selectedTeikers.isEmpty) return;

    final selected = teikers
        .where((teiker) => _selectedTeikers.contains(teiker.uid))
        .toList();
    if (selected.isEmpty) return;

    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar teikers',
      message:
          'Tens a certeza que queres eliminar ${selected.length} teiker(s)? Esta ação é permanente.',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );

    if (!confirmed) return;

    try {
      await _authService.deleteTeikers(selected);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message:
            'Teikers eliminadas no Firestore. Para eliminar contas Auth de terceiros é necessário backend admin (Cloud Functions).',
        icon: Icons.delete_outline,
        background: Colors.green.shade700,
      );
      setState(() {
        _selectionMode = false;
        _selectedTeikers.clear();
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao eliminar teikers: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  List<Teiker> _applyFilters(List<Teiker> input) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = input.where((teiker) {
      if (_isHr &&
          _currentUserUid != null &&
          teiker.uid.trim() == _currentUserUid.trim()) {
        return false;
      }
      if (query.isEmpty) return true;
      return teiker.nameTeiker.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case _TeikerSort.az:
        filtered.sort(
          (a, b) =>
              a.nameTeiker.toLowerCase().compareTo(b.nameTeiker.toLowerCase()),
        );
      case _TeikerSort.hoursDesc:
        filtered.sort((a, b) {
          final ah = _totalHoursCache[a.uid] ?? 0;
          final bh = _totalHoursCache[b.uid] ?? 0;
          return bh.compareTo(ah);
        });
    }

    return filtered;
  }

  int _countFeriasDays(
    List<FeriasPeriodo> periodos, {
    DateTime? legacyStart,
    DateTime? legacyEnd,
  }) {
    final dayKeys = <DateTime>{};

    void addRange(DateTime start, DateTime end) {
      final normalizedStart = DateTime(start.year, start.month, start.day);
      final normalizedEnd = DateTime(end.year, end.month, end.day);
      var cursor = normalizedStart;
      while (!cursor.isAfter(normalizedEnd)) {
        dayKeys.add(DateTime(cursor.year, cursor.month, cursor.day));
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    for (final periodo in periodos) {
      addRange(periodo.inicio, periodo.fim);
    }
    if (legacyStart != null && legacyEnd != null) {
      addRange(legacyStart, legacyEnd);
    }

    return dayKeys.length;
  }

  double? _monthHoursForTeiker(String teikerId) {
    return _totalHoursCache[teikerId];
  }

  Widget _teikerCard(Teiker teiker) {
    final selected = _selectedTeikers.contains(teiker.uid);
    final primary = teiker.corIdentificadora;
    final isHrEntry = AppUserRoleResolver.isHrEmail(teiker.email);
    final consultasCount = teiker.consultas.length;
    final feriasPeriodos = teiker.feriasPeriodos;
    final feriasDays = _countFeriasDays(
      feriasPeriodos,
      legacyStart: teiker.feriasInicio,
      legacyEnd: teiker.feriasFim,
    );
    final currentMonthHours = _monthHoursForTeiker(teiker.uid);

    return InkWell(
      onTap: () {
        if (_isAdmin && _selectionMode) {
          _toggleSelected(teiker.uid);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TeikersDetails(teiker: teiker, canEditPersonalInfo: _isAdmin),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? const Border.fromBorderSide(
                  BorderSide(color: AppColors.primaryGreen, width: 1.5),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 80,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isAdmin && _selectionMode) ...[
                        Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          color: selected
                              ? AppColors.primaryGreen
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          teiker.nameTeiker,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      if (_isAdmin && isHrEntry)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(
                                alpha: .25,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Recursos Humanos',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (feriasDays > 0)
                        _infoChip(
                          icon: Icons.beach_access,
                          color: Colors.orange.shade700,
                          text:
                              'Férias: $feriasDays dia${feriasDays == 1 ? '' : 's'}',
                        ),
                      _infoChip(
                        icon: Icons.event_note,
                        color: primary,
                        text:
                            '$consultasCount consulta${consultasCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_selectionMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isHrEntry) ...[
                    Text(
                      currentMonthHours == null
                          ? '...h'
                          : '${currentMonthHours.toStringAsFixed(1)}h',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _iconBox({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryGreen.withValues(alpha: .12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: .18),
          ),
        ),
        child: Icon(
          icon,
          color: active ? AppColors.primaryGreen : Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Teiker>>(
      stream: _teikersStream,
      builder: (context, snapshot) {
        final listBottomInset =
            AppBottomNavBar.barHeight +
            MediaQuery.of(context).padding.bottom +
            16;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: _buildTeikersAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: _buildTeikersAppBar(),
            body: const Center(child: Text('Erro ao carregar teikers')),
          );
        }

        final teikers = snapshot.data ?? [];
        _preloadHoursTotals(teikers);
        final filteredTeikers = _applyFilters(teikers);

        return Scaffold(
          appBar: _buildTeikersAppBar(),
          body: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      controller: _searchController,
                      hintText: 'Pesquisar',
                      margin: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_isPrivileged)
                    _iconBox(
                      icon: Icons.filter_alt_outlined,
                      active: _showFilters,
                      onTap: () => setState(() => _showFilters = !_showFilters),
                    ),
                  if (_isPrivileged) const SizedBox(width: 6),
                  if (_isAdmin)
                    _iconBox(
                      icon: Icons.delete_outline,
                      active: _selectionMode,
                      onTap: () => setState(() {
                        _selectionMode = !_selectionMode;
                        _selectedTeikers.clear();
                      }),
                    ),
                  if (_isAdmin) const SizedBox(width: 12),
                ],
              ),
              if (_isPrivileged && _showFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('A-Z'),
                        selected: _sort == _TeikerSort.az,
                        onSelected: (_) =>
                            setState(() => _sort = _TeikerSort.az),
                      ),
                      ChoiceChip(
                        label: const Text('Mais horas'),
                        selected: _sort == _TeikerSort.hoursDesc,
                        onSelected: (_) =>
                            setState(() => _sort = _TeikerSort.hoursDesc),
                      ),
                    ],
                  ),
                ),
              if (_isAdmin && _selectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedTeikers.length} selecionado(s)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _selectedTeikers.isEmpty
                            ? null
                            : () => _deleteSelected(teikers),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectionMode = false;
                          _selectedTeikers.clear();
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredTeikers.isEmpty
                    ? const Center(child: Text('Nenhuma teiker encontrada'))
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: listBottomInset),
                        itemCount: filteredTeikers.length,
                        itemBuilder: (context, index) {
                          final teiker = filteredTeikers[index];
                          return _teikerCard(teiker);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
