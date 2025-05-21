import 'package:flutter/material.dart';

// Widget for displaying progress information with optional percentage
class ProgressCard extends StatelessWidget {
  final String title;
  final String value;
  final int? percentage;

  const ProgressCard({
    super.key,
    required this.title,
    required this.value,
    this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (percentage != null)
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (percentage != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: percentage! / 100,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ],
      ),
    );
  }
}
