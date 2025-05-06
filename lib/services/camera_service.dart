import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/logger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isSwitchingCamera = false;

  final StreamController<CameraImage> _imageStreamController =
      StreamController<CameraImage>.broadcast();
  Stream<CameraImage> get imageStream => _imageStreamController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        throw CameraException(
          'No cameras available',
          'No cameras were found on this device',
        );
      }

      // Initialize with the front camera by default
      await _initializeCameraController(
        _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        ),
      );

      _isInitialized = true;
      AppLogger.info('CameraService initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing CameraService: $e');
      _isInitialized = false;
    }
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
    // Store whether we were streaming before for later restoration
    final wasStreaming = _controller?.value.isStreamingImages ?? false;
    
    // Properly dispose of the previous controller
    if (_controller != null) {
      // Stop streaming first if needed
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      
      // Dispose the controller and wait for it to complete
      await _controller!.dispose();
      _controller = null;
    }

    try {
      // Create a camera controller with medium resolution preset
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Initialize the camera and wait for it to complete
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // Restore streaming if it was active before
      if (wasStreaming) {
        await _controller!.startImageStream((CameraImage image) {
          if (!_imageStreamController.isClosed) {
            _imageStreamController.add(image);
          }
        });
      }

      // Log the actual camera resolution for debugging
      final size = _controller!.value.previewSize;
      if (size != null) {
        AppLogger.info(
          'Camera initialized with resolution: ${size.width.toInt()}x${size.height.toInt()}',
        );
      }
    } catch (e) {
      AppLogger.error('Error initializing camera controller: $e');
      // Rethrow to allow proper handling by caller
      rethrow;
    }
  }

  Future<void> startImageStream() async {
    if (!_isInitialized || _controller == null) {
      await initialize();
      if (!_isInitialized) return;
    }

    if (_controller!.value.isStreamingImages) {
      return;
    }

    try {
      await _controller!.startImageStream((CameraImage image) {
        if (!_imageStreamController.isClosed) {
          _imageStreamController.add(image);
        }
      });
    } catch (e) {
      AppLogger.error('Error starting image stream: $e');
    }
  }

  Future<void> stopImageStream() async {
    if (_controller?.value.isStreamingImages ?? false) {
      try {
        await _controller!.stopImageStream();
      } catch (e) {
        AppLogger.error('Error stopping image stream: $e');
      }
    }
  }

  Future<bool> toggleCamera() async {
    // Prevent multiple simultaneous toggle operations
    if (_isSwitchingCamera || !_isInitialized || _cameras == null || _cameras!.length <= 1) {
      return false;
    }

    _isSwitchingCamera = true;
    bool success = false;

    try {
      final CameraDescription currentCamera = _controller!.description;
      CameraDescription newCamera;

      if (currentCamera.lensDirection == CameraLensDirection.front) {
        newCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
      } else {
        newCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );
      }

      if (newCamera != currentCamera) {
        // Wait for any pending operations to complete
        await Future.delayed(const Duration(milliseconds: 100));
        
        // The _initializeCameraController method will handle stream restoration
        await _initializeCameraController(newCamera);
        
        AppLogger.info('Camera switched successfully to ${newCamera.lensDirection}');
        success = true;
      }
    } catch (e) {
      AppLogger.error('Error toggling camera: $e');
      success = false;
    } finally {
      _isSwitchingCamera = false;
    }

    return success;
  }

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isSwitchingCamera => _isSwitchingCamera;

  void dispose() async {
    await stopImageStream();
    
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    if (!_imageStreamController.isClosed) {
      await _imageStreamController.close();
    }

    _isInitialized = false;
  }
}
