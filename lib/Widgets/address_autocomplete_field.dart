import 'dart:async';

import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/backend/address_autocomplete_service.dart';

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.addressController,
    required this.cityController,
    required this.onPostalCodeSelected,
    required this.label,
    required this.focusColor,
    required this.fillColor,
    required this.borderColor,
    this.prefixIcon = Icons.home_outlined,
    this.countryBias,
    this.autocompleteService,
  });

  final TextEditingController addressController;
  final TextEditingController cityController;
  final ValueChanged<String> onPostalCodeSelected;
  final String label;
  final Color focusColor;
  final Color fillColor;
  final Color borderColor;
  final IconData prefixIcon;
  final List<String>? countryBias;
  final AddressAutocompleteService? autocompleteService;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  static const _debounceDuration = Duration(milliseconds: 350);

  late final AddressAutocompleteService _service;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  int _requestId = 0;
  bool _loading = false;
  List<AddressSuggestion> _suggestions = const <AddressSuggestion>[];

  @override
  void initState() {
    super.initState();
    _service = widget.autocompleteService ?? const AddressAutocompleteService();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && mounted) {
      setState(() => _suggestions = const <AddressSuggestion>[]);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _requestId++;
    final trimmed = value.trim();

    if (trimmed.length < 3) {
      if (mounted) {
        setState(() {
          _loading = false;
          _suggestions = const <AddressSuggestion>[];
        });
      }
      return;
    }

    _debounce = Timer(_debounceDuration, () async {
      final currentRequestId = _requestId;
      if (mounted) {
        setState(() => _loading = true);
      }
      final suggestions = await _service.search(
        trimmed,
        countryBias: widget.countryBias,
      );
      if (!mounted || currentRequestId != _requestId) return;
      setState(() {
        _loading = false;
        _suggestions = suggestions;
      });
    });
  }

  void _applySuggestion(AddressSuggestion suggestion) {
    widget.addressController.text = suggestion.addressLine;
    if (suggestion.city.isNotEmpty) {
      widget.cityController.text = suggestion.city;
    }
    if (suggestion.postalCode.isNotEmpty) {
      widget.onPostalCodeSelected(suggestion.postalCode);
    }

    FocusScope.of(context).unfocus();
    setState(() => _suggestions = const <AddressSuggestion>[]);
  }

  @override
  Widget build(BuildContext context) {
    final hasSuggestions = _suggestions.isNotEmpty && _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: widget.label,
          controller: widget.addressController,
          focusNode: _focusNode,
          focusColor: widget.focusColor,
          fillColor: widget.fillColor,
          borderColor: widget.borderColor,
          prefixIcon: widget.prefixIcon,
          onChanged: _onChanged,
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search_outlined),
        ),
        if (hasSuggestions) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: widget.borderColor),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: widget.focusColor,
                    size: 20,
                  ),
                  title: Text(
                    suggestion.addressLine,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (suggestion.postalCode.isNotEmpty)
                        suggestion.postalCode,
                      if (suggestion.city.isNotEmpty) suggestion.city,
                    ].join(' '),
                  ),
                  onTap: () => _applySuggestion(suggestion),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
