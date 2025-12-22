import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/ClientsDetails.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppCard.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/work_sessions/domain/work_session.dart';
import '../models/Clientes.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  // mapa para controlar estado dos botões

  final Map<String, WorkSession?> _openSessions = {};
  final WorkSessionService _workSessionService = WorkSessionService();
  late Future<List<Clientes>> _clientesFuture;
  late final bool _isAdmin;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _isAdmin = AuthService().isCurrentUserAdmin;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _clientesFuture = AuthService().getClientes();
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

  Future<void> _refreshClientes() async {
    if (!mounted) return;

    setState(() {
      _clientesFuture = AuthService().getClientes();
      _openSessions.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Clientes>>(
      future: _clientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: buildAppBar("Os Clientes Teiker"),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar: buildAppBar("Os Clientes Teiker"),
            body: const Center(child: Text("Sem clientes ainda")),
          );
        }

        var listaClientes = snapshot.data!;

        if (!_isAdmin && _currentUserId != null) {
          listaClientes = listaClientes
              .where((c) => c.teikersIds.contains(_currentUserId))
              .toList();
        }

        _ensureOpenSessions(listaClientes);

        return Scaffold(
          appBar: buildAppBar("Os Clientes Teiker"),
          body: ListView.builder(
            itemCount: listaClientes.length,
            itemBuilder: (context, index) {
              final cliente = listaClientes[index];
              final bool working = _openSessions[cliente.uid] != null;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => Clientsdetails(
                              cliente: cliente,
                              onSessionClosed: () {
                                if (!mounted) return;
                                setState(() {
                                  _openSessions[cliente.uid] = null;
                                });
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
                          const Icon(Icons.people),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cliente.nameCliente,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cliente.moradaCliente,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${cliente.hourasCasa.toStringAsFixed(1)} horas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: cliente.hourasCasa >= 40
                                  ? const Color.fromARGB(255, 4, 76, 32)
                                  : const Color.fromARGB(255, 188, 82, 82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: "Começar",
                            color: const Color.fromARGB(255, 4, 76, 32),
                            enabled: !working,
                            onPressed: () async {
                              try {
                                final session = await _workSessionService
                                    .startSession(
                                      clienteId: cliente.uid,
                                      clienteName: cliente.nameCliente,
                                    );

                                setState(() {
                                  _openSessions[cliente.uid] = session;
                                });

                                AppSnackBar.show(
                                  context,
                                  message:
                                      "Começaste às ${TimeOfDay.now().format(context)}!",
                                  icon: Icons.play_arrow,
                                  background: const Color.fromARGB(
                                    255,
                                    4,
                                    76,
                                    32,
                                  ),
                                );
                              } catch (e) {
                                AppSnackBar.show(
                                  context,
                                  message: "Não foi possivel iniciar: $e",
                                  icon: Icons.error,
                                  background: Colors.red.shade700,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            text: "Terminar",
                            outline: true,
                            color: const Color.fromARGB(255, 4, 76, 32),
                            enabled: working,
                            onPressed: () async {
                              try {
                                final session = _openSessions[cliente.uid];

                                if (session == null) {
                                  throw Exception(
                                    'Sessão não encontrada localmente.',
                                  );
                                }

                                final total = await _workSessionService
                                    .finishSessionById(
                                      clienteId: cliente.uid,
                                      sessionId: session.id,
                                      startTime: session.startTime,
                                    );

                                setState(() {
                                  _openSessions[cliente.uid] = null;
                                  cliente.hourasCasa = total;
                                });

                                AppSnackBar.show(
                                  context,
                                  message:
                                      "Terminaste! Total do mês: ${total.toStringAsFixed(2)}h",
                                  icon: Icons.square,
                                  background: const Color.fromARGB(
                                    255,
                                    188,
                                    82,
                                    82,
                                  ),
                                );

                                await _ensureOpenSessions([cliente]);
                              } catch (e) {
                                AppSnackBar.show(
                                  context,
                                  message: "Não foi possivel terminar: $e",
                                  icon: Icons.error,
                                  background: Colors.red.shade700,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
