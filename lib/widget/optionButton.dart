import 'package:flutter/material.dart';

class OptionButton extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const OptionButton({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? Colors.blue : Colors.grey.shade200,
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
