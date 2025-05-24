import 'package:flutter/material.dart';
import '../models/lesson_model.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/practice_mirror_widget.dart';
import '../widgets/interactive_exercise_widget.dart';
import '../widgets/quiz_widget.dart';
import '../services/mongodb_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({Key? key, required this.lesson}) : super(key: key);

  @override
  _LessonDetailScreenState createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  int _currentStep = 0;
  double _lessonProgress = 0.0;
  bool _isPracticeSuccessful = false;
  bool _isFinished = false;
  String? _detectedSign;
  String? _targetSign;

  // Add a key to force widget rebuild when content changes
  final Map<int, GlobalKey> _contentKeys = {};

  @override
  void initState() {
    super.initState();
    _lessonProgress = widget.lesson.getProgress();

    // Initialize keys for all content items
    for (int i = 0; i < widget.lesson.content.length; i++) {
      _contentKeys[i] = GlobalKey();
    }

    // Set initial target sign and practice status
    _updateCurrentStepState();
  }

  void _updateCurrentStepState() {
    final contentItem = widget.lesson.content[_currentStep];

    // Reset practice status when changing steps
    _isPracticeSuccessful = false;
    _detectedSign = null;
    _isFinished = contentItem.status == LessonContentStatus.finished;

    // Set target sign for practice content
    if (contentItem.type == LessonContentType.practice) {
      // Extract target sign from title or instructions
      // Assuming the target sign is stored in the content item
      // You may need to adjust this based on your data structure
      _targetSign = _extractTargetSign(contentItem);
    } else {
      _targetSign = null;
      // For non-practice content, mark as successful by default
      _isPracticeSuccessful = true;
    }
  }

  String? _extractTargetSign(dynamic contentItem) {
    // Extract target sign from title, instructions, or a dedicated field
    // This is a simple example - adjust based on your data structure
    String text = contentItem.title?.toLowerCase() ?? '';
    text += ' ${contentItem.instructions?.toLowerCase() ?? ''}';

    // Look for patterns like "practice A", "sign A", "letter A", etc.
    RegExp regExp = RegExp(r'\b(?:practice|sign|letter)\s+([a-z])\b');
    Match? match = regExp.firstMatch(text);

    if (match != null) {
      return match.group(1)?.toUpperCase();
    }

    // Fallback: look for single letters in the title
    RegExp letterRegExp = RegExp(r'\b([A-Z])\b');
    Match? letterMatch = letterRegExp.firstMatch(contentItem.title ?? '');

    return letterMatch?.group(1);
  }

  void _onSignDetected(String detectedSign) {
    setState(() {
      _detectedSign = detectedSign;

      // Check if detected sign matches target sign
      if (_targetSign != null &&
          detectedSign.toUpperCase() == _targetSign!.toUpperCase()) {
        _isPracticeSuccessful = true;
      }
    });
  }

  void _updateProgress(double progress) {
    setState(() {
      _lessonProgress = progress;
      // In a real app, you would save this progress to storage/backend
    });
  }

  Future<void> _markCurrentStepComplete(BuildContext context) async {
    final contentItem = widget.lesson.content[_currentStep];

    print("ADD LESSON TO USER PROGRESS: START");

    try {
      print("ADD LESSON TO USER PROGRESS");
      print("${contentItem.objId.toHexString()}");
      await MongoDBService.addLessonToUserProgress(context, contentItem.objId.toHexString());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update progress: $e')),
      );
    }
  }

  bool _canProceedToNext() {
    final contentItem = widget.lesson.content[_currentStep];

    // For practice content, require successful practice
    if (contentItem.type == LessonContentType.practice) {
      return _isPracticeSuccessful || _isFinished;
    }

    // For other content types, can always proceed
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.lesson.title),
          actions: [
            // Completion tick indicator
            if (_isFinished)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
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
          // Step indicator with completion status
          // Step indicator with completion status
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Step counter row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of ${widget.lesson.content.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    if (_isFinished) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Step title row (with proper text wrapping)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.lesson.content[_currentStep].title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Completion banner (optional - shows when current step is completed)
          if (_isFinished)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'This step is completed!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep--;
                          _updateCurrentStepState();
                          _updateProgress((_currentStep + 1) / widget.lesson.content.length);
                        });
                      },
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                if (_canProceedToNext())
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _markCurrentStepComplete(context);
                        setState(() {
                          if (_currentStep < widget.lesson.content.length - 1) {
                            _currentStep++;
                            _updateCurrentStepState();
                            _updateProgress((_currentStep + 1) / widget.lesson.content.length);
                          } else {
                            _updateProgress(1.0);
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getLessonColor() {
    switch (widget.lesson.objId) {
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
          targetSign: _targetSign,
          onSignDetected: _onSignDetected,
          initialVideoOn: !_isFinished,
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
                _updateCurrentStepState();
              });
            },
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }
}