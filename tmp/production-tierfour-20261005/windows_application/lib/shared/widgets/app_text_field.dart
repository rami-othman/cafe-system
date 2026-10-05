import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.onChanged,
    this.onTap,
    this.keyboardType,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.prefixText,
    this.errorText,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final TextAlign textAlign;
  final String? prefixText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      keyboardType: keyboardType,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      textAlign: textAlign,
      decoration: InputDecoration(
        constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
        labelText: label,
        hintText: hint ?? hintText,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon == null
            ? null
            : onSuffixPressed == null
            ? Icon(suffixIcon)
            : IconButton(icon: Icon(suffixIcon), onPressed: onSuffixPressed),
        errorText: errorText,
      ),
    );
  }
}
