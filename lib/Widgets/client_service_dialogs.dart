import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';

class ServicePickerOption {
  const ServicePickerOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ServiceSearchPickerSheet extends StatefulWidget {
  const ServiceSearchPickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.options,
    required this.selectedId,
    required this.primaryColor,
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<ServicePickerOption> options;
  final String? selectedId;
  final Color primaryColor;

  @override
  State<ServiceSearchPickerSheet> createState() =>
      _ServiceSearchPickerSheetState();
}

class _ServiceSearchPickerSheetState extends State<ServiceSearchPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.options.where((option) {
      if (query.isEmpty) return true;
      return option.label.toLowerCase().contains(query);
    }).toList();

    return AppBottomSheetShell(
      title: widget.title,
      subtitle: widget.subtitle,
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            AppTextField(
              label: widget.searchHint,
              controller: _searchController,
              prefixIcon: Icons.search,
              focusColor: widget.primaryColor,
              borderColor: widget.primaryColor.withValues(alpha: .25),
              fillColor: Colors.grey.shade100,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Sem resultados.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final selected = option.id == widget.selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, option),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? widget.primaryColor.withValues(alpha: .12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? widget.primaryColor
                                    : widget.primaryColor.withValues(
                                        alpha: .15,
                                      ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.chevron_right_rounded,
                                  color: selected
                                      ? widget.primaryColor
                                      : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
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

class ServicePriceSheet extends StatefulWidget {
  const ServicePriceSheet({
    super.key,
    required this.serviceName,
    required this.primaryColor,
    this.initialPrice,
  });

  final String serviceName;
  final Color primaryColor;
  final double? initialPrice;

  @override
  State<ServicePriceSheet> createState() => _ServicePriceSheetState();
}

class _ServicePriceSheetState extends State<ServicePriceSheet> {
  late final TextEditingController _priceController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.initialPrice == null
          ? ''
          : widget.initialPrice!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _priceController.text.trim();
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (raw.isEmpty || parsed == null || parsed < 0) {
      setState(() => _errorText = 'Define um valor válido para o serviço.');
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppBottomSheetShell(
        title: 'Preço do serviço',
        subtitle: widget.serviceName,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Preço (CHF)',
              controller: _priceController,
              keyboard: TextInputType.number,
              prefixIcon: Icons.payments_outlined,
              focusColor: widget.primaryColor,
              borderColor: widget.primaryColor.withValues(alpha: .25),
              fillColor: Colors.grey.shade100,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Cancelar',
                    outline: true,
                    color: widget.primaryColor,
                    onPressed: () => Navigator.of(context).pop(),
                    verticalPadding: 13,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: 'Adicionar',
                    icon: Icons.check_rounded,
                    color: widget.primaryColor,
                    onPressed: _submit,
                    verticalPadding: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
