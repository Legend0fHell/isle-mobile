import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Widget for displaying the practice calendar
class PracticeCalendar extends StatelessWidget {
  final DateTime selectedMonth;
  final Set<DateTime> activeDays;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool Function(DateTime) isActiveDay;
  final bool Function(DateTime) isToday;

  const PracticeCalendar({
    super.key,
    required this.selectedMonth,
    required this.activeDays,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.isActiveDay,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practice Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildMonthNavigator(),
          const SizedBox(height: 15),
          _buildCalendarGrid(context),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: onPreviousMonth,
        ),
        Text(
          DateFormat('MMMM yyyy').format(selectedMonth),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: onNextMonth,
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    // Get the first day of the month
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);

    // Get the day of week (0 = Monday, 6 = Sunday in DateTime, but we want 0 = Sunday)
    int firstDayIndex = firstDay.weekday % 7;

    // Get the number of days in the month
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

    // Calculate responsive day cell size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 40; // Account for the 20px padding on each side
    final calendarInnerWidth = availableWidth - 30; // Account for container padding
    final cellSize = (calendarInnerWidth / 7).floor() - 4; // Divide by 7 days, account for spacing

    // Create calendar days
    List<Widget> dayWidgets = [];

    // Add day of week headers using DayOfWeekCell widget
    const daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (final day in daysOfWeek) {
      dayWidgets.add(
        DayOfWeekCell(day: day, cellSize: cellSize),
      );
    }

    // Add empty boxes for days before the first day of the month
    for (int i = 0; i < firstDayIndex; i++) {
      dayWidgets.add(SizedBox(width: cellSize.toDouble(), height: cellSize.toDouble()));
    }

    // Add all days of the month using CalendarDayCell widget
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(selectedMonth.year, selectedMonth.month, day);
      dayWidgets.add(
        CalendarDayCell(
          day: day,
          cellSize: cellSize,
          isActive: isActiveDay(currentDate),
          isToday: isToday(currentDate),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: dayWidgets,
    );
  }
}

// Widget for displaying day of week header cell
class DayOfWeekCell extends StatelessWidget {
  final String day;
  final int cellSize;

  const DayOfWeekCell({
    super.key,
    required this.day,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cellSize.toDouble(),
      height: cellSize.toDouble(),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            day,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for displaying calendar day cell
class CalendarDayCell extends StatelessWidget {
  final int day;
  final int cellSize;
  final bool isActive;
  final bool isToday;

  const CalendarDayCell({
    super.key,
    required this.day,
    required this.cellSize,
    required this.isActive,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cellSize.toDouble(),
      height: cellSize.toDouble(),
      child: Center(
        child: Container(
          width: cellSize * 0.8,
          height: cellSize * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.red.withOpacity(0.3) : Colors.transparent,
            border: isToday
                ? Border.all(color: Colors.white, width: 1)
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isActive ? Colors.red : Colors.white,
                  fontWeight: isActive || isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for displaying streak information
class StreakCard extends StatelessWidget {
  final Set<DateTime> activeDays;

  const StreakCard({
    super.key,
    required this.activeDays,
  });

  // Calculate the current streak based on active days
  int _calculateCurrentStreak() {
    if (activeDays.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if user is active today
    bool isActiveToday = activeDays.any((date) =>
    date.year == todayDate.year &&
        date.month == todayDate.month &&
        date.day == todayDate.day
    );

    // Start counting from yesterday if not active today
    int streak = isActiveToday ? 1 : 0;
    int currentDay = 0;

    while (true) {
      currentDay++;
      final checkDate = todayDate.subtract(Duration(days: currentDay));

      final isActive = activeDays.any((date) =>
      date.year == checkDate.year &&
          date.month == checkDate.month &&
          date.day == checkDate.day
      );

      if (isActive) {
        streak = streak == 0 ? 1 : streak + 1;
      } else if (streak > 0 || currentDay > 30) {
        // Break if streak is broken or we checked back too far
        break;
      }
    }

    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final days = _calculateCurrentStreak();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.orange,
            size: 40,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Streak',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '$days days',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
