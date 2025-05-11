import 'package:flutter/material.dart';
import '../models/lesson_model.dart';
import '../widgets/lesson_card_widget.dart';
import 'lesson_detail_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({Key? key}) : super(key: key);

  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final List<Lesson> _lessons = [
    Lesson.commonWords(),
    Lesson.vowels(),
    Lesson.consonants(),
  ];

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _lessons.length,
        itemBuilder: (context, index) {
          final lesson = _lessons[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: LessonCardWidget(
              lesson: lesson,
              onTap: () {
                _navigateToLessonDetail(lesson);
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToLessonDetail(Lesson lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailScreen(lesson: lesson),
      ),
    ).then((_) {
      // Refresh the list when returning from lesson detail
      setState(() {});
    });
  }
}