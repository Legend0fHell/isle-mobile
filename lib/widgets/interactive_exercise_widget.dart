import 'package:flutter/material.dart';
import '../models/lesson_model.dart';
import 'video_player_widget.dart';

class InteractiveExerciseWidget extends StatefulWidget {
  final LessonContent exercise;
  final Function(double) onComplete;

  const InteractiveExerciseWidget({
    Key? key,
    required this.exercise,
    required this.onComplete,
  }) : super(key: key);

  @override
  _InteractiveExerciseWidgetState createState() =>
      _InteractiveExerciseWidgetState();
}

class _InteractiveExerciseWidgetState extends State<InteractiveExerciseWidget> {
  int _currentStep = 0;
  bool _showHint = false;
  List<bool> _stepsCompleted = [];

  @override
  void initState() {
    super.initState();
    // Initialize steps completion tracking
    if (widget.exercise.dialogueSteps != null) {
      _stepsCompleted = List.generate(
        widget.exercise.dialogueSteps!.length,
            (index) => false,
      );
    } else if (widget.exercise.wordExamples != null) {
      _stepsCompleted = List.generate(
        widget.exercise.wordExamples!.length,
            (index) => false,
      );
    } else {
      _stepsCompleted = [false]; // Default if no steps defined
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            widget.exercise.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            widget.exercise.instructions,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24.0),

        // Display current exercise item
        _buildCurrentExerciseItem(),

        const SizedBox(height: 24.0),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentStep > 0)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                      _showHint = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                ),
              const SizedBox(width: 16.0),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showHint = !_showHint;
                  });
                },
                icon: Icon(_showHint ? Icons.visibility_off : Icons.visibility),
                label: Text(_showHint ? 'Hide Hint' : 'Show Hint'),
              ),
              const SizedBox(width: 16.0),
              if (_currentStep < getTotalSteps() - 1)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _stepsCompleted[_currentStep] = true;
                      _currentStep++;
                      _showHint = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              if (_currentStep == getTotalSteps() - 1)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _stepsCompleted[_currentStep] = true;
                    });

                    // Calculate completion score (percentage of steps completed)
                    final completedSteps = _stepsCompleted.where((step) => step).length;
                    final score = completedSteps / _stepsCompleted.length;

                    // Notify parent with completion score
                    widget.onComplete(score);

                    // Show completion dialog
                    _showCompletionDialog(score);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
            ],
          ),
        ),

        // Progress indicators
        const SizedBox(height: 24.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: _buildStepIndicators(),
        ),
      ],
    );
  }

  Widget _buildCurrentExerciseItem() {
    // Handle dialogue steps exercise
    if (widget.exercise.dialogueSteps != null &&
        widget.exercise.dialogueSteps!.isNotEmpty) {
      return _buildDialogueStep();
    }

    // Handle word examples exercise
    if (widget.exercise.wordExamples != null &&
        widget.exercise.wordExamples!.isNotEmpty) {
      return _buildWordExampleStep();
    }

    // Fallback for other types
    return const Center(
      child: Text('No exercise content available'),
    );
  }

  Widget _buildDialogueStep() {
    final currentPhrase = widget.exercise.dialogueSteps![_currentStep];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blue),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.forum,
                size: 48,
                color: Colors.blue,
              ),
              const SizedBox(height: 16.0),
              Text(
                'Sign this phrase:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                currentPhrase,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (_showHint)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  'Hint video would play here for "$currentPhrase"',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWordExampleStep() {
    final currentWord = widget.exercise.wordExamples![_currentStep];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.purple),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.spellcheck,
                size: 48,
                color: Colors.purple,
              ),
              const SizedBox(height: 16.0),
              Text(
                'Sign this word:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.purple[800],
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                currentWord,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),
              Wrap(
                spacing: 8.0,
                children: currentWord.split('').map((letter) {
                  return Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        if (_showHint)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  'Hint video would play here for "$currentWord"',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        getTotalSteps(),
            (index) => Container(
          width: 24.0,
          height: 24.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentStep == index
                ? Colors.blue
                : _stepsCompleted[index]
                ? Colors.green
                : Colors.grey[300],
            border: Border.all(
              color: _currentStep == index ? Colors.blue[700]! : Colors.grey,
              width: 2.0,
            ),
          ),
          child: _stepsCompleted[index]
              ? const Icon(
            Icons.check,
            size: 16.0,
            color: Colors.white,
          )
              : Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: _currentStep == index ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCompletionDialog(double score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exercise Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              color: Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'You completed the ${widget.exercise.title}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 0.8
                    ? Colors.green
                    : score >= 0.5
                    ? Colors.orange
                    : Colors.red,
              ),
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Text(
              '${(score * 100).toInt()}% Complete',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset exercise to practice again
              setState(() {
                _currentStep = 0;
                _stepsCompleted = List.generate(getTotalSteps(), (index) => false);
                _showHint = false;
              });
            },
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }

  int getTotalSteps() {
    if (widget.exercise.dialogueSteps != null) {
      return widget.exercise.dialogueSteps!.length;
    } else if (widget.exercise.wordExamples != null) {
      return widget.exercise.wordExamples!.length;
    } else {
      return 1; // Default if no steps defined
    }
  }
}