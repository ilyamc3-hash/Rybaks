import 'package:flutter/material.dart';

/// Единое текстовое поле ввода, используемое на всех экранах приложения.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final TextAlign textAlign;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      textAlign: textAlign,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        counterText: '',
      ),
    );
  }
}
