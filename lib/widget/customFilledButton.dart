import 'package:flutter/material.dart';

class CustomFilledButton extends StatelessWidget {
  const CustomFilledButton({
    super.key,
    required this.label,
    this.color,
    this.onPressed,
  });

  final MaterialColor? color;
  final void Function()? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(elevation: 7, backgroundColor: color),
      onPressed: onPressed,
      child: Align(
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}