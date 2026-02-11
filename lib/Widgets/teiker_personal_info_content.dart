import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/phone_number_input_row.dart';

class TeikerPersonalInfoContent extends StatelessWidget {
  const TeikerPersonalInfoContent({
    super.key,
    required this.birthDate,
    required this.telemovelController,
    required this.phoneCountryIso,
    required this.onPhoneCountryChanged,
    required this.primaryColor,
  });

  final DateTime? birthDate;
  final TextEditingController telemovelController;
  final String phoneCountryIso;
  final ValueChanged<String> onPhoneCountryChanged;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final birthDateLabel = birthDate == null
        ? 'Sem data definida'
        : DateFormat('dd/MM/yyyy', 'pt_PT').format(birthDate!);
    final neutralBorder = primaryColor.withValues(alpha: .85);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: neutralBorder, width: 1.25),
          ),
          child: Row(
            children: [
              Icon(Icons.cake_outlined, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data de nascimento',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      birthDateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PhoneNumberInputRow(
          controller: telemovelController,
          countryIso: phoneCountryIso,
          onCountryChanged: onPhoneCountryChanged,
          primaryColor: primaryColor,
          label: 'Telemóvel',
          fillColor: Colors.grey.shade100,
          borderColor: primaryColor,
        ),
      ],
    );
  }
}
