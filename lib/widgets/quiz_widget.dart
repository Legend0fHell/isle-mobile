import 'package:flutter/material.dart';
import '../models/lesson_model.dart';

class QuizWidget extends StatefulWidget {
  final List<Question>? questions;
  final Function(double) onComplete;

  const QuizWidget({
    Key? key,
    required this.questions,
    required this.onComplete,
  }) : super(key: key);

  @override
  _QuizWidgetState createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  List<bool> _answers = [];
  bool _quizCompleted = false;
  bool _answerSubmitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.questions != null) {
      _answers = List.filled(widget.questions!.length, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions == null || widget.questions!.isEmpty) {
      return const Center(
        child: Text('No quiz questions available'),
      );
    }

    if (_quizCompleted) {
      return _buildQuizResults();
    }

    final currentQuestion = widget.questions![_currentQuestionIndex];

    return SafeArea(
      child: Column(
        children: [
          // Fixed header area with progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question progress
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / widget.questions!.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 8,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Question ${_currentQuestionIndex + 1} of ${widget.questions!.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        currentQuestion.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Question image if available
                    if (currentQuestion.imageUrl != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.asset(
                            currentQuestion.imageUrl!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                    // Options - wrapped in a column that doesn't overflow
                    ...List.generate(
                      currentQuestion.options.length,
                          (index) => _buildOptionItem(index, currentQuestion),
                    ),

                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          ),

          // Fixed footer area with navigation buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // First row: Previous and Submit buttons
                Row(
                  children: [
                    // Previous button
                    if (_currentQuestionIndex > 0)
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _currentQuestionIndex--;
                              _selectedOptionIndex = null;
                              _answerSubmitted = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: const Text(
                            'Previous',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),

                    if (_currentQuestionIndex > 0) const SizedBox(width: 12),

                    // Submit button
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: _selectedOptionIndex == null || _answerSubmitted
                            ? null
                            : _checkAnswer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                // Second row: Next/Finish button (only visible after submitting)
                if (_answerSubmitted) ...[
                  const SizedBox(height: 12.0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (_currentQuestionIndex < widget.questions!.length - 1) {
                            _currentQuestionIndex++;
                            _selectedOptionIndex = null;
                            _answerSubmitted = false;
                          } else {
                            _quizCompleted = true;
                            _calculateAndSubmitScore();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      child: Text(
                        _currentQuestionIndex < widget.questions!.length - 1
                            ? 'Next Question'
                            : 'Finish Quiz',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(int index, Question question) {
    final isImage = question.options[index].endsWith('.jpg') ||
        question.options[index].endsWith('.png') ||
        question.options[index].endsWith('.gif');

    final isCorrect = index == question.correctOptionIndex;

    Color? backgroundColor;
    if (_answerSubmitted) {
      backgroundColor = isCorrect ? Colors.green[100] :
      (_selectedOptionIndex == index ? Colors.red[100] : null);
    } else {
      backgroundColor = _selectedOptionIndex == index ? Colors.blue[50] : null;
    }

    return GestureDetector(
      onTap: _answerSubmitted ? null : () {
        setState(() {
          _selectedOptionIndex = index;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: _answerSubmitted
                ? (isCorrect ? Colors.green : (_selectedOptionIndex == index ? Colors.red : Colors.grey))
                : (_selectedOptionIndex == index ? Colors.blue : Colors.grey),
            width: _selectedOptionIndex == index ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: isImage
            ? ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: Image.asset(
            question.options[index],
            fit: BoxFit.contain,
          ),
        )
            : Text(
          question.options[index],
          style: TextStyle(
            fontSize: 16,
            fontWeight: _selectedOptionIndex == index
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _checkAnswer() {
    if (_selectedOptionIndex == null) return;

    setState(() {
      _answerSubmitted = true;
      _answers[_currentQuestionIndex] =
          _selectedOptionIndex == widget.questions![_currentQuestionIndex].correctOptionIndex;
    });
  }

  void _calculateAndSubmitScore() {
    final correctAnswers = _answers.where((answer) => answer).length;
    final totalQuestions = widget.questions!.length;
    final score = (correctAnswers / totalQuestions) * 100;

    widget.onComplete(score);
  }

  Widget _buildQuizResults() {
    final correctAnswers = _answers.where((answer) => answer).length;
    final totalQuestions = widget.questions!.length;
    final score = (correctAnswers / totalQuestions) * 100;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80.0,
              ),
              const SizedBox(height: 24.0),
              const Text(
                'Quiz Completed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Your Score: ${score.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                '$correctAnswers out of $totalQuestions questions correct',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentQuestionIndex = 0;
                    _selectedOptionIndex = null;
                    _quizCompleted = false;
                    _answerSubmitted = false;
                    _answers = List.filled(widget.questions!.length, false);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                ),
                child: const Text('Retry Quiz'),
              ),
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Back to Lessons'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}