import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.addressLine,
    required this.city,
    required this.postalCode,
    required this.label,
    this.countryCode = '',
    this.country = '',
  });

  final String addressLine;
  final String city;
  final String postalCode;
  final String label;
  final String countryCode;
  final String country;
}

abstract class AddressAutocompleteProvider {
  const AddressAutocompleteProvider();

  Future<List<AddressSuggestion>> search(
    String query, {
    List<String>? countryBias,
    int limit = 6,
  });
}

class AddressAutocompleteService {
  const AddressAutocompleteService({AddressAutocompleteProvider? provider})
    : _provider = provider ?? const NominatimAddressAutocompleteProvider();

  final AddressAutocompleteProvider _provider;

  Future<List<AddressSuggestion>> search(
    String query, {
    List<String>? countryBias,
    int limit = 6,
  }) {
    return _provider.search(query, countryBias: countryBias, limit: limit);
  }
}

class NominatimAddressAutocompleteProvider extends AddressAutocompleteProvider {
  const NominatimAddressAutocompleteProvider();

  static const String _host = 'nominatim.openstreetmap.org';

  @override
  Future<List<AddressSuggestion>> search(
    String query, {
    List<String>? countryBias,
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const <AddressSuggestion>[];

    final safeLimit = limit.clamp(1, 10);
    final bias = _normalizeCountryBias(countryBias);
    final uri = Uri.https(_host, '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$safeLimit',
      // Global por defeito: não filtramos por país.
      // O countryBias (quando fornecido) é usado para reordenar resultados.
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'TeikerApp/1.0 (info@teiker.ch)',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <AddressSuggestion>[];
      }

      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AddressSuggestion>[];

      final seen = <String>{};
      final suggestions = <AddressSuggestion>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final suggestion = _parseSuggestion(item);
        if (suggestion == null) continue;

        final key =
            '${suggestion.addressLine.toLowerCase()}|${suggestion.postalCode.toLowerCase()}|${suggestion.city.toLowerCase()}|${suggestion.countryCode.toLowerCase()}';
        if (!seen.add(key)) continue;
        suggestions.add(suggestion);
      }

      if (bias.isEmpty || suggestions.length <= 1) {
        return suggestions;
      }

      return _sortByCountryBias(suggestions, bias);
    } catch (e) {
      debugPrint('Falha ao procurar moradas: $e');
      return const <AddressSuggestion>[];
    } finally {
      client.close(force: true);
    }
  }

  AddressSuggestion? _parseSuggestion(Map item) {
    final address = item['address'];
    final addressMap = address is Map ? address : const <String, dynamic>{};

    final displayName = _stringValue(item['display_name']);
    final road = _firstNonEmpty([
      addressMap['road'],
      addressMap['pedestrian'],
      addressMap['footway'],
      addressMap['residential'],
      addressMap['path'],
      addressMap['street'],
      addressMap['square'],
      addressMap['place'],
      addressMap['neighbourhood'],
      addressMap['suburb'],
    ]);
    final houseNumber = _firstNonEmpty([
      addressMap['house_number'],
      addressMap['house_name'],
      addressMap['building'],
    ]);
    final city = _extractLocality(addressMap);
    final postalCode = _normalizePostalCode(
      _stringValue(addressMap['postcode']),
    );
    final countryCode = _stringValue(addressMap['country_code']).toUpperCase();
    final country = _stringValue(addressMap['country']);

    final addressLine = _buildAddressLine(
      road: road,
      houseNumber: houseNumber,
      fallbackDisplayName: displayName,
    );
    if (addressLine.isEmpty) return null;

    final label = _buildLabel(
      addressLine: addressLine,
      postalCode: postalCode,
      city: city,
      country: country,
      fallbackDisplayName: displayName,
    );

    return AddressSuggestion(
      addressLine: addressLine,
      city: city,
      postalCode: postalCode,
      label: label,
      countryCode: countryCode,
      country: country,
    );
  }

  List<AddressSuggestion> _sortByCountryBias(
    List<AddressSuggestion> suggestions,
    List<String> bias,
  ) {
    final withIndex = suggestions.indexed.toList();
    withIndex.sort((a, b) {
      final aRank = _biasRank(a.$2.countryCode, bias);
      final bRank = _biasRank(b.$2.countryCode, bias);
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.$1.compareTo(b.$1);
    });
    return withIndex.map((entry) => entry.$2).toList(growable: false);
  }

  int _biasRank(String countryCode, List<String> bias) {
    if (countryCode.trim().isEmpty) return bias.length + 1;
    final index = bias.indexOf(countryCode.trim().toUpperCase());
    return index < 0 ? bias.length : index;
  }

  List<String> _normalizeCountryBias(List<String>? countryBias) {
    if (countryBias == null || countryBias.isEmpty) return const <String>[];
    final seen = <String>{};
    final result = <String>[];
    for (final raw in countryBias) {
      final code = raw.trim().toUpperCase();
      if (code.length < 2 || code.length > 3) continue;
      if (seen.add(code)) result.add(code);
    }
    return result;
  }

  String _extractLocality(Map addressMap) {
    return _firstNonEmpty([
      addressMap['city'],
      addressMap['town'],
      addressMap['village'],
      addressMap['municipality'],
      addressMap['suburb'],
      addressMap['hamlet'],
      addressMap['borough'],
      addressMap['city_district'],
      addressMap['district'],
      addressMap['quarter'],
      addressMap['county'],
      addressMap['state_district'],
    ]);
  }

  String _buildAddressLine({
    required String road,
    required String houseNumber,
    required String fallbackDisplayName,
  }) {
    final parts = <String>[
      if (road.isNotEmpty) road,
      if (houseNumber.isNotEmpty && !road.contains(houseNumber)) houseNumber,
    ];
    if (parts.isNotEmpty) return parts.join(' ');

    final fallback = fallbackDisplayName.split(',').first.trim();
    return fallback;
  }

  String _buildLabel({
    required String addressLine,
    required String postalCode,
    required String city,
    required String country,
    required String fallbackDisplayName,
  }) {
    final location = [
      if (postalCode.isNotEmpty) postalCode,
      if (city.isNotEmpty) city,
    ].join(' ');

    if (location.isNotEmpty && country.isNotEmpty) {
      return '$addressLine, $location, $country';
    }
    if (location.isNotEmpty) {
      return '$addressLine, $location';
    }
    if (country.isNotEmpty) {
      return '$addressLine, $country';
    }
    if (fallbackDisplayName.isNotEmpty) return fallbackDisplayName;
    return addressLine;
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _firstNonEmpty(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizePostalCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final compact = value.replaceAll(RegExp(r'\s+'), '');
    final digitsAndHyphen = compact.replaceAll(RegExp(r'[^0-9A-Za-z-]'), '');
    if (digitsAndHyphen.isEmpty) return value;

    return digitsAndHyphen.replaceAll(RegExp(r'-+'), '-');
  }
}
