import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// import '../models/recognition_model.dart';
import '../utils/logger.dart';
import '../utils/img_convert.dart';

// Global instance - singleton to ensure consistent state across the app
final handLandmarkService = HandLandmarkService._internal();

// Class for passing data to the isolate
class _ProcessImageParams {
  final CameraImage image;
  final CameraDescription cameraDescription;
  final RootIsolateToken rootIsolateToken;
  final int rotation;

  _ProcessImageParams({
    required this.image,
    required this.cameraDescription,
    required this.rootIsolateToken,
    required this.rotation,
  });
}

Future<Map<String, dynamic>> _processImageInIsolate(
  _ProcessImageParams params,
) async {
  // Ensure Platform Channel bindings are initialized for this isolate
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

  try {
    // Initialize the method channel for communicating with the native code
    const MethodChannel channel = MethodChannel('com.uet.isle/hand_landmark');

    // Get image and parameters from params
    final CameraImage image = params.image;
    final imageBytes = await convertImage(image, rotation: params.rotation);

    // Call the native method
    final result = await channel.invokeMethod('detectLandmarks', {
      'imageBytes': imageBytes,
    });

    if (result == "failed") {
      AppLogger.error('Error occured in native code.');
      return {'success': false};
    }
    return {'success': true};
  } catch (e) {
    AppLogger.error('Error in _processImageInIsolate: $e');
    return {'success': false};
  }
}

int _getRotation(CameraDescription camera) {
  switch (camera.sensorOrientation) {
    case 0:
      return 0;
    case 90:
      return 90;
    case 180:
      return 180;
    case 270:
      return 270;
    default:
      return 0;
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
  dynamic _currentLandmarks;
  Completer<void>? _initializingCompleter;

  // --- Rate Limiting Members ---
  DateTime _lastProcessedTime = DateTime.now();
  static const Duration _minimumProcessingInterval = Duration(
    milliseconds: 200,
  );
  bool _isProcessing = false;
  // ---------------------------

  // The name of the model file
  static const String modelFilename = 'hand_landmarker.task';

  // Getters
  bool get isInitialized => _isInitialized;
  dynamic get currentLandmarks => _currentLandmarks;

  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) return;

    // If currently initializing, wait for that to complete
    if (_initializingCompleter != null) {
      return _initializingCompleter!.future;
    }

    // Create a new completer for this initialization
    _initializingCompleter = Completer<void>();

    try {
      // Run initialization in background
      unawaited(_initializeAsync());

      // Always allow the app to proceed immediately
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('Error initializing HandLandmarkService', e);
      _isInitialized = true;
    }

    // Return immediately while initialization continues in background
    return;
  }

  // Actual initialization work, runs in background
  Future<void> _initializeAsync() async {
    try {
      // Prepare the asset file for the native side
      final assetPath = 'assets/models/$modelFilename';

      AppLogger.info('Looking for model at: $assetPath');

      try {
        final result = await _channel.invokeMethod('prepareAssetFile', {
          'assetPath': assetPath,
          'fileName': modelFilename,
        });

        AppLogger.info('MediaPipe model prepared at: $result');
      } catch (e) {
        AppLogger.error('Error preparing MediaPipe model: $e');
      }

      if (_initializingCompleter != null &&
          !_initializingCompleter!.isCompleted) {
        _initializingCompleter!.complete();
      }
    } catch (e) {
      AppLogger.error('Error in background initialization', e);

      if (_initializingCompleter != null &&
          !_initializingCompleter!.isCompleted) {
        _initializingCompleter!.completeError(e);
      }
    }

    // Set up a method channel to listen for native calls
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onLandmarksDetected':
          final result = call.arguments;
          final jsonObject = jsonDecode(result);

          if (_currentLandmarks != jsonObject) {
            _currentLandmarks = jsonObject;
            notifyListeners();
          }
          // _channel.invokeMethod('onLandmarksDetectedUI', {
          //   'result': jsonObject,
          // });
          break;
        default:
          AppLogger.error('Unknown method called: ${call.method}');
      }
    });
  }

  /// Process a camera image and detect hand landmarks
  /// Returns a HandLandmarks object or null if no hand was detected
  Future<void> processImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) async {
    // If we are already processing an image, or haven't initialized yet, skip this frame
    if (_isProcessing || !_isInitialized) {
      return;
    }

    // Rate limiting - only process every X milliseconds
    final now = DateTime.now();
    if (now.difference(_lastProcessedTime) < _minimumProcessingInterval) {
      return;
    }

    _lastProcessedTime = now;
    _isProcessing = true;

    try {
      final token = RootIsolateToken.instance;
      if (token == null) {
        AppLogger.error("Could not get RootIsolateToken");
        return;
      }

      // We're using a fixed size square in the UI, but for processing
      // we need to pass the full image from the camera and let the native
      // code handle any necessary cropping/scaling
      await compute(
        _processImageInIsolate,
        _ProcessImageParams(
          image: image,
          cameraDescription: cameraDescription,
          rootIsolateToken: token,
          rotation: _getRotation(cameraDescription),
        ),
      );
    } catch (e) {
      AppLogger.error('Error processing image for hand landmarks', e);
      return;
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _isInitialized = false;
    _currentLandmarks = null;
    _initializingCompleter = null;
    super.dispose();
  }
}
