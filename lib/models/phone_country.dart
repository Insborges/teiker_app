class PhoneCountry {
  final String isoCode;
  final String dialCode;
  final String name;

  const PhoneCountry({
    required this.isoCode,
    required this.dialCode,
    required this.name,
  });

  String get flagEmoji {
    final code = isoCode.toUpperCase();
    if (code.length != 2) return '🌐';
    final first = code.codeUnitAt(0) - 65 + 0x1F1E6;
    final second = code.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }
}

const List<PhoneCountry> phoneCountries = [
  PhoneCountry(isoCode: 'PT', dialCode: '+351', name: 'Portugal'),
  PhoneCountry(isoCode: 'CH', dialCode: '+41', name: 'Suíça'),
  PhoneCountry(isoCode: 'ES', dialCode: '+34', name: 'Espanha'),
  PhoneCountry(isoCode: 'FR', dialCode: '+33', name: 'França'),
  PhoneCountry(isoCode: 'DE', dialCode: '+49', name: 'Alemanha'),
  PhoneCountry(isoCode: 'IT', dialCode: '+39', name: 'Itália'),
  PhoneCountry(isoCode: 'GB', dialCode: '+44', name: 'Reino Unido'),
  PhoneCountry(isoCode: 'IE', dialCode: '+353', name: 'Irlanda'),
  PhoneCountry(isoCode: 'BE', dialCode: '+32', name: 'Bélgica'),
  PhoneCountry(isoCode: 'NL', dialCode: '+31', name: 'Países Baixos'),
  PhoneCountry(isoCode: 'LU', dialCode: '+352', name: 'Luxemburgo'),
  PhoneCountry(isoCode: 'AT', dialCode: '+43', name: 'Áustria'),
  PhoneCountry(isoCode: 'BR', dialCode: '+55', name: 'Brasil'),
  PhoneCountry(isoCode: 'US', dialCode: '+1', name: 'Estados Unidos'),
  PhoneCountry(isoCode: 'CA', dialCode: '+1', name: 'Canadá'),
];

PhoneCountry phoneCountryByIso(String? isoCode) {
  final iso = (isoCode ?? 'PT').trim().toUpperCase();
  for (final country in phoneCountries) {
    if (country.isoCode == iso) return country;
  }
  return phoneCountries.first;
}

String formatPhoneWithCountry({
  required String phoneDigits,
  required String countryIso,
}) {
  final country = phoneCountryByIso(countryIso);
  final number = phoneDigits.trim();
  if (number.isEmpty) {
    return '${country.flagEmoji} ${country.dialCode}';
  }
  return '${country.flagEmoji} ${country.dialCode} $number';
}
