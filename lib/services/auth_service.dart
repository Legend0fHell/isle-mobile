// lib/services/auth_service.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mongodb_service.dart';

class AuthService {
  static const String _usersCollection = 'users';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Hash password using SHA-256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // User registration
  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    try {
      await MongoDBService.initialize();
      final collection = MongoDBService.getCollection(_usersCollection);

      // Check if user already exists
      final existingUser = await collection.findOne(where.eq('email', email));
      if (existingUser != null) {
        return {
          'success': false,
          'message': 'User with this email already exists'
        };
      }

      // Create new user
      final user = {
        'email': email,
        'password': _hashPassword(password),
        'name': name,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await collection.insert(user);

      if (result["isSuccess"]) {
        return {
          'success': true,
          'message': 'User registered successfully',
          'userId': result["_id"]
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to register user'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration error: $e'
      };
    }
  }

  // User login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      await MongoDBService.initialize();
      final collection = MongoDBService.getCollection(_usersCollection);

      // Find user by email
      final user = await collection.findOne(where.eq('email', email));

      if (user == null) {
        return {
          'success': false,
          'message': 'User not found'
        };
      }

      // Verify password
      final hashedPassword = _hashPassword(password);
      if (user['password'] != hashedPassword) {
        return {
          'success': false,
          'message': 'Invalid password'
        };
      }

      // Generate a simple token (in a real app, use JWT or other secure token method)
      final token = base64Encode(utf8.encode('${user['_id']}:${DateTime.now().millisecondsSinceEpoch}'));

      // Save token to secure storage
      await _secureStorage.write(key: _tokenKey, value: token);
      await _secureStorage.write(key: _userIdKey, value: user['_id'].toString());

      return {
        'success': true,
        'message': 'Login successful',
        'user': {
          'id': user['_id'],
          'email': user['email'],
          'name': user['name'],
        }
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login error: $e'
      };
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      return token != null;
    } catch (e) {
      return false;
    }
  }

  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userId = await _secureStorage.read(key: _userIdKey);
      if (userId == null) return null;

      await MongoDBService.initialize();
      final collection = MongoDBService.getCollection(_usersCollection);

      final user = await collection.findOne(where.eq('_id', ObjectId.parse(userId)));
      if (user == null) return null;

      return {
        'id': user['_id'],
        'email': user['email'],
        'name': user['name'],
      };
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userIdKey);
    } catch (e) {
      print('Error during logout: $e');
    }
  }
}