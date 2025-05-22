import 'package:flutter/material.dart';

class NotificationCard extends StatefulWidget {
  final String title;
  final String message;
  final DateTime timestamp;
  final String? type;
  final VoidCallback? onTap;
  final bool initialIsRead;
  final Color? backgroundColor;
  final Color? readBackgroundColor;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type,
    this.onTap,
    this.initialIsRead = false,
    this.backgroundColor,
    this.readBackgroundColor,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  late bool isRead;

  @override
  void initState() {
    super.initState();
    isRead = widget.initialIsRead;
  }

  void _handleTap() {
    setState(() {
      isRead = true;
    });
    widget.onTap?.call();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getNotificationIcon() {
    switch (widget.type) {
      case 'practice_reminder':
        return Icons.alarm;
      case 'daily_goal_reached':
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationIconColor() {
    switch (widget.type) {
      case 'practice_reminder':
        return Colors.orange.shade400;
      case 'daily_goal_reached':
        return Colors.green.shade400;
      default:
        return Colors.blue.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isRead
        ? (widget.readBackgroundColor ?? Colors.grey.shade800)
        : (widget.backgroundColor ?? Colors.grey.shade900);

    return Card(
      color: cardColor,
      margin: widget.margin,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: widget.padding!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Notification type icon
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: _getNotificationIconColor().withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getNotificationIcon(),
                      color: _getNotificationIconColor(),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Unread indicator
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.fade,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTimestamp(widget.timestamp),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}