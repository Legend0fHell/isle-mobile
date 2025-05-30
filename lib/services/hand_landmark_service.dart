import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// import '../models/recognition_model.dart';
import '../utils/logger.dart';
import '../utils/img_convert.dart';

// Global instance - singleton to ensure consistent state across the app
final handLandmarkService = HandLandmarkService._internal();

// Only used for real device processing
class _ProcessImageParams {
  final CameraImage image;
  final int rotation;
  final RootIsolateToken rootIsolateToken;

  _ProcessImageParams({
    required this.image,
    required this.rotation,
    required this.rootIsolateToken,
  });
}

// Only used for real device processing
Future<Map<String, dynamic>> _processImageInIsolate(
  _ProcessImageParams params,
) async {
  try {
    // Initialize the isolate bindings
    BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

    // Try to convert the image - if it fails, return error
    final imageBytes = await convertImage(params.image, rotation: params.rotation);
    if (imageBytes.isEmpty) {
      return {'success': false, 'error': 'Failed to convert image'};
    }

    // Create a new method channel for this isolate
    const MethodChannel channel = MethodChannel('com.uet.isle/hand_landmark');
    
    // Call the native method
    final result = await channel.invokeMethod('detectLandmarks', {
      'imageBytes': imageBytes,
    }).timeout(const Duration(seconds: 5));
      
    if (result == "failed") {
      throw Exception('Native code error');
    }

    return {'success': true};
  } catch (e) {
    AppLogger.error('Error in _processImageInIsolate: $e');
    return {'success': false, 'error': e.toString()};
  }
}

class HandLandmarkService extends ChangeNotifier {
  // Private constructor
  HandLandmarkService._internal();

  // Factory constructor that returns the global instance
  factory HandLandmarkService() {
    return handLandmarkService;
  }

  static const MethodChannel _channel = MethodChannel(
    'com.uet.isle/hand_landmark',
  );

  bool _isInitialized = false;
  bool _isDisposed = false;
  String _delegateType = "Waiting";
  int _inferenceTime = 0;
  dynamic _currentLandmarks;
  bool _isEmulatorMode = false;
  bool _isProcessing = false;

  // Getters
  bool get isInitialized => _isInitialized && !_isDisposed;
  dynamic get currentLandmarks => _isDisposed ? null : _currentLandmarks;
  String get delegateType => _isDisposed ? "Disposed" : _delegateType;
  int get inferenceTime => _isDisposed ? 0 : _inferenceTime;
  bool get isEmulatorMode => _isEmulatorMode;

  Future<void> initialize() async {
    // If disposed, reset state
    if (_isDisposed) {
      _isDisposed = false;
      _isInitialized = false;
      _currentLandmarks = null;
      _delegateType = "Waiting";
      _inferenceTime = 0;
    }

    _isEmulatorMode = dotenv.env['EMU_SUPPORT'] == 'true';
    
    // If in emulator mode, we're done - no need to initialize native code
    if (_isEmulatorMode) {
      AppLogger.info('HandLandmarkService (Stage1) initializing in mock output -- all outputs are random!');
      _isInitialized = true;
      _delegateType = "Emulator";
      return;
    }

    // Only gets here if NOT in emulator mode
    
    // Set up a method channel to listen for native calls
    _channel.setMethodCallHandler((MethodCall call) async {
      if (_isDisposed) return;

      if (call.method == 'onLandmarksDetected') {
        final result = call.arguments as String;
        _processLandmarkResult(result);
      }
    });

    // Prepare the asset file for the native side (model file)
    try {
      const assetPath = 'assets/models/hand_landmarker.task';
      final result = await _channel.invokeMethod('prepareAssetFile', {
        'assetPath': assetPath,
        'fileName': 'hand_landmarker.task',
      });
      AppLogger.info('MediaPipe model prepared at: $result');
    } catch (e) {
      AppLogger.error('Error preparing MediaPipe model: $e');
    }

    _isInitialized = true;
    return;
  }
  
  // Process the landmark results from native side
  void _processLandmarkResult(String result) {
    if (_isDisposed) return;
    
    try {
      final jsonObject = jsonDecode(result);

      _delegateType = jsonObject['delegate'] as String;
      _inferenceTime = jsonObject['inferenceTime'] as int;
      
      if (_currentLandmarks == null ||
          _currentLandmarks['landmarks'] != jsonObject['landmarks']) {
        _currentLandmarks = jsonObject;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error processing landmark result: $e');
    }
  }

  /// Process a camera image and detect hand landmarks
  Future<void> processImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) async {
    // Return immediately if the service was disposed, not initialized, or already processing
    if (_isDisposed || !_isInitialized || _isProcessing) {
      return;
    }

    // Set processing flag to prevent concurrent processing
    _isProcessing = true;

    try {
      // Emulator mode is much simpler - just generate random landmarks
      if (isEmulatorMode) {
        _generateMockLandmarks();
        return;
      }
      
      // Real device mode uses isolate and native code
      final token = RootIsolateToken.instance;
      if (token == null) {
        AppLogger.error("Could not get RootIsolateToken");
        return;
      }
      
      // Process in isolate to avoid blocking the UI
      final result = await compute(
        _processImageInIsolate,
        _ProcessImageParams(
          image: image,
          rotation: _getRotationAngle(cameraDescription),
          rootIsolateToken: token,
        ),
      );
      
      if (result['success'] == false) {
        AppLogger.warn('Error processing image: ${result['error']}');
      }
    } catch (e) {
      AppLogger.error('Error in processImage: $e');
    } finally {
      if (!_isDisposed) {
        _isProcessing = false;
      }
    }
  }

  // Generate simple mock hand landmarks with random values
  void _generateMockLandmarks() {
    try {
      final random = math.Random();
      final landmarks = <Map<String, dynamic>>[];
      
      // Create 21 landmarks with random positions
      for (int i = 0; i < 21; i++) {
        landmarks.add({
          'index': i,
          'x': random.nextDouble(),  // Between 0.0 and 1.0
          'y': random.nextDouble(),  // Between 0.0 and 1.0
          'z': random.nextDouble() * 0.2,  // Smaller Z values
        });
      }
      
      final mockResult = {
        'delegate': 'Emulator',
        'inferenceTime': 5,
        'landmarks': landmarks,
        'isLeftHand': random.nextBool(),
      };
      
      _delegateType = mockResult['delegate'] as String;
      _inferenceTime = mockResult['inferenceTime'] as int;
      _currentLandmarks = mockResult;
      
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error generating mock landmarks: $e');
    }
  }
  
  // Helper to get the rotation angle
  int _getRotationAngle(CameraDescription camera) {
    return camera.sensorOrientation;
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _isInitialized = false;
    _currentLandmarks = null;
    
    try {
      _channel.setMethodCallHandler(null);
    } catch (e) {
      // Ignore errors during disposal
    }
    
    super.dispose();
  }
}
