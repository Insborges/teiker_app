import 'package:flutter/material.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/TeikersDetais.dart';
import 'package:teiker_app/backend/TeikerService.dart';
import '../models/Teikers.dart';
import '../Widgets/AppBar.dart';
import '../Widgets/AppCard.dart';

class TeikersInfoScreen extends StatefulWidget {
  const TeikersInfoScreen({super.key});

  @override
  State<TeikersInfoScreen> createState() => _TeikersInfoScreenState();
}

class _TeikersInfoScreenState extends State<TeikersInfoScreen> {
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
              return AppCard(
                icon: Icons.person,
                iconColor: teiker.corIdentificadora,
                title: teiker.nameTeiker,
                subtitleWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (teiker.feriasInicio != null && teiker.feriasFim != null)
                      Text(
                        'Férias: ${teiker.feriasInicio!.day}/${teiker.feriasInicio!.month} até ${teiker.feriasFim!.day}/${teiker.feriasFim!.month}',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 4, 76, 32),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),

                trailing: Text(
                  '${teiker.horas} horas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: teiker.horas >= 0
                        ? const Color.fromARGB(255, 4, 76, 32)
                        : const Color.fromARGB(255, 188, 82, 82),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeikersDetails(teiker: teiker),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
