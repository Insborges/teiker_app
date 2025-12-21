import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/TeikersDetais.dart';
import 'package:teiker_app/backend/TeikerService.dart';
import 'package:teiker_app/backend/auth_service.dart';
import '../models/Clientes.dart';
import '../models/Teikers.dart';
import '../Widgets/AppBar.dart';

class TeikersInfoScreen extends StatefulWidget {
  const TeikersInfoScreen({super.key});

  @override
  State<TeikersInfoScreen> createState() => _TeikersInfoScreenState();
}

class _TeikersInfoScreenState extends State<TeikersInfoScreen> {
  final Map<String, Future<Map<String, double>>> _hoursCache = {};
  Map<String, Clientes> _clientes = {};

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final all = await AuthService().getClientes();
    if (!mounted) return;
    setState(() {
      _clientes = {for (final c in all) c.uid: c};
    });
  }

  Future<Map<String, double>> _fetchTeikerHours(String teikerId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
      docs = snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      // Fallback without composite index: single-field query + local filter.
      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .get();
      docs = snapshot.docs.where((doc) {
        final start = (doc.data()['startTime'] as Timestamp?)?.toDate();
        return start != null &&
            !start.isBefore(monthStart) &&
            start.isBefore(nextMonth);
      });
    }

    final Map<String, double> hoursByCliente = {};

    for (final doc in docs) {
      final data = doc.data();
      final clienteId = data['clienteId'] as String?;
      if (clienteId == null) continue;

      double? duration = (data['durationHours'] as num?)?.toDouble();
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();

      duration ??= (start != null && end != null)
          ? end.difference(start).inMinutes / 60.0
          : null;

      if (duration != null) {
        final dur = duration;
        hoursByCliente.update(clienteId, (v) => v + dur, ifAbsent: () => dur);
      }
    }

    return hoursByCliente;
  }

  Future<Map<String, double>> _getTeikerHours(String teikerId) {
    return _hoursCache.putIfAbsent(teikerId, () => _fetchTeikerHours(teikerId));
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
              color: Colors.black.withOpacity(0.05),
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
                          color: primary.withOpacity(.08),
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
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }

                            final data = hoursSnap.data ?? {};
                            final total =
                                data.values.fold<double>(0, (a, b) => a + b);

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
                        text: '$consultasCount consulta${consultasCount == 1 ? '' : 's'}',
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
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("As Teikers"),
      body: StreamBuilder<List<Teiker>>(
        stream: TeikerService().streamTeikers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar teikers"));
          }
          final teikers = snapshot.data ?? [];

          return ListView.builder(
            itemCount: teikers.length,
            itemBuilder: (context, index) {
              final teiker = teikers[index];
              return _teikerCard(teiker);
            },
          );
        },
      ),
    );
  }
}
