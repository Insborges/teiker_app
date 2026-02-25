import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/address_autocomplete_field.dart';
import 'package:teiker_app/Widgets/client_details_sections.dart';
import 'package:teiker_app/Widgets/phone_number_input_row.dart';
import 'package:teiker_app/models/client_invoice.dart';

class ClientDetailsAdminHoursTab extends StatelessWidget {
  const ClientDetailsAdminHoursTab({
    super.key,
    required this.primaryColor,
    required this.borderColor,
    required this.currentPricePerHour,
    required this.horasCasa,
    required this.currentServicePrices,
    required this.onAddHoras,
    required this.canAddHoras,
    required this.issuingInvoice,
    required this.onEmitirFaturas,
    required this.canEmitirFaturas,
    required this.invoicesStream,
    required this.sharingInvoiceIds,
    required this.deletingInvoiceIds,
    required this.onShareInvoice,
    required this.onDeleteInvoice,
    required this.canShareInvoices,
    required this.canDeleteInvoices,
    required this.serviceMonthLabel,
    required this.appliedServicePrices,
    required this.onRemoveAppliedService,
    required this.onAddService,
    required this.canManageAdditionalServices,
  });

  final Color primaryColor;
  final Color borderColor;
  final double currentPricePerHour;
  final double horasCasa;
  final Map<String, double> currentServicePrices;
  final VoidCallback onAddHoras;
  final bool canAddHoras;
  final bool issuingInvoice;
  final VoidCallback onEmitirFaturas;
  final bool canEmitirFaturas;
  final Stream<List<ClientInvoice>> invoicesStream;
  final Set<String> sharingInvoiceIds;
  final Set<String> deletingInvoiceIds;
  final Future<void> Function(ClientInvoice invoice) onShareInvoice;
  final Future<void> Function(ClientInvoice invoice) onDeleteInvoice;
  final bool canShareInvoices;
  final bool canDeleteInvoices;
  final String serviceMonthLabel;
  final Map<String, double> appliedServicePrices;
  final Future<void> Function(String serviceKey) onRemoveAppliedService;
  final VoidCallback onAddService;
  final bool canManageAdditionalServices;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ClientOrcamentoSummaryCard(
            orcamento: currentPricePerHour,
            horas: horasCasa,
            servicePrices: currentServicePrices,
          ),
          const SizedBox(height: 12),
          if (canAddHoras) ...[
            AppButton(
              text: 'Adicionar Horas',
              icon: Icons.timer,
              color: primaryColor,
              onPressed: onAddHoras,
            ),
            const SizedBox(height: 12),
          ],
          ClientIssuedInvoicesCard(
            primaryColor: primaryColor,
            borderColor: borderColor,
            invoicesStream: invoicesStream,
            sharingInvoiceIds: sharingInvoiceIds,
            deletingInvoiceIds: deletingInvoiceIds,
            onShareInvoice: onShareInvoice,
            onDeleteInvoice: onDeleteInvoice,
            canShareInvoices: canShareInvoices,
            canDeleteInvoices: canDeleteInvoices,
          ),
          const SizedBox(height: 12),
          if (canEmitirFaturas) ...[
            AppButton(
              text: issuingInvoice ? 'A emitir fatura...' : 'Emitir Faturas',
              icon: Icons.file_copy,
              color: primaryColor,
              enabled: !issuingInvoice,
              onPressed: onEmitirFaturas,
            ),
            const SizedBox(height: 12),
          ],
          ClientAdditionalServicesSection(
            primaryColor: primaryColor,
            borderColor: borderColor,
            serviceMonthLabel: serviceMonthLabel,
            appliedServicePrices: appliedServicePrices,
            onRemoveAppliedService: onRemoveAppliedService,
            onAddService: onAddService,
            readOnly: !canManageAdditionalServices,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class ClientDetailsAdminInfoTab extends StatelessWidget {
  const ClientDetailsAdminInfoTab({
    super.key,
    required this.primaryColor,
    required this.borderColor,
    required this.nameController,
    required this.moradaController,
    required this.cidadeController,
    required this.codigoPostalController,
    required this.phoneController,
    required this.phoneCountryIso,
    required this.onPhoneCountryChanged,
    required this.emailController,
    required this.orcamentoController,
    required this.onSave,
    required this.readOnly,
    this.associatedTeikerNames = const <String>[],
  });

  final Color primaryColor;
  final Color borderColor;
  final TextEditingController nameController;
  final TextEditingController moradaController;
  final TextEditingController cidadeController;
  final TextEditingController codigoPostalController;
  final TextEditingController phoneController;
  final String phoneCountryIso;
  final ValueChanged<String> onPhoneCountryChanged;
  final TextEditingController emailController;
  final TextEditingController orcamentoController;
  final VoidCallback onSave;
  final bool readOnly;
  final List<String> associatedTeikerNames;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ClientInfoSectionCard(
            title: 'Dados do cliente',
            icon: Icons.badge_outlined,
            primaryColor: primaryColor,
            borderColor: borderColor,
            child: Column(
              children: [
                ClientDetailsStyledField(
                  label: 'Nome',
                  controller: nameController,
                  readOnly: readOnly,
                  borderColor: borderColor,
                  focusColor: primaryColor,
                  fillColor: Colors.white,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                if (readOnly)
                  ClientDetailsStyledField(
                    label: 'Morada',
                    controller: moradaController,
                    readOnly: true,
                    borderColor: borderColor,
                    focusColor: primaryColor,
                    fillColor: Colors.white,
                    prefixIcon: Icons.home_outlined,
                  )
                else
                  AddressAutocompleteField(
                    label: 'Morada',
                    addressController: moradaController,
                    cityController: cidadeController,
                    countryBias: const ['CH', 'PT'],
                    onPostalCodeSelected: (postalCode) {
                      codigoPostalController.text = postalCode;
                    },
                    focusColor: primaryColor,
                    fillColor: Colors.white,
                    borderColor: borderColor,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: ClientDetailsStyledField(
                        label: 'Código Postal',
                        controller: codigoPostalController,
                        readOnly: readOnly,
                        borderColor: borderColor,
                        focusColor: primaryColor,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 13,
                      child: ClientDetailsStyledField(
                        label: 'Cidade',
                        controller: cidadeController,
                        readOnly: readOnly,
                        borderColor: borderColor,
                        focusColor: primaryColor,
                        fillColor: Colors.white,
                        prefixIcon: Icons.location_city_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!readOnly) ...[
            const SizedBox(height: 12),
            ClientInfoSectionCard(
              title: 'Teikers associadas',
              icon: Icons.groups_2_outlined,
              primaryColor: primaryColor,
              borderColor: borderColor,
              child: associatedTeikerNames.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Text(
                        'Sem teikers associadas.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: associatedTeikerNames
                          .map(
                            (name) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: borderColor.withValues(alpha: .8),
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
          const SizedBox(height: 12),
          ClientInfoSectionCard(
            title: 'Contacto e faturação',
            icon: Icons.receipt_long_outlined,
            primaryColor: primaryColor,
            borderColor: borderColor,
            child: Column(
              children: [
                PhoneNumberInputRow(
                  controller: phoneController,
                  countryIso: phoneCountryIso,
                  onCountryChanged: readOnly ? (_) {} : onPhoneCountryChanged,
                  primaryColor: primaryColor,
                  label: 'Telefone',
                  readOnlyNumber: readOnly,
                  allowCountryPicker: !readOnly,
                  fillColor: Colors.white,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 12),
                ClientDetailsStyledField(
                  label: 'Email',
                  controller: emailController,
                  readOnly: readOnly,
                  keyboard: TextInputType.emailAddress,
                  borderColor: borderColor,
                  focusColor: primaryColor,
                  fillColor: Colors.white,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 12),
                ClientDetailsStyledField(
                  label: 'Preço/Hora',
                  controller: orcamentoController,
                  readOnly: readOnly,
                  keyboard: TextInputType.number,
                  borderColor: borderColor,
                  focusColor: primaryColor,
                  fillColor: Colors.white,
                  prefixIcon: Icons.payments_outlined,
                ),
              ],
            ),
          ),
          if (!readOnly) ...[
            const SizedBox(height: 16),
            AppButton(
              text: 'Guardar Alterações',
              icon: Icons.save_rounded,
              color: primaryColor,
              onPressed: onSave,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class ClientInfoSectionCard extends StatelessWidget {
  const ClientInfoSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.borderColor,
    required this.child,
    this.backgroundColor = Colors.white,
  });

  final String title;
  final IconData icon;
  final Color primaryColor;
  final Color borderColor;
  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class ClientDetailsStyledField extends StatelessWidget {
  const ClientDetailsStyledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.readOnly = false,
    this.borderColor,
    this.focusColor,
    this.labelColor,
    this.textColor,
    this.fillColor = Colors.white,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final bool readOnly;
  final Color? borderColor;
  final Color? focusColor;
  final Color? labelColor;
  final Color? textColor;
  final Color fillColor;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      prefixIcon: prefixIcon,
      readOnly: readOnly,
      keyboard: keyboard,
      focusColor: focusColor ?? borderColor ?? Colors.grey.shade600,
      fillColor: fillColor,
      borderColor: borderColor ?? Colors.grey.shade400,
      enableInteractiveSelection: !readOnly,
      style: textColor != null
          ? TextStyle(color: textColor, fontWeight: FontWeight.w600)
          : null,
      labelStyle: labelColor != null
          ? TextStyle(color: labelColor, fontWeight: FontWeight.w600)
          : null,
      borderRadius: 12,
    );
  }
}
