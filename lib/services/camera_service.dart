import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/logger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

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
    if (_controller != null) {
      await _controller!.dispose();
    }

    // Create a camera controller with medium resolution preset
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    // Log the actual camera resolution for debugging
    final size = _controller!.value.previewSize;
    if (size != null) {
      AppLogger.info(
        'Camera initialized with resolution: ${size.width.toInt()}x${size.height.toInt()}',
      );
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

    await _controller!.startImageStream((CameraImage image) {
      if (!_imageStreamController.isClosed) {
        _imageStreamController.add(image);
      }
    });
  }

  Future<void> stopImageStream() async {
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller!.stopImageStream();
    }
  }

  Future<void> toggleCamera() async {
    if (!_isInitialized || _cameras == null || _cameras!.length <= 1) {
      return;
    }

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
      await _initializeCameraController(newCamera);

      // If we were streaming before, restart streaming with the new camera
      if (_controller!.value.isStreamingImages) {
        await stopImageStream();
        await startImageStream();
      }
    }
  }

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  void dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;

    if (!_imageStreamController.isClosed) {
      await _imageStreamController.close();
    }

    _isInitialized = false;
  }
}
