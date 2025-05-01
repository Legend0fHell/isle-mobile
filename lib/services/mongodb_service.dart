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
}
