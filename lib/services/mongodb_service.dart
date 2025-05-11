// lib/services/mongodb_service.dart
import 'package:isle/utils/logger.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoDBService {
  static late Db _db;
  static bool _isInitialized = false;

  // Initialize MongoDB connection
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load environment variables from .env file
      await dotenv.load();

      // Get MongoDB URI from environment variables
      final mongoUri =
          dotenv.env['MONGODB_URI'] ??
              'mongodb://localhost:27017/sign_language_app';

      _db = await Db.create(mongoUri);
      await _db.open();
      _isInitialized = true;
      AppLogger.info('Connected to MongoDB');
    } catch (e) {
      AppLogger.error('Failed to connect to MongoDB: $e');
      throw Exception('Failed to connect to MongoDB: $e');
    }
  }

  // Close the database connection
  static Future<void> close() async {
    if (_isInitialized) {
      await _db.close();
      _isInitialized = false;
      AppLogger.info('Disconnected from MongoDB');
    }
  }

  // Get a specific collection
  static DbCollection getCollection(String collectionName) {
    if (!_isInitialized) {
      throw Exception('MongoDB not initialized. Call initialize() first.');
    }
    return _db.collection(collectionName);
  }

  // Get user profile from MongoDB
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final usersCollection = getCollection('users');
      final objectId = ObjectId.parse(userId); // Convert string to ObjectId
      final userData = await usersCollection.findOne({'_id': objectId});

      return userData;
    } catch (e) {
      AppLogger.info('Error getting user profile: $e');
      return null;
    }
  }

// Update user profile in MongoDB
  static Future<bool> updateUserProfile(String userId, Map<String, dynamic> updatedData) async {
    try {
      final usersCollection = getCollection('users');
      final objectId = ObjectId.parse(userId); // Convert string to ObjectId

      // Check if the updated email is already taken by another user
      if (updatedData.containsKey('email')) {
        final existingUser = await usersCollection.findOne({
          'email': updatedData['email'],
          '_id': {'\$ne': objectId}  // not the current user
        });

        if (existingUser != null) {
          AppLogger.info('Email already in use by another user.');
          throw Exception('Email is already in use by another user.');
        }
      }

      // Perform the update
      await usersCollection.updateOne(
        {'_id': objectId},
        {'\$set': updatedData},
      );

      return true;
    } catch (e) {
      AppLogger.info('Error updating user profile: $e');
      rethrow;
    }
  }

  // Get lesson by ID from MongoDB
  static Future<Map<String, dynamic>?> getLesson(String lessonId) async {
    try {
      final lessonsCollection = getCollection('lessons');
      final objectId = ObjectId.parse(lessonId); // Convert string to ObjectId
      final lessonData = await lessonsCollection.findOne({'_id': objectId});

      if (lessonData == null) {
        AppLogger.info('Lesson not found with ID: $lessonId');
        return null;
      }

      return lessonData;
    } catch (e) {
      AppLogger.error('Error getting lesson: $e');
      return null;
    }
  }
}