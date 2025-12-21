import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/models/Clientes.dart';

class TeikerHorasScreen extends StatefulWidget {
  const TeikerHorasScreen({super.key});

  @override
  State<TeikerHorasScreen> createState() => _TeikerHorasScreenState();
}

class _TeikerHorasScreenState extends State<TeikerHorasScreen> {
  final Color _primary = const Color.fromARGB(255, 4, 76, 32);
  bool _loading = true;
  bool _collapsed = false;
  Map<DateTime, Map<String, double>> _hoursByDay = {};
  double _totalMes = 0;
  String _monthLabel = '';

  @override
  void initState() {
    super.initState();
    _loadHoras();
  }

  Future<void> _loadHoras() async {
    final user = FirebaseService().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final clientes = await AuthService().getClientes();
    final Map<String, Clientes> clientesMap = {
      for (final c in clientes) c.uid: c
    };

    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final proximoMes = DateTime(now.year, now.month + 1, 1);
    _monthLabel = DateFormat('MMMM yyyy', 'pt_PT').format(inicioMes);

    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: user.uid)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(proximoMes))
          .get();
      docs = snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: user.uid)
          .get();

      docs = snapshot.docs.where((doc) {
        final start = (doc.data()['startTime'] as Timestamp?)?.toDate();
        return start != null &&
            !start.isBefore(inicioMes) &&
            start.isBefore(proximoMes);
      });
    }

    final Map<DateTime, Map<String, double>> grouped = {};
    double total = 0;

    for (final doc in docs) {
      final data = doc.data();
      final clienteId = data['clienteId'] as String?;
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();
      double? duration = (data['durationHours'] as num?)?.toDouble();
      duration ??= (start != null && end != null)
          ? end.difference(start).inMinutes / 60.0
          : null;

      if (duration == null || start == null) continue;
      final double dur = duration;

      final key = DateTime(start.year, start.month, start.day);
      final clienteName = clienteId != null
          ? clientesMap[clienteId]?.nameCliente ?? clienteId
          : "Cliente";

      grouped.putIfAbsent(key, () => {});
      grouped[key]!.update(
        clienteName,
        (v) => v + dur,
        ifAbsent: () => dur,
      );

      total += dur;
    }

    if (!mounted) return;
    setState(() {
      _hoursByDay = grouped;
      _totalMes = total;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = _totalMes >= 0;

    return Scaffold(
      appBar: buildAppBar("Horas do mês", seta: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryCard(isPositive),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!_collapsed)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("Fechar mês"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: BorderSide(color: _primary),
                          ),
                          onPressed: () => setState(() => _collapsed = true),
                        ),
                      if (_collapsed)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.visibility),
                          label: const Text("Ver detalhes"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: BorderSide(color: _primary),
                          ),
                          onPressed: () => setState(() => _collapsed = false),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_collapsed)
                    Expanded(
                      child: _hoursByDay.isEmpty
                          ? Center(
                              child: Text(
                                "Ainda sem registos este mês.",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView(
                              children: (_hoursByDay.entries.toList()
                                    ..sort(
                                      (a, b) => b.key.compareTo(a.key),
                                    ))
                                  .map((e) => _dayCard(e.key, e.value))
                                  .toList(),
                            ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(bool isPositive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total: ${_totalMes.toStringAsFixed(1)} h",
                  style: TextStyle(
                    color:
                        isPositive ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(DateTime day, Map<String, double> clientes) {
    final totalDia =
        clientes.values.fold<double>(0, (previous, element) => previous + element);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMMM', 'pt_PT').format(day),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                "${totalDia.toStringAsFixed(1)} h",
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: clientes.entries.map((entry) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_work_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${entry.value.toStringAsFixed(1)} h",
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
