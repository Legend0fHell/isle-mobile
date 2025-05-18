import 'package:flutter/material.dart';
import '../models/lesson_model.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/practice_mirror_widget.dart';
import '../widgets/interactive_exercise_widget.dart';
import '../widgets/quiz_widget.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({Key? key, required this.lesson}) : super(key: key);

  @override
  _LessonDetailScreenState createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  int _currentStep = 0;
  double _lessonProgress = 0.0;

  // Add a key to force widget rebuild when content changes
  final Map<int, GlobalKey> _contentKeys = {};

  @override
  void initState() {
    super.initState();
    _lessonProgress = widget.lesson.progress;

    // Initialize keys for all content items
    for (int i = 0; i < widget.lesson.content.length; i++) {
      _contentKeys[i] = GlobalKey();
    }
  }

  void _updateProgress(double progress) {
    setState(() {
      _lessonProgress = progress;
      // In a real app, you would save this progress to storage/backend
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '${(_lessonProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: _lessonProgress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getLessonColor()),
            minHeight: 10,
          ),
          // Step indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Step ${_currentStep + 1} of ${widget.lesson.content.length}: ${widget.lesson.content[_currentStep].title}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Content description
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.lesson.description,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Lesson content
          Expanded(
            child: _buildLessonContent(),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                      // Update progress when going back
                      _updateProgress(
                          (_currentStep + 1) / widget.lesson.content.length);
                    });
                  },
                  child: const Text('Previous'),
                ),
              if (_currentStep > 0) const Spacer(),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_currentStep < widget.lesson.content.length - 1) {
                      _currentStep++;
                      // Update progress when advancing
                      _updateProgress(
                          (_currentStep + 1) / widget.lesson.content.length);
                    } else {
                      // Lesson completed
                      _updateProgress(1.0);
                      // Navigate back or show completion dialog
                      _showCompletionDialog();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getLessonColor(),
                ),
                child: Text(_currentStep < widget.lesson.content.length - 1
                    ? 'Next'
                    : 'Complete'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLessonColor() {
    switch (widget.lesson.id) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  Widget _buildLessonContent() {
    // Get current lesson content item
    final contentItem = widget.lesson.content[_currentStep];

    // Use a key specific to this step to force rebuild
    final key = _contentKeys[_currentStep] ?? GlobalKey();

    // Return appropriate widget based on content type
    switch (contentItem.type) {
      case LessonContentType.video:
        return VideoPlayerWidget(
          key: key,
          videoUrl: contentItem.resourceUrl,
        );
      case LessonContentType.practice:
        return PracticeMirrorWidget(
          key: key,
          referenceVideoUrl: contentItem.resourceUrl,
          instructions: contentItem.instructions,
        );
      case LessonContentType.interactive:
        return InteractiveExerciseWidget(
          key: key,
          exercise: contentItem,
          onComplete: (score) {
            // Handle completion of interactive exercise
          },
        );
      case LessonContentType.quiz:
        return QuizWidget(
          key: key,
          questions: contentItem.questions,
          onComplete: (score) {
            // Handle completion of quiz
          },
        );
      default:
        return Center(
          child: Text(
            'Content not available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lesson Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('You\'ve completed ${widget.lesson.title}'),
            const SizedBox(height: 8),
            const Text('Great job learning these signs!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Lessons'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset to first step to practice again
              setState(() {
                _currentStep = 0;
              });
            },
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }
}