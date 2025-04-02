import 'package:flutter/foundation.dart';

/// A utility class for logging messages throughout the app
/// Helps avoid the use of print() statements which trigger lint warnings
class AppLogger {
  static void info(String message) {
    _log('INFO', message);
  }

  static void warn(String message) {
    _log('WARN', message);
  }

  static void error(String message, [dynamic e]) {
    _log('ERROR', message + (e != null ? ': $e' : ''));
  }

  static void debug(String message) {
    _log('DEBUG', message);
  }

  static void _log(String level, String message) {
    // Only log in debug mode
    if (kDebugMode) {
      debugPrint('[$level] $message');
    }
  }
} 