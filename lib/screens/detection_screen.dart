import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../services/camera_service.dart';
import '../services/hand_landmark_service.dart';
import '../services/recognition_service.dart';
import '../services/text_input_service.dart';
import '../models/recognition_model.dart';
// import '../widgets/suggestion_chip.dart';
import '../utils/logger.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final HandLandmarkService _handLandmarkService = handLandmarkService;
  final RecognitionService _recognitionService = RecognitionService();

  bool _isCameraPermissionGranted = false;
  bool _isProcessing = false;
  RecognitionResult? _lastRecognition;
  StreamSubscription? _subscription;

  // Animation controller for detection feedback
  late AnimationController _animationController;
  late Animation<Color?> _borderColorAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Define the color animation
    _borderColorAnimation = ColorTween(
      begin: Colors.yellow,
      end: Colors.green,
    ).animate(_animationController);

    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive) {
      _stopCamera();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isCameraPermissionGranted = status.isGranted;
    });
  }

  Future<void> _recognitionHandsign(landmarksResult) async {
    AppLogger.info('[UI] Landmarks detected: $landmarksResult');
    if (landmarksResult == null) {
      // No landmarks detected, clear recognition
      _updateRecognitionState(null);
    } else {
      // Landmarks detected, update recognition state
      // Process landmarks on a separate isolate via the service
      final result = await _recognitionService.processHandLandmarks(
        landmarksResult,
      );

      if (result != null && result.confidence > 0.7 && mounted) {
        _updateRecognitionState(result);

        // Update the UI asynchronously
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Provider.of<TextInputService>(
              context,
              listen: false,
            ).addCharacter(result);
          }
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    // Check camera permission
    if (!_isCameraPermissionGranted) {
      await _requestCameraPermission();
      if (!_isCameraPermissionGranted) {
        return;
      }
    }

    // Initialize services
    await _cameraService.initialize();
    await _handLandmarkService.initialize();
    await _recognitionService.initialize();

    // Start camera stream
    await _cameraService.startImageStream();

    // Process frames
    _subscription = _cameraService.imageStream.listen(_processImage);

    // Listen for hand landmarks
    _handLandmarkService.addListener(() {
      if (_handLandmarkService.currentLandmarks != null) {
        _recognitionHandsign(_handLandmarkService.currentLandmarks);
      }
    });
  }

  Future<void> _processImage(CameraImage image) async {
    // Don't process another frame if we're still processing or if the widget is unmounted
    if (_isProcessing || !mounted) return;

    // Set processing flag to prevent multiple simultaneous processing
    setState(() {
      _isProcessing = true;
    });

    try {
      // Move the processing to a separate isolate via the service
      // Services are already updated to use compute() internally
      await _handLandmarkService.processImage(
        image,
        _cameraService.controller!.description,
      );
    } catch (e) {
      AppLogger.error('Error processing image: $e');
    } finally {
      // Reset processing flag if widget is still mounted
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _stopCamera() {
    _subscription?.cancel();
    _cameraService.stopImageStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _cameraService.dispose();
    _handLandmarkService.dispose();
    _recognitionService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Update the UI when recognition changes
  void _updateRecognitionState(RecognitionResult? result) {
    setState(() {
      _lastRecognition = result;

      // Control animation based on detection
      if (result != null) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Language Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              await _cameraService.toggleCamera();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isCameraPermissionGranted) {
      return _buildPermissionRequest();
    }

    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return _buildLoading();
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Simple camera preview
              CameraPreview(_cameraService.controller!),

              // Processing area indicator with animated feedback
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.width * 0.8,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _borderColorAnimation.value ?? Colors.yellow,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // Conditional detection text
                          if (_lastRecognition != null)
                            Center(
                              child: Text(
                                "Hand Detected!",
                                style: TextStyle(
                                  color:
                                      _borderColorAnimation.value ??
                                      Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1.0, 1.0),
                                      blurRadius: 3.0,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.front_hand_outlined,
                                    color:
                                        _borderColorAnimation.value ??
                                        Colors.yellow,
                                    size: 40,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Place hand here",
                                    style: TextStyle(
                                      color:
                                          _borderColorAnimation.value ??
                                          Colors.yellow,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1.0, 1.0),
                                          blurRadius: 3.0,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Recognition indicator
              if (_lastRecognition != null)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Detected: ${_lastRecognition!.character} (${(_lastRecognition!.confidence * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Processing indicator
              if (_isProcessing)
                const Center(
                  child: SpinKitRipple(color: Colors.white, size: 100.0),
                ),

              // Model status indicator
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MediaPipe: GPU', // TODO: Update this based on actual model used
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Text input display
        Expanded(
          flex: 2,
          child: Consumer<TextInputService>(
            builder: (context, service, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          service.text,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.backspace),
                          onPressed: () => service.clearText(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.space_bar),
                          onPressed: () => service.selectSuggestion(" "),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => service.clearText(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Camera permission is required',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _requestCameraPermission,
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: SpinKitCircle(color: Colors.blue, size: 50.0));
  }
}
