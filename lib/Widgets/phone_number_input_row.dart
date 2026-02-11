import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/models/phone_country.dart';

class PhoneNumberInputRow extends StatelessWidget {
  const PhoneNumberInputRow({
    super.key,
    required this.controller,
    required this.countryIso,
    required this.onCountryChanged,
    required this.primaryColor,
    this.label = 'Telemóvel',
    this.readOnlyNumber = false,
    this.allowCountryPicker = true,
    this.fillColor = Colors.white,
    this.borderColor,
  });

  final TextEditingController controller;
  final String countryIso;
  final ValueChanged<String> onCountryChanged;
  final Color primaryColor;
  final String label;
  final bool readOnlyNumber;
  final bool allowCountryPicker;
  final Color fillColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final country = phoneCountryByIso(countryIso);
    final effectiveBorder = borderColor ?? primaryColor.withValues(alpha: .2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: _CountryPickerField(
            country: country,
            primaryColor: primaryColor,
            borderColor: effectiveBorder,
            fillColor: fillColor,
            enabled: allowCountryPicker,
            onTap: () async {
              if (!allowCountryPicker) return;
              final picked = await showPhoneCountryPicker(
                context,
                initialIso: country.isoCode,
                primaryColor: primaryColor,
              );
              if (picked != null) {
                onCountryChanged(picked.isoCode);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppTextField(
            label: label,
            controller: controller,
            keyboard: TextInputType.phone,
            readOnly: readOnlyNumber,
            focusColor: primaryColor,
            fillColor: fillColor,
            borderColor: effectiveBorder,
            prefixIcon: Icons.phone_outlined,
          ),
        ),
      ],
    );
  }
}

class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({
    required this.country,
    required this.primaryColor,
    required this.borderColor,
    required this.fillColor,
    required this.enabled,
    required this.onTap,
  });

  final PhoneCountry country;
  final Color primaryColor;
  final Color borderColor;
  final Color fillColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 54,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(country.flagEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              country.dialCode,
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.expand_more_rounded,
            color: enabled ? primaryColor : Colors.grey.shade500,
            size: 20,
          ),
        ],
      ),
    );

    if (!enabled) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

Future<PhoneCountry?> showPhoneCountryPicker(
  BuildContext context, {
  required String initialIso,
  required Color primaryColor,
}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: .78,
      child: _PhoneCountryPickerSheet(
        initialIso: initialIso,
        primaryColor: primaryColor,
      ),
    ),
  );
}

class _PhoneCountryPickerSheet extends StatefulWidget {
  const _PhoneCountryPickerSheet({
    required this.initialIso,
    required this.primaryColor,
  });

  final String initialIso;
  final Color primaryColor;

  @override
  State<_PhoneCountryPickerSheet> createState() =>
      _PhoneCountryPickerSheetState();
}

class _PhoneCountryPickerSheetState extends State<_PhoneCountryPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final items = phoneCountries.where((country) {
      if (query.isEmpty) return true;
      return country.name.toLowerCase().contains(query) ||
          country.dialCode.contains(query) ||
          country.isoCode.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Selecionar país',
              style: TextStyle(
                color: widget.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Pesquisar país',
              controller: _searchCtrl,
              focusColor: widget.primaryColor,
              prefixIcon: Icons.search,
              fillColor: Colors.grey.shade100,
              borderColor: widget.primaryColor.withValues(alpha: .2),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: widget.primaryColor.withValues(alpha: .12),
                ),
                itemBuilder: (context, index) {
                  final country = items[index];
                  final selected = country.isoCode == widget.initialIso;

                  return ListTile(
                    dense: true,
                    onTap: () => Navigator.pop(context, country),
                    leading: Text(
                      country.flagEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      country.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(country.dialCode),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: widget.primaryColor)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
