import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
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
    required this.issuingInvoice,
    required this.onEmitirFaturas,
    required this.invoicesStream,
    required this.sharingInvoiceIds,
    required this.deletingInvoiceIds,
    required this.onShareInvoice,
    required this.onDeleteInvoice,
    required this.serviceMonthLabel,
    required this.appliedServicePrices,
    required this.onRemoveAppliedService,
    required this.onAddService,
  });

  final Color primaryColor;
  final Color borderColor;
  final double currentPricePerHour;
  final double horasCasa;
  final Map<String, double> currentServicePrices;
  final VoidCallback onAddHoras;
  final bool issuingInvoice;
  final VoidCallback onEmitirFaturas;
  final Stream<List<ClientInvoice>> invoicesStream;
  final Set<String> sharingInvoiceIds;
  final Set<String> deletingInvoiceIds;
  final Future<void> Function(ClientInvoice invoice) onShareInvoice;
  final Future<void> Function(ClientInvoice invoice) onDeleteInvoice;
  final String serviceMonthLabel;
  final Map<String, double> appliedServicePrices;
  final Future<void> Function(String serviceKey) onRemoveAppliedService;
  final VoidCallback onAddService;

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
          AppButton(
            text: 'Adicionar Horas',
            icon: Icons.timer,
            color: primaryColor,
            onPressed: onAddHoras,
          ),
          const SizedBox(height: 12),
          ClientIssuedInvoicesCard(
            primaryColor: primaryColor,
            borderColor: borderColor,
            invoicesStream: invoicesStream,
            sharingInvoiceIds: sharingInvoiceIds,
            deletingInvoiceIds: deletingInvoiceIds,
            onShareInvoice: onShareInvoice,
            onDeleteInvoice: onDeleteInvoice,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: issuingInvoice ? 'A emitir fatura...' : 'Emitir Faturas',
            icon: Icons.file_copy,
            color: primaryColor,
            enabled: !issuingInvoice,
            onPressed: onEmitirFaturas,
          ),
          const SizedBox(height: 12),
          ClientAdditionalServicesSection(
            primaryColor: primaryColor,
            borderColor: borderColor,
            serviceMonthLabel: serviceMonthLabel,
            appliedServicePrices: appliedServicePrices,
            onRemoveAppliedService: onRemoveAppliedService,
            onAddService: onAddService,
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
    required this.codigoPostalController,
    required this.phoneController,
    required this.phoneCountryIso,
    required this.onPhoneCountryChanged,
    required this.emailController,
    required this.orcamentoController,
    required this.onSave,
  });

  final Color primaryColor;
  final Color borderColor;
  final TextEditingController nameController;
  final TextEditingController moradaController;
  final TextEditingController codigoPostalController;
  final TextEditingController phoneController;
  final String phoneCountryIso;
  final ValueChanged<String> onPhoneCountryChanged;
  final TextEditingController emailController;
  final TextEditingController orcamentoController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ClientDetailsStyledField(
            label: 'Nome',
            controller: nameController,
            borderColor: borderColor,
            focusColor: primaryColor,
            fillColor: Colors.white,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          ClientDetailsStyledField(
            label: 'Morada',
            controller: moradaController,
            borderColor: borderColor,
            focusColor: primaryColor,
            fillColor: Colors.white,
            prefixIcon: Icons.home_outlined,
          ),
          const SizedBox(height: 12),
          ClientDetailsStyledField(
            label: 'Código Postal',
            controller: codigoPostalController,
            borderColor: borderColor,
            focusColor: primaryColor,
            fillColor: Colors.white,
            prefixIcon: Icons.local_post_office_outlined,
          ),
          const SizedBox(height: 12),
          PhoneNumberInputRow(
            controller: phoneController,
            countryIso: phoneCountryIso,
            onCountryChanged: onPhoneCountryChanged,
            primaryColor: primaryColor,
            label: 'Telefone',
            fillColor: Colors.white,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          ClientDetailsStyledField(
            label: 'Email',
            controller: emailController,
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
            keyboard: TextInputType.number,
            borderColor: borderColor,
            focusColor: primaryColor,
            fillColor: Colors.white,
            prefixIcon: Icons.payments_outlined,
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Guardar Alterações',
            icon: Icons.save_rounded,
            color: primaryColor,
            onPressed: onSave,
          ),
          const SizedBox(height: 12),
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
