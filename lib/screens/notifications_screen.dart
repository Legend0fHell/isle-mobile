import 'package:flutter/material.dart';
import '../widgets/notification_card_widget.dart'; // Import your NotificationCard widget
import '../services/mongodb_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Set<DateTime> practicedDates = {};
  DateTime createdDate = DateTime.now();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final practiced_dates = await _getDailyGoalReachedDates();
      final created_date = await _getCreatedDate();
      setState(() {
        practicedDates = practiced_dates;
        createdDate = created_date;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading lessons: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Extract daily goal reached notifications based on lessons data
  Future<Set<DateTime>> _getDailyGoalReachedDates() async {
    // Example logic: Check if user completed lessons today
    final progressCollection = await MongoDBService.getProgressCurrentUser(context);
    Map<DateTime, int> dateCount = {};

    for (var entry in progressCollection) {
      DateTime fullDate = entry['finished_at'];
      DateTime justDate = DateTime(fullDate.year, fullDate.month, fullDate.day);

      dateCount.update(justDate, (count) => count + 1, ifAbsent: () => 1);
    };

    Set<DateTime> frequentDates = dateCount.entries
        .where((entry) => entry.value >= 3)
        .map((entry) => entry.key)
        .toSet();

    return frequentDates;
  }

  Future<DateTime> _getCreatedDate() async {
    final userProfile = await MongoDBService.getUserProfile(context);

    return DateTime.parse(userProfile?["created_at"]);
  }

  // Generate practice reminder notifications
  List<NotificationCard> _generatePracticeReminders() {
    List<NotificationCard> reminders = [];
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
    DateTime currentDate = DateTime(now.year, now.month, now.day);

    // Calculate days since account creation
    int daysSinceCreation = currentDate.difference(startDate).inDays;

    for (int i = 0; i <= daysSinceCreation; i++) {
      DateTime reminderDate = startDate.add(Duration(days: i));
      DateTime notificationTime;

      // For the first day (creation day), use the actual creation time
      if (i == 0) {
        notificationTime = createdDate;
      } else {
        // For subsequent days, set to 12:00 AM (midnight)
        notificationTime = DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 0, 0);
      }

      reminders.add(
        NotificationCard(
          title: 'Practice Reminder',
          initialIsRead: i != daysSinceCreation,
          message: 'Time to practice! Keep up your learning streak.',
          timestamp: notificationTime,
          type: 'practice_reminder',
        ),
      );
    }

    return reminders;
  }

  // Generate daily goal reached notifications
  List<NotificationCard> _generateDailyGoalNotifications() {
    List<NotificationCard> notifications = [];
    DateTime today = DateTime.now();

    for (DateTime practiceDate in practicedDates) {

      bool isSameDate = practiceDate.year == today.year &&
          practiceDate.month == today.month &&
          practiceDate.day == today.day;

      notifications.add(
        NotificationCard(
          title: 'Daily Goal Reached',
          initialIsRead: !isSameDate,
          message: 'Congratulations! You\'ve completed your daily practice goal.',
          timestamp: practiceDate,
          type: 'daily_goal_reached',
        ),
      );
    }

    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: _getAllNotifications(),
      ),
    );
  }

  // Get all notifications sorted by timestamp
  List<Widget> _getAllNotifications() {
    List<NotificationCard> allNotifications = [
      ..._generatePracticeReminders(),
      ..._generateDailyGoalNotifications(),
    ];

    // Sort notifications by timestamp (most recent first)
    allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return allNotifications.cast<Widget>();
  }
}