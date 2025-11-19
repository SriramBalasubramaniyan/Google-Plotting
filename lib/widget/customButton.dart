import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.label,
    this.bgColor = Colors.green,
    this.onPressed,
    super.key,
  });

  final MaterialColor bgColor;
  final String label;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      splashColor: bgColor,
      color: bgColor.shade50,
      elevation: 0,
      onPressed: onPressed,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: FittedBox(
        child: Text(
          label,
          style: TextStyle(color: bgColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}