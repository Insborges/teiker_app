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
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final Color? borderColor;
  final double borderRadius;
  final int maxLines;
  final bool? enableInteractiveSelection;
  final FocusNode? focusNode;
  final bool prefixIconAlignTop;

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
    this.onFieldSubmitted,
    this.autofillHints,
    this.style,
    this.labelStyle,
    this.borderColor,
    this.borderRadius = 12,
    this.maxLines = 1,
    this.enableInteractiveSelection,
    this.focusNode,
    this.prefixIconAlignTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final neutralBorder = borderColor ?? Colors.grey.shade400;
    final isMultiline = maxLines > 1;
    final useHintInside = isMultiline && prefixIcon != null;
    final useInlinePrefixForMultiline = useHintInside;
    final shouldTopAlignPrefixIcon =
        prefixIcon != null &&
        !useInlinePrefixForMultiline &&
        (isMultiline || prefixIconAlignTop);
    final baseLabelStyle =
        labelStyle ??
        TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        );
    final effectiveContentPadding =
        contentPadding ??
        (isMultiline
            ? const EdgeInsets.fromLTRB(14, 14, 14, 14)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      obscureText: obscureText,
      readOnly: readOnly,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      style: style,
      maxLines: maxLines,
      textAlignVertical: isMultiline ? TextAlignVertical.top : null,
      enableInteractiveSelection: enableInteractiveSelection ?? !readOnly,
      decoration: InputDecoration(
        labelText: useHintInside ? null : label,
        hintText: useHintInside ? label : null,
        hintStyle: useHintInside ? baseLabelStyle : null,
        hintMaxLines: useHintInside ? maxLines : null,
        alignLabelWithHint: isMultiline,
        labelStyle: baseLabelStyle,
        floatingLabelBehavior: useHintInside
            ? FloatingLabelBehavior.never
            : FloatingLabelBehavior.auto,
        floatingLabelStyle: baseLabelStyle.copyWith(
          color: focusColor,
          fontWeight: FontWeight.w700,
        ),
        prefix: useInlinePrefixForMultiline
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(prefixIcon, size: 20, color: focusColor),
              )
            : null,
        prefixIcon: prefixIcon != null
            ? (useInlinePrefixForMultiline
                  ? null
                  : shouldTopAlignPrefixIcon
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12, top: 12),
                      child: Align(
                        alignment: Alignment.topLeft,
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Icon(prefixIcon, color: focusColor),
                      ),
                    )
                  : Icon(prefixIcon, color: focusColor))
            : null,
        prefixIconConstraints: shouldTopAlignPrefixIcon
            ? const BoxConstraints(minWidth: 44, minHeight: 0)
            : null,
        suffixIcon: suffixIcon,
        contentPadding: effectiveContentPadding,
        isDense: !isMultiline,
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
