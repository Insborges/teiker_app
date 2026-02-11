import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';

class TeikerPersonalInfoContent extends StatelessWidget {
  const TeikerPersonalInfoContent({
    super.key,
    required this.telemovelController,
    required this.primaryColor,
    required this.onSave,
  });

  final TextEditingController telemovelController;
  final Color primaryColor;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Telemovel',
          controller: telemovelController,
          prefixIcon: Icons.phone,
          focusColor: primaryColor,
          fillColor: Colors.grey.shade100,
          borderColor: primaryColor,
          borderRadius: 10,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: Icon(Icons.save, color: primaryColor),
            label: Text(
              'Guardar Alteracoes',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor, width: 1.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
            onPressed: onSave,
          ),
        ),
      ],
    );
  }
}
