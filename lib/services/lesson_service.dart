// lib/services/lesson_service.dart
import 'package:flutter/material.dart';
import 'package:isle/models/lesson_model.dart';
import 'package:isle/services/mongodb_service.dart';
import 'package:isle/utils/logger.dart';
import 'package:bson/bson.dart';

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

  static Future<List<Lesson>> getAllLessons(BuildContext context) async {
    try {
      await MongoDBService.initialize();

      final lessonsCollection = await MongoDBService.getCollection('lessons');
      final lessonContentsCollection = await MongoDBService.getCollection('lessoncontents');
      final progressCollection = await MongoDBService.getProgressCurrentUser(context); // e.g., [{ lesson_id, finished_at }]

      final lessonsCursor = await lessonsCollection.find().toList();
      final lessonContentsCursor = await lessonContentsCollection.find().toList();

      // Extract finished content IDs from progress
      final finishedContentIds = progressCollection
          .map((entry) => entry['lesson_id'] as ObjectId)
          .toSet();

      // Mark each content as 'finished' or 'incomplete' and group by lessonId
      final contentsByLessonId = <ObjectId, List<Map<String, dynamic>>>{};
      for (var content in lessonContentsCursor) {
        final lessonId = content['lessonId'] as ObjectId;
        final contentId = content['_id'] as ObjectId;

        content['status'] = finishedContentIds.contains(contentId)
            ? LessonContentStatus.finished
            : LessonContentStatus.incomplete;

        contentsByLessonId.putIfAbsent(lessonId, () => []).add(content);
      }

      // Assemble the final lesson list
      final lessonFinal = lessonsCursor.map((lesson) {
        final lessonId = lesson['_id'] as ObjectId;
        final lessonContents = contentsByLessonId[lessonId] ?? [];

        return {
          ...lesson,
          'content': lessonContents,
        };
      }).toList();

      lessonFinal.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      print("LESSON FINAL");
      print(lessonFinal);

      // throw Exception("test");

      return lessonFinal.map((lessonData) => Lesson.fromMap(lessonData)).toList();
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