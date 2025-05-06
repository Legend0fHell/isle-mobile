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
  bool _isDisposed = false;
  String _delegateType = "Waiting";
  int _inferenceTime = 0;
  dynamic _currentLandmarks;
  Completer<void>? _initializingCompleter;
  final List<VoidCallback> _pendingListeners = [];

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
  bool get isInitialized => _isInitialized && !_isDisposed;
  dynamic get currentLandmarks => _isDisposed ? null : _currentLandmarks;
  String get delegateType => _isDisposed ? "Disposed" : _delegateType;
  int get inferenceTime => _isDisposed ? 0 : _inferenceTime;

  @override
  void addListener(VoidCallback listener) {
    if (_isDisposed) {
      AppLogger.warn('Attempted to add listener to disposed HandLandmarkService');
      return;
    }
    super.addListener(listener);
    _pendingListeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_isDisposed) {
      return;
    }
    super.removeListener(listener);
    _pendingListeners.remove(listener);
  }

  Future<void> initialize() async {
    // If disposed, reset state for re-initialization
    if (_isDisposed) {
      _isDisposed = false;
      _isInitialized = false;
      _currentLandmarks = null;
      _delegateType = "Waiting";
      _inferenceTime = 0;
      AppLogger.info('Re-initializing previously disposed HandLandmarkService');
    }

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
      _isInitialized = false;
    }

    // Return immediately while initialization continues in background
    return;
  }

  // Actual initialization work, runs in background
  Future<void> _initializeAsync() async {
    // Return immediately if the service was disposed
    if (_isDisposed) return;

    try {
      // Clear previous method handler if any
      _channel.setMethodCallHandler(null);

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

      // Set up a method channel to listen for native calls
      _channel.setMethodCallHandler((MethodCall call) async {
        // Cancel handling if disposed
        if (_isDisposed) return;

        switch (call.method) {
          case 'onLandmarksDetected':
            final result = call.arguments;
            final jsonObject = jsonDecode(result);

            _delegateType = jsonObject['delegate'] as String;
            _inferenceTime = jsonObject['inferenceTime'] as int;
            if (_currentLandmarks == null ||
                _currentLandmarks['landmarks'] != jsonObject['landmarks']) {
              _currentLandmarks = jsonObject;
              
              // Only notify if not disposed
              if (!_isDisposed) {
                notifyListeners();
              }
            }
            break;
          default:
            AppLogger.error('Unknown method called: ${call.method}');
        }
      });

      if (_initializingCompleter != null &&
          !_initializingCompleter!.isCompleted &&
          !_isDisposed) {
        _initializingCompleter!.complete();
      }
    } catch (e) {
      AppLogger.error('Error in background initialization', e);

      if (_initializingCompleter != null &&
          !_initializingCompleter!.isCompleted &&
          !_isDisposed) {
        _initializingCompleter!.completeError(e);
      }
    }
  }

  /// Process a camera image and detect hand landmarks
  /// Returns a HandLandmarks object or null if no hand was detected
  Future<void> processImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) async {
    // Return immediately if the service was disposed or not initialized
    if (_isDisposed || !_isInitialized) {
      return;
    }

    // If we are already processing an image, skip this frame
    if (_isProcessing) {
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
      // Return early if disposed
      if (_isDisposed) return;

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
      // Set processing flag if not disposed
      if (!_isDisposed) {
        _isProcessing = false;
      }
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;  // Prevent multiple disposals
    }

    AppLogger.info('Disposing HandLandmarkService');
    _isDisposed = true;
    _isInitialized = false;
    _currentLandmarks = null;
    
    // Clear all pending listeners to avoid memory leaks
    for (final listener in _pendingListeners) {
      super.removeListener(listener);
    }
    _pendingListeners.clear();
    
    // Complete any pending initialization
    if (_initializingCompleter != null && !_initializingCompleter!.isCompleted) {
      _initializingCompleter!.complete();
    }
    _initializingCompleter = null;
    
    // Stop any in-progress frame processing
    _isProcessing = false;
    
    // Clear method handler to prevent callbacks after disposal
    // Using a try-catch since this sometimes causes issues if the app is closing
    try {
      _channel.setMethodCallHandler(null);
    } catch (e) {
      AppLogger.warn('Failed to clear method handler during disposal: $e');
    }
    
    super.dispose();
  }
}
