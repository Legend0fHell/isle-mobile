// lib/screens/learn_screen.dart
import 'package:flutter/material.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildLessonCard(
              'Lesson 1',
              'The common words: Hello, How are you?, What\'s your name?',
              'Completed',
              100,
              Colors.green,
              Icons.check_circle,
            ),
            const SizedBox(height: 16),
            _buildLessonCard(
              'Lesson 2',
              'The vowels: A, E, I, O U',
              'In progress',
              50,
              Colors.amber,
              Icons.arrow_forward,
            ),
            const SizedBox(height: 16),
            _buildLessonCard(
              'Lesson 3',
              'The common consonants: B, C, D, F, G',
              'Not started',
              0,
              Colors.white,
              Icons.add,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(String title, String description, String status,
      int percentage, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: color == Colors.white ? Colors.black : Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  color: color == Colors.white ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: color == Colors.white ? Colors.black : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Status: $status ($percentage%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color == Colors.white ? Colors.black : Colors.black.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}