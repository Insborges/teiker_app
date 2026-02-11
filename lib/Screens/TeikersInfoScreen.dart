import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/TeikersDetais.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/app_search_bar.dart';
import 'package:teiker_app/backend/TeikerService.dart';
import 'package:teiker_app/work_sessions/application/monthly_teiker_hours_service.dart';
import '../models/Teikers.dart';
import '../Widgets/AppBar.dart';

class TeikersInfoScreen extends StatefulWidget {
  const TeikersInfoScreen({super.key});

  @override
  State<TeikersInfoScreen> createState() => _TeikersInfoScreenState();
}

class _TeikersInfoScreenState extends State<TeikersInfoScreen> {
  final Map<String, Future<Map<String, double>>> _hoursCache = {};
  final MonthlyTeikerHoursService _monthlyHoursService =
      MonthlyTeikerHoursService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Teiker>> _teikersStream;

  @override
  void initState() {
    super.initState();
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

  Widget _teikerCard(Teiker teiker) {
    final primary = teiker.corIdentificadora;
    final consultasCount = teiker.consultas.length;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TeikersDetails(teiker: teiker)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                      if (teiker.feriasInicio != null &&
                          teiker.feriasFim != null)
                        _infoChip(
                          icon: Icons.beach_access,
                          color: Colors.orange.shade700,
                          text:
                              'Férias: ${teiker.feriasInicio!.day}/${teiker.feriasInicio!.month} - ${teiker.feriasFim!.day}/${teiker.feriasFim!.month}',
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
            appBar: buildAppBar("As Teikers"),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: buildAppBar("As Teikers"),
            body: const Center(child: Text("Erro ao carregar teikers")),
          );
        }
        final teikers = snapshot.data ?? [];
        final query = _searchController.text.trim().toLowerCase();
        final filteredTeikers = query.isEmpty
            ? teikers
            : teikers.where((teiker) {
                return teiker.nameTeiker.toLowerCase().contains(query);
              }).toList();

        return Scaffold(
          appBar: buildAppBar("As Teikers"),
          body: Column(
            children: [
              AppSearchBar(
                controller: _searchController,
                hintText: 'Pesquisar teikers',
                onChanged: (_) => setState(() {}),
              ),
              Expanded(
                child: filteredTeikers.isEmpty
                    ? const Center(child: Text("Nenhuma teiker encontrada"))
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
