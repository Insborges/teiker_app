import 'package:flutter/material.dart';
import 'package:teiker_app/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final Color focusColor;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final Color fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final Color? borderColor;
  final double borderRadius;
  final int maxLines;
  final bool? enableInteractiveSelection;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.focusColor = AppColors.primaryGreen,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.fillColor = Colors.white,
    this.contentPadding,
    this.textInputAction,
    this.onChanged,
    this.style,
    this.labelStyle,
    this.borderColor,
    this.borderRadius = 12,
    this.maxLines = 1,
    this.enableInteractiveSelection,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final neutralBorder = borderColor ?? Colors.grey.shade400;
    final baseLabelStyle =
        labelStyle ??
        TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      obscureText: obscureText,
      readOnly: readOnly,
      textInputAction: textInputAction,
      onChanged: onChanged,
      style: style,
      maxLines: maxLines,
      enableInteractiveSelection: enableInteractiveSelection ?? !readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: baseLabelStyle,
        floatingLabelStyle: baseLabelStyle.copyWith(
          color: focusColor,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: focusColor)
            : null,
        suffixIcon: suffixIcon,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: neutralBorder.withValues(alpha: .85),
            width: 1.25,
          ),
        ),
        filled: true,
        fillColor: fillColor,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: focusColor, width: 1.9),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.red.shade700, width: 1.8),
        ),
      ),
    );
  }
}
