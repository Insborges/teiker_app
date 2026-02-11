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
  });

  @override
  Widget build(BuildContext context) {
    final neutralBorder = borderColor ?? Colors.grey.shade400;

    return TextFormField(
      controller: controller,
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
        labelStyle: labelStyle,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: focusColor)
            : null,
        suffixIcon: suffixIcon,
        contentPadding: contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: neutralBorder, width: 1.2),
        ),
        filled: true,
        fillColor: fillColor,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: focusColor, width: 2),
        ),
      ),
    );
  }
}
