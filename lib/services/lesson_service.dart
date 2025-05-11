// lib/services/lesson_service.dart
import 'package:isle/models/lesson_model.dart';
import 'package:isle/services/mongodb_service.dart';
import 'package:isle/utils/logger.dart';

class LessonService {
  // Get a lesson by its ID
  static Future<Lesson?> getLessonById(String lessonId) async {
    try {
      // Ensure MongoDB connection is initialized
      await MongoDBService.initialize();

      // Get lesson data from MongoDB
      final lessonData = await MongoDBService.getLesson(lessonId);

      if (lessonData == null) {
        return null;
      }

      // Convert MongoDB document to Lesson model
      return Lesson.fromMap(lessonData);
    } catch (e) {
      AppLogger.error('Error in getLessonById: $e');
      return null;
    }
  }

  // Get all lessons
  static Future<List<Lesson>> getAllLessons() async {
    try {
      // Ensure MongoDB connection is initialized
      await MongoDBService.initialize();

      // Get the lessons collection
      final lessonsCollection = MongoDBService.getCollection('lessons');

      // Fetch all lessons
      final lessonsCursor = await lessonsCollection.find().toList();

      // Convert MongoDB documents to Lesson models
      return lessonsCursor.map((lessonData) => Lesson.fromMap(lessonData)).toList();
    } catch (e) {
      AppLogger.error('Error in getAllLessons: $e');
      return [];
    }
  }

  // Get lessons by category
  static Future<List<Lesson>> getLessonsByCategory(String category) async {
    try {
      // Ensure MongoDB connection is initialized
      await MongoDBService.initialize();

      // Get the lessons collection
      final lessonsCollection = MongoDBService.getCollection('lessons');

      // Fetch lessons by category
      final lessonsCursor = await lessonsCollection.find({'category': category}).toList();

      // Convert MongoDB documents to Lesson models
      return lessonsCursor.map((lessonData) => Lesson.fromMap(lessonData)).toList();
    } catch (e) {
      AppLogger.error('Error in getLessonsByCategory: $e');
      return [];
    }
  }

  // Get lessons by difficulty level
  static Future<List<Lesson>> getLessonsByLevel(String level) async {
    try {
      // Ensure MongoDB connection is initialized
      await MongoDBService.initialize();

      // Get the lessons collection
      final lessonsCollection = MongoDBService.getCollection('lessons');

      // Fetch lessons by difficulty level
      final lessonsCursor = await lessonsCollection.find({'level': level}).toList();

      // Convert MongoDB documents to Lesson models
      return lessonsCursor.map((lessonData) => Lesson.fromMap(lessonData)).toList();
    } catch (e) {
      AppLogger.error('Error in getLessonsByLevel: $e');
      return [];
    }
  }
}