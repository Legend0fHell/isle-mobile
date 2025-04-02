import 'package:flutter/material.dart';

class SuggestionChip extends StatelessWidget {
  final String suggestion;
  final VoidCallback onTap;

  const SuggestionChip({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          suggestion,
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 