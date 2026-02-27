import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/ClientsDetails.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppCard.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/work_sessions/application/monthly_hours_overview_service.dart';
import 'package:teiker_app/work_sessions/domain/work_session.dart';
import '../models/Clientes.dart';

enum _ClientesSort { az, hoursDesc }

enum _ClientesBulkMode { none, archive, delete }

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final Map<String, WorkSession?> _openSessions = {};
  final Map<String, Future<Map<DateTime, double>>> _hoursByClienteFuture = {};
  final Map<String, double> _currentMonthHoursCache = {};
  String _openSessionsKey = '';
  final WorkSessionService _workSessionService = WorkSessionService();
  final MonthlyHoursOverviewService _monthlyHoursOverviewService =
      MonthlyHoursOverviewService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Clientes>> _clientesFuture;
  late final bool _isAdmin;
  late final bool _isHr;
  late final bool _isPrivileged;
  late final String? _currentUserId;

  bool _showFilters = false;
  bool _onlyArchived = false;
  _ClientesSort _sort = _ClientesSort.az;
  _ClientesBulkMode _bulkMode = _ClientesBulkMode.none;
  final Set<String> _selectedClientes = {};

  bool get _isSelecting => _bulkMode != _ClientesBulkMode.none;
  bool get _hasAnyOpenSession => _openSessions.values.any((s) => s != null);
  bool get _hasActiveSearchOrFilters =>
      _searchController.text.trim().isNotEmpty ||
      _showFilters ||
      _onlyArchived ||
      _sort != _ClientesSort.az;

  @override
  void initState() {
    super.initState();
    final role = _authService.currentUserRole;
    _isAdmin = role.isAdmin;
    _isHr = role.isHr;
    _isPrivileged = role.isPrivileged;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _clientesFuture = _loadClientes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Clientes>> _loadClientes() async {
    final clientes = await _authService.getClientes(
      includeArchived: _isPrivileged,
    );

    if (_isPrivileged) return clientes;

    final now = DateTime.now();
    final totals = await Future.wait(
      clientes.map(
        (cliente) => _workSessionService.calculateMonthlyTotalForCurrentUser(
          clienteId: cliente.uid,
          referenceDate: now,
        ),
      ),
    );

    for (var i = 0; i < clientes.length; i++) {
      clientes[i].hourasCasa = totals[i];
      _currentMonthHoursCache[clientes[i].uid] = totals[i];
    }

    return clientes;
  }

  Future<Map<DateTime, double>> _getClienteHoursByMonth(String clienteId) {
    return _hoursByClienteFuture.putIfAbsent(
      clienteId,
      () => _monthlyHoursOverviewService.fetchMonthlyTotals(
        teikerId: _isPrivileged ? null : _currentUserId,
        clienteId: clienteId,
      ),
    );
  }

  double _currentMonthHoursFromMap(Map<DateTime, double> monthlyTotals) {
    final now = DateTime.now();
    return monthlyTotals[DateTime(now.year, now.month)] ?? 0;
  }

  void _preloadCurrentMonthHours(List<Clientes> clientes) {
    for (final cliente in clientes) {
      if (_currentMonthHoursCache.containsKey(cliente.uid)) continue;
      _getClienteHoursByMonth(cliente.uid)
          .then((monthlyTotals) {
            if (!mounted) return;
            final total = _currentMonthHoursFromMap(monthlyTotals);
            if (_currentMonthHoursCache[cliente.uid] == total) return;
            setState(() => _currentMonthHoursCache[cliente.uid] = total);
          })
          .catchError((_) {
            if (!mounted) return;
            if (_currentMonthHoursCache.containsKey(cliente.uid)) return;
            setState(() => _currentMonthHoursCache[cliente.uid] = 0);
          });
    }
  }

  Future<void> _ensureOpenSessions(List<Clientes> clientes) async {
    final missing = clientes
        .where((cliente) => !_openSessions.containsKey(cliente.uid))
        .toList();

    if (missing.isEmpty) return;

    final results = await Future.wait(
      missing.map(
        (cliente) => _workSessionService.findOpenSession(cliente.uid),
      ),
    );

    if (!mounted) return;

    setState(() {
      for (var i = 0; i < missing.length; i++) {
        _openSessions[missing[i].uid] = results[i];
      }
    });
  }

  Future<void> _updateClienteHours(Clientes cliente) async {
    if (!_isPrivileged) {
      final total = await _workSessionService
          .calculateMonthlyTotalForCurrentUser(
            clienteId: cliente.uid,
            referenceDate: DateTime.now(),
          );
      if (!mounted) return;
      setState(() {
        cliente.hourasCasa = total;
        _currentMonthHoursCache[cliente.uid] = total;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _hoursByClienteFuture.remove(cliente.uid);
      _currentMonthHoursCache.remove(cliente.uid);
    });
    _preloadCurrentMonthHours([cliente]);
  }

  Future<void> _refreshClientes() async {
    if (!mounted) return;
    setState(() {
      _clientesFuture = _loadClientes();
      _openSessions.clear();
      _openSessionsKey = '';
      _selectedClientes.clear();
      _hoursByClienteFuture.clear();
      _currentMonthHoursCache.clear();
    });
  }

  AppBar _buildClientesAppBar() {
    return buildAppBar(
      'Os Clientes Teiker',
      actions: [
        IconButton(
          onPressed: _refreshClientes,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Atualizar',
        ),
      ],
    );
  }

  void _toggleSelected(String clienteId) {
    setState(() {
      if (_selectedClientes.contains(clienteId)) {
        _selectedClientes.remove(clienteId);
      } else {
        _selectedClientes.add(clienteId);
      }
    });
  }

  void _setBulkMode(_ClientesBulkMode mode) {
    setState(() {
      _bulkMode = _bulkMode == mode ? _ClientesBulkMode.none : mode;
      _selectedClientes.clear();
    });
  }

  Future<void> _archiveSelected() async {
    if (_selectedClientes.isEmpty) return;

    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Arquivar clientes',
      message:
          'Tens a certeza que queres arquivar ${_selectedClientes.length} cliente(s)?',
      confirmLabel: 'Arquivar',
      confirmColor: AppColors.primaryGreen,
    );
    if (!confirmed) return;

    try {
      await _authService.archiveClientes(
        _selectedClientes.toList(),
        archivedBy: 'Admin',
      );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Clientes arquivados com sucesso.',
        icon: Icons.archive_outlined,
        background: Colors.green.shade700,
      );
      setState(() {
        _bulkMode = _ClientesBulkMode.none;
        _selectedClientes.clear();
      });
      await _refreshClientes();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao arquivar clientes: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedClientes.isEmpty) return;

    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Eliminar clientes',
      message:
          'Tens a certeza que queres eliminar ${_selectedClientes.length} cliente(s)? Esta ação é permanente.',
      confirmLabel: 'Eliminar',
      confirmColor: Colors.red.shade700,
    );
    if (!confirmed) return;

    try {
      await _authService.deleteClientes(_selectedClientes.toList());
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Clientes eliminados com sucesso.',
        icon: Icons.delete_outline,
        background: Colors.green.shade700,
      );
      setState(() {
        _bulkMode = _ClientesBulkMode.none;
        _selectedClientes.clear();
      });
      await _refreshClientes();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro ao eliminar clientes: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _toggleArchiveStatus(Clientes cliente, bool archive) async {
    try {
      if (archive) {
        await _authService.archiveClientes([cliente.uid], archivedBy: 'Admin');
      } else {
        await _authService.unarchiveClientes([cliente.uid]);
      }
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: archive
            ? 'Cliente arquivado com sucesso.'
            : 'Cliente desarquivado com sucesso.',
        icon: archive ? Icons.archive_outlined : Icons.unarchive_outlined,
        background: Colors.green.shade700,
      );
      await _refreshClientes();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: archive
            ? 'Erro ao arquivar cliente: $e'
            : 'Erro ao desarquivar cliente: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  List<Clientes> _applyFilters(List<Clientes> input) {
    final query = _searchController.text.trim().toLowerCase();

    var list = input.where((cliente) {
      if (_onlyArchived) {
        if (!cliente.isArchived) return false;
      } else {
        if (cliente.isArchived) return false;
      }
      if (query.isEmpty) return true;
      return cliente.nameCliente.toLowerCase().contains(query) ||
          cliente.moradaCliente.toLowerCase().contains(query) ||
          cliente.cidadeCliente.toLowerCase().contains(query) ||
          cliente.codigoPostal.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case _ClientesSort.az:
        list.sort(
          (a, b) => a.nameCliente.toLowerCase().compareTo(
            b.nameCliente.toLowerCase(),
          ),
        );
      case _ClientesSort.hoursDesc:
        list.sort((a, b) {
          final aHours = _currentMonthHoursCache[a.uid] ?? a.hourasCasa;
          final bHours = _currentMonthHoursCache[b.uid] ?? b.hourasCasa;
          return bHours.compareTo(aHours);
        });
    }

    return list;
  }

  Widget _buildStateListMessage({
    required IconData icon,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    EdgeInsetsGeometry? padding,
  }) {
    final bottomInset =
        AppBottomNavBar.barHeight + MediaQuery.of(context).padding.bottom + 16;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.fromLTRB(12, 12, 12, bottomInset),
      children: [
        AppCard(
          child: Column(
            children: [
              Icon(
                icon,
                size: 34,
                color: AppColors.primaryGreen.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Clientes>>(
      future: _clientesFuture,
      builder: (context, snapshot) {
        final listBottomInset =
            AppBottomNavBar.barHeight +
            MediaQuery.of(context).padding.bottom +
            16;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: _buildClientesAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: _buildClientesAppBar(),
            body: RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _refreshClientes,
              child: _buildStateListMessage(
                icon: Icons.error_outline,
                title: 'Erro ao carregar clientes',
                subtitle:
                    'Puxa para atualizar ou tenta novamente pelo botão de atualizar.',
                actionLabel: 'Tentar novamente',
                onAction: _refreshClientes,
              ),
            ),
          );
        }

        final listaClientes = snapshot.data ?? [];
        _preloadCurrentMonthHours(listaClientes);
        final filteredClientes = _applyFilters(listaClientes);

        final nextOpenSessionsKey =
            listaClientes.map((cliente) => cliente.uid).toList()..sort();
        final joinedKey = nextOpenSessionsKey.join('|');
        if (_openSessionsKey != joinedKey) {
          _openSessionsKey = joinedKey;
          Future.microtask(() => _ensureOpenSessions(listaClientes));
        }

        return Scaffold(
          appBar: _buildClientesAppBar(),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
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
                        onTap: () =>
                            setState(() => _showFilters = !_showFilters),
                      ),
                    if (_isPrivileged) const SizedBox(width: 6),
                    if (_isAdmin)
                      _iconBox(
                        icon: Icons.archive_outlined,
                        active: _bulkMode == _ClientesBulkMode.archive,
                        onTap: () => _setBulkMode(_ClientesBulkMode.archive),
                      ),
                    if (_isAdmin) const SizedBox(width: 12),
                    if (_isAdmin)
                      _iconBox(
                        icon: Icons.delete_outline,
                        active: _bulkMode == _ClientesBulkMode.delete,
                        onTap: () => _setBulkMode(_ClientesBulkMode.delete),
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
                        if (_isPrivileged)
                          ChoiceChip(
                            label: Text(_onlyArchived ? 'Arquivados' : 'Todos'),
                            selected: _onlyArchived,
                            onSelected: (_) =>
                                setState(() => _onlyArchived = !_onlyArchived),
                          ),
                        ChoiceChip(
                          label: const Text('A-Z'),
                          selected: _sort == _ClientesSort.az,
                          onSelected: (_) =>
                              setState(() => _sort = _ClientesSort.az),
                        ),
                        ChoiceChip(
                          label: const Text('Mais horas'),
                          selected: _sort == _ClientesSort.hoursDesc,
                          onSelected: (_) =>
                              setState(() => _sort = _ClientesSort.hoursDesc),
                        ),
                      ],
                    ),
                  ),
                if (_isSelecting)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedClientes.length} selecionado(s)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: [
                            if (_bulkMode == _ClientesBulkMode.archive)
                              TextButton.icon(
                                onPressed: _selectedClientes.isEmpty
                                    ? null
                                    : _archiveSelected,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                ),
                                icon: const Icon(Icons.archive_outlined),
                                label: const Text('Arquivar'),
                              ),
                            if (_bulkMode == _ClientesBulkMode.delete)
                              TextButton.icon(
                                onPressed: _selectedClientes.isEmpty
                                    ? null
                                    : _deleteSelected,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Eliminar'),
                              ),
                            TextButton(
                              onPressed: () =>
                                  _setBulkMode(_ClientesBulkMode.none),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredClientes.isEmpty
                      ? RefreshIndicator(
                          color: AppColors.primaryGreen,
                          onRefresh: _refreshClientes,
                          child: _buildStateListMessage(
                            icon: _onlyArchived
                                ? Icons.archive_outlined
                                : Icons.search_off_rounded,
                            title: _onlyArchived
                                ? 'Sem clientes arquivados'
                                : 'Nenhum cliente encontrado',
                            subtitle: _hasActiveSearchOrFilters
                                ? 'Ajusta a pesquisa ou os filtros para veres mais resultados.'
                                : 'Ainda não existem clientes para mostrar.',
                            actionLabel: 'Atualizar',
                            onAction: _refreshClientes,
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryGreen,
                          onRefresh: _refreshClientes,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.only(bottom: listBottomInset),
                            itemCount: filteredClientes.length,
                            itemBuilder: (context, index) {
                              final cliente = filteredClientes[index];
                              final working =
                                  _openSessions[cliente.uid] != null;
                              final selected = _selectedClientes.contains(
                                cliente.uid,
                              );
                              final isArchived = cliente.isArchived;
                              final cachedHours =
                                  _currentMonthHoursCache[cliente.uid] ??
                                  cliente.hourasCasa;

                              return AppCard(
                                color: isArchived
                                    ? AppColors.primaryGreen.withValues(
                                        alpha: .5,
                                      )
                                    : Colors.white,
                                borderSide: selected
                                    ? const BorderSide(
                                        color: AppColors.primaryGreen,
                                        width: 1.5,
                                      )
                                    : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (_isSelecting) {
                                          _toggleSelected(cliente.uid);
                                          return;
                                        }

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (ctx) => Clientsdetails(
                                              cliente: cliente,
                                              onSessionClosed: () {
                                                if (!mounted) return;
                                                setState(() {
                                                  _openSessions[cliente.uid] =
                                                      null;
                                                });
                                                _updateClienteHours(cliente);
                                              },
                                            ),
                                          ),
                                        ).then((updated) {
                                          if (updated == true) {
                                            _refreshClientes();
                                          }
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected
                                                ? Icons.check_circle
                                                : Icons.people,
                                            color: selected
                                                ? AppColors.primaryGreen
                                                : (isArchived
                                                      ? Colors.white
                                                      : Colors.black87),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cliente.nameCliente,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 20,
                                                    color: isArchived
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  [
                                                        cliente.moradaCliente
                                                            .trim(),
                                                        cliente.cidadeCliente
                                                            .trim(),
                                                      ]
                                                      .where(
                                                        (e) => e.isNotEmpty,
                                                      )
                                                      .join(' • '),
                                                  style: TextStyle(
                                                    color: isArchived
                                                        ? Colors.white
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                                if (cliente.isArchived) ...[
                                                  const SizedBox(height: 4),
                                                  InkWell(
                                                    onTap: _isAdmin
                                                        ? () =>
                                                              _toggleArchiveStatus(
                                                                cliente,
                                                                false,
                                                              )
                                                        : null,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: .16,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: .3,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .unarchive_outlined,
                                                            size: 14,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              '${cliente.archivedBy == null ? 'Arquivado' : 'Arquivado por ${cliente.archivedBy}'} · toque para desarquivar',
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${cachedHours.toStringAsFixed(1)}h',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: isArchived
                                                      ? Colors.white
                                                      : const Color.fromARGB(
                                                          255,
                                                          4,
                                                          76,
                                                          32,
                                                        ),
                                                ),
                                              ),
                                              if (!_isSelecting) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.chevron_right,
                                                  color: isArchived
                                                      ? Colors.white
                                                      : Colors.grey,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelecting &&
                                        !_onlyArchived &&
                                        !_isHr) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: AppButton(
                                              text: 'Começar',
                                              color: const Color.fromARGB(
                                                255,
                                                4,
                                                76,
                                                32,
                                              ),
                                              enabled:
                                                  !working &&
                                                  !_hasAnyOpenSession,
                                              onPressed: () async {
                                                try {
                                                  final session =
                                                      await _workSessionService
                                                          .startSession(
                                                            clienteId:
                                                                cliente.uid,
                                                            clienteName: cliente
                                                                .nameCliente,
                                                          );

                                                  setState(() {
                                                    _openSessions[cliente.uid] =
                                                        session;
                                                  });

                                                  AppSnackBar.show(
                                                    context,
                                                    message:
                                                        'Começaste às ${TimeOfDay.now().format(context)}!',
                                                    icon: Icons.play_arrow,
                                                    background:
                                                        const Color.fromARGB(
                                                          255,
                                                          4,
                                                          76,
                                                          32,
                                                        ),
                                                  );
                                                } catch (e) {
                                                  AppSnackBar.show(
                                                    context,
                                                    message:
                                                        'Não foi possivel iniciar: $e',
                                                    icon: Icons.error,
                                                    background:
                                                        Colors.red.shade700,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: AppButton(
                                              text: 'Terminar',
                                              outline: true,
                                              color: const Color.fromARGB(
                                                255,
                                                4,
                                                76,
                                                32,
                                              ),
                                              enabled: working,
                                              onPressed: () async {
                                                try {
                                                  final session =
                                                      _openSessions[cliente
                                                          .uid];

                                                  if (session == null) {
                                                    throw Exception(
                                                      'Sessão não encontrada localmente.',
                                                    );
                                                  }

                                                  final total =
                                                      await _workSessionService
                                                          .finishSessionById(
                                                            clienteId:
                                                                cliente.uid,
                                                            sessionId:
                                                                session.id,
                                                            startTime: session
                                                                .startTime,
                                                          );

                                                  final displayTotal = _isAdmin
                                                      ? total
                                                      : await _workSessionService
                                                            .calculateMonthlyTotalForCurrentUser(
                                                              clienteId:
                                                                  cliente.uid,
                                                              referenceDate:
                                                                  session
                                                                      .startTime,
                                                            );

                                                  setState(() {
                                                    _openSessions[cliente.uid] =
                                                        null;
                                                    cliente.hourasCasa =
                                                        displayTotal;
                                                    _currentMonthHoursCache[cliente
                                                            .uid] =
                                                        displayTotal;
                                                  });

                                                  AppSnackBar.show(
                                                    context,
                                                    message:
                                                        'Terminaste! Total do mês: ${displayTotal.toStringAsFixed(2)}h',
                                                    icon: Icons.square,
                                                    background:
                                                        const Color.fromARGB(
                                                          255,
                                                          188,
                                                          82,
                                                          82,
                                                        ),
                                                  );

                                                  await _ensureOpenSessions([
                                                    cliente,
                                                  ]);
                                                } catch (e) {
                                                  AppSnackBar.show(
                                                    context,
                                                    message:
                                                        'Não foi possivel terminar: $e',
                                                    icon: Icons.error,
                                                    background:
                                                        Colors.red.shade700,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
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
}
