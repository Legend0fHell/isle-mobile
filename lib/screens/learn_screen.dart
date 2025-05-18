import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lesson_model.dart';
import '../widgets/lesson_card_widget.dart';
import '../providers/auth_provider.dart';
import 'lesson_detail_screen.dart';
import '../services/lesson_service.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({Key? key}) : super(key: key);

  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<Lesson> _lessons = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLessons();
  }

  Future<void> _fetchLessons() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final lessons = await LessonService.getAllLessons(context);

      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });

      print("Lessons HERE:");
      print(lessons);
    } catch (e) {

      print("Lessons Error: ${e.toString()}");
      setState(() {
        _errorMessage = 'Failed to load lessons: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _fetchLessons,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    print("RESULT LESSONS:");
    print(_lessons);
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading lessons...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchLessons,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_lessons.isEmpty) {
      return const Center(
        child: Text('No lessons available'),
      );
    }

    return ListView.builder(
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
    );
  }

  void _navigateToLessonDetail(Lesson lesson) {
    final isLoggedIn = Provider.of<AuthProvider>(context, listen: false).isAuthenticated;

    if (!isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return; // Stop further execution
    }

    if (!lesson.open) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lesson Closed'),
          content: Text('This lesson is currently closed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return; // Stop further execution
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailScreen(lesson: lesson),
      ),
    ).then((_) {
      // Refresh the list when returning from lesson detail
      _fetchLessons();
    });
  }
}