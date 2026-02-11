import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/TeikersDetais.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
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
  late final bool _isAdmin;

  bool _showFilters = false;
  bool _selectionMode = false;
  _TeikerSort _sort = _TeikerSort.az;
  final Set<String> _selectedTeikers = {};

  @override
  void initState() {
    super.initState();
    _isAdmin = _authService.isCurrentUserAdmin;
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

  Widget _teikerCard(Teiker teiker) {
    final selected = _selectedTeikers.contains(teiker.uid);
    final primary = teiker.corIdentificadora;
    final consultasCount = teiker.consultas.length;
    final feriasPeriodos = teiker.feriasPeriodos;
    final hasLegacyFerias =
        feriasPeriodos.isEmpty &&
        teiker.feriasInicio != null &&
        teiker.feriasFim != null;

    return InkWell(
      onTap: () {
        if (_isAdmin && _selectionMode) {
          _toggleSelected(teiker.uid);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeikersDetails(teiker: teiker)),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FutureBuilder<Map<String, double>>(
                          future: _getTeikerHours(teiker.uid),
                          builder: (context, hoursSnap) {
                            if (hoursSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                width: 50,
                                height: 16,
                                child: Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final data = hoursSnap.data ?? {};
                            final total = data.values.fold<double>(
                              0,
                              (a, b) => a + b,
                            );
                            _totalHoursCache[teiker.uid] = total;

                            return Text(
                              '${total.toStringAsFixed(1)}h',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (feriasPeriodos.isNotEmpty || hasLegacyFerias)
                        _infoChip(
                          icon: Icons.beach_access,
                          color: Colors.orange.shade700,
                          text: feriasPeriodos.isNotEmpty
                              ? 'Férias: ${feriasPeriodos.length} período${feriasPeriodos.length == 1 ? '' : 's'}'
                              : 'Férias: ${teiker.feriasInicio!.day}/${teiker.feriasInicio!.month} - ${teiker.feriasFim!.day}/${teiker.feriasFim!.month}',
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
              const Icon(Icons.chevron_right, color: Colors.grey),
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
            appBar: buildAppBar('As Teikers'),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: buildAppBar('As Teikers'),
            body: const Center(child: Text('Erro ao carregar teikers')),
          );
        }

        final teikers = snapshot.data ?? [];
        final filteredTeikers = _applyFilters(teikers);

        return Scaffold(
          appBar: buildAppBar('As Teikers'),
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
                  if (_isAdmin)
                    _iconBox(
                      icon: Icons.filter_alt_outlined,
                      active: _showFilters,
                      onTap: () => setState(() => _showFilters = !_showFilters),
                    ),
                  if (_isAdmin) const SizedBox(width: 6),
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
              if (_showFilters)
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
