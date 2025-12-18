import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/DatePickerBottomSheet.dart';
import '../../models/Teikers.dart';
import '../../Widgets/AppBar.dart';
import '../../Widgets/AppButton.dart';
import '../../Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/TeikerService.dart';

class TeikersDetails extends StatefulWidget {
  final Teiker teiker;
  const TeikersDetails({super.key, required this.teiker});

  @override
  State<TeikersDetails> createState() => _TeikersDetailsState();
}

class _TeikersDetailsState extends State<TeikersDetails> {
  late TextEditingController _emailController;
  late TextEditingController _telemovelController;
  DateTime? _feriasInicio;
  DateTime? _feriasFim;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.teiker.email);
    _telemovelController = TextEditingController(
      text: widget.teiker.telemovel.toString(),
    );

    _feriasInicio = widget.teiker.feriasInicio;
    _feriasFim = widget.teiker.feriasFim;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telemovelController.dispose();
    super.dispose();
  }

  void _guardarAlteracoes() async {
    final newTelemovel = int.tryParse(_telemovelController.text.trim());

    if (newTelemovel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos corretamente.")),
      );
      return;
    }

    try {
      final updatedTeiker = widget.teiker.copyWith(telemovel: newTelemovel);

      await TeikerService().updateTeiker(updatedTeiker);

      AppSnackBar.show(
        context,
        message: "Atualizações realizadas com sucesso!",
        icon: Icons.check_box_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      AppSnackBar.show(
        context,
        message: "Erro ao guardar alterações: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _adicionarFerias() async {
    final selectedDates = await DatePickerBottomSheet.show(
      context,
      initialStart: _feriasInicio,
      initialEnd: _feriasFim,
    );

    if (selectedDates == null || selectedDates.length != 2) return;

    setState(() {
      _feriasInicio = selectedDates[0];
      _feriasFim = selectedDates[1];
    });

    await TeikerService().updateFerias(
      widget.teiker.uid,
      _feriasInicio,
      _feriasFim,
    );

    AppSnackBar.show(
      context,
      message: "Férias atualizadas!",
      icon: Icons.check,
      background: Colors.green.shade700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final teiker = widget.teiker;

    return Scaffold(
      appBar: buildAppBar(teiker.nameTeiker, seta: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Pessoal + Botão Guardar
            _buildSectionCard(
              title: "Informações Pessoais",
              children: [
                _buildInputField(
                  "Telemóvel",
                  _telemovelController,
                  Icons.phone,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.save,
                      color: Color.fromARGB(255, 4, 76, 32),
                    ),
                    label: const Text(
                      "Guardar Alterações",
                      style: TextStyle(
                        color: Color.fromARGB(255, 4, 76, 32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 4, 76, 32),
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                    ),
                    onPressed: _guardarAlteracoes,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Horas (apenas texto)
            _buildSectionCard(
              title: "Horas",
              children: [
                _buildInfoRow(
                  "Esta semana (h):",
                  "${(teiker.horas * 0.3).toStringAsFixed(1)}h",
                ),
                _buildInfoRow(
                  "Este mês (h):",
                  "${teiker.horas.toStringAsFixed(1)}h",
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Férias
            _buildSectionCard(
              title: "Férias",
              children: [
                if (_feriasInicio != null && _feriasFim != null)
                  Text(
                    "De ${_feriasInicio!.day}/${_feriasInicio!.month} "
                    "até ${_feriasFim!.day}/${_feriasFim!.month}",
                    style: const TextStyle(
                      color: Color.fromARGB(255, 4, 76, 32),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const Text(
                    "Ainda sem férias registadas.",
                    style: TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 12),
                AppButton(
                  text: "Adicionar férias",
                  color: const Color.fromARGB(255, 4, 76, 32),
                  icon: Icons.beach_access,
                  onPressed: _adicionarFerias,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Componentes auxiliares
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color.fromARGB(255, 4, 76, 32),
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color.fromARGB(255, 4, 76, 32)),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 4, 76, 32),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 4, 76, 32),
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 4, 76, 32),
            ),
          ),
        ],
      ),
    );
  }
}
