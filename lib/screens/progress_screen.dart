import 'package:flutter/material.dart';

import '../services/lesson_service.dart'; // Import the LessonService
import '../services/mongodb_service.dart';
import '../widgets/progress_card_widget.dart';
import '../widgets/calendar_widget.dart';
import '../models/lesson_model.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  DateTime _selectedMonth = DateTime.now();
  // Sample active days for demonstration (in a real app, this would come from a database)
  Set<DateTime> _activeDays = {};

  // Track lesson completion metrics
  int _completedLessons = 0;
  int _totalLessons = 0;
  int _completionPercentage = 0;

  // Track number of practice sessions
  int _practiceSessions = 0;

  //

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  // Load lesson data from the LessonService
  Future<void> _loadLessonData() async {
    try {
      final lessons = await LessonService.getAllLessons(context);

      // Count completed lessons (where status is 'completed')
      int completed = lessons.where((lesson) => lesson.getProgress() == 1.0).length;
      int total_practices = 0;
      for (var i=0; i<lessons.length; i++) {
        for (var eachContent in lessons[i].content) {
          if (eachContent.type == LessonContentType.practice
              && eachContent.status == LessonContentStatus.finished) {
            total_practices += 1;
          }
        };
      }

      // Retrieve the dates
      final progressCollection = await MongoDBService.getProgressCurrentUser(context);
      Map<DateTime, int> dateCount = {};

      for (var entry in progressCollection) {
        DateTime fullDate = entry['finished_at'];
        DateTime justDate = DateTime(fullDate.year, fullDate.month, fullDate.day);

        dateCount.update(justDate, (count) => count + 1, ifAbsent: () => 1);
      }

      print("DATE COUNT");
      print(dateCount);

      // Step 2: Get dates that appear 3 or more times
      Set<DateTime> frequentDates = dateCount.entries
          .where((entry) => entry.value >= 3)
          .map((entry) => entry.key)
          .toSet();

      print("FREQUENT DATES");
      print(frequentDates);

      setState(() {
        _completedLessons = completed;
        _totalLessons = lessons.length;
        _completionPercentage = _totalLessons > 0
            ? (_completedLessons * 100 ~/ _totalLessons)  // Calculate percentage and round to int
            : 0;
        _practiceSessions = total_practices;
        _activeDays = frequentDates;
      });
    } catch (error) {
      debugPrint('Error loading lesson data: $error');
      // Handle error - perhaps show a snackbar or error message
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
    });
  }

  bool _isActiveDay(DateTime date) {
    for (final activeDay in _activeDays) {
      if (activeDay.year == date.year &&
          activeDay.month == date.month &&
          activeDay.day == date.day) {
        return true;
      }
    }
    return false;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Progress', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Learning Progress',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                ProgressCard(
                  title: 'Lessons Completed',
                  value: '$_completedLessons/$_totalLessons',
                  percentage: _completionPercentage,
                ),
                const SizedBox(height: 20),
                ProgressCard(title: 'Practice Sessions', value: '$_practiceSessions'),
                const SizedBox(height: 20),
                StreakCard(activeDays: _activeDays),
                const SizedBox(height: 20),
                PracticeCalendar(
                  selectedMonth: _selectedMonth,
                  activeDays: _activeDays,
                  onPreviousMonth: _previousMonth,
                  onNextMonth: _nextMonth,
                  isActiveDay: _isActiveDay,
                  isToday: _isToday,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}