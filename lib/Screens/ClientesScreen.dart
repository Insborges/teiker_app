import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/ClientsDetails.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppCard.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import '../models/Clientes.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  // mapa para controlar estado dos botões
  final Map<String, bool> isWorking = {};
  final Map<String, String> _openSessionIds = {};
  final WorkSessionService _workSessionService = WorkSessionService();

  @override
  Widget build(BuildContext context) {
    Future<List<Clientes>> loadClientes() async {
      return await AuthService().getClientes();
    }

    return FutureBuilder<List<Clientes>>(
      future: loadClientes(),
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

        final listaClientes = snapshot.data!;

        return Scaffold(
          appBar: buildAppBar("Os Clientes Teiker"),
          body: ListView.builder(
            itemCount: listaClientes.length,
            itemBuilder: (context, index) {
              final cliente = listaClientes[index];
              final working = isWorking[cliente.uid] ?? false;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => Clientsdetails(cliente: cliente),
                          ),
                        ).then((updated) {
                          if (updated == true) {
                            setState(() {});
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
                                final sessionId = await _workSessionService
                                    .startSession(clienteId: cliente.uid);

                                setState(() {
                                  isWorking[cliente.uid] = true;
                                  _openSessionIds[cliente.uid] = sessionId;
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
                                final total = await _workSessionService
                                    .finishSession(
                                      clienteId: cliente.uid,
                                      sessionId: _openSessionIds[cliente.uid],
                                    );

                                setState(() {
                                  isWorking[cliente.uid] = false;
                                  _openSessionIds.remove(cliente.uid);
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

                                setState(() {});
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
