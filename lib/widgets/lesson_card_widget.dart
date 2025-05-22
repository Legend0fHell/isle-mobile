import 'package:flutter/material.dart';
import '../models/lesson_model.dart';

class LessonCardWidget extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;

  const LessonCardWidget({
    Key? key,
    required this.lesson,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _getLessonColor(),
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                _getActionIcon(),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              lesson.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: ${_getStatusText()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '(${(lesson.getProgress() * 100).toInt()}%)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getLessonColor() {
    switch (lesson.objId) {
      default:
        return Colors.purple;
    }
  }

  Widget _getActionIcon() {
    if (lesson.getProgress() >= 1.0) {
      return const Icon(
        Icons.check_circle,
        color: Colors.white,
        size: 28,
      );
    } else if (lesson.getProgress() > 0.0) {
      return const Icon(
        Icons.arrow_forward,
        color: Colors.white,
        size: 28,
      );
    } else {
      return const Icon(
        Icons.add,
        color: Colors.white,
        size: 28,
      );
    }
  }

  String _getStatusText() {
    if (lesson.getProgress() >= 1.0) {
      return 'Completed';
    } else if (lesson.getProgress() > 0.0) {
      return 'In progress';
    } else {
      return 'Not started';
    }
  }
}