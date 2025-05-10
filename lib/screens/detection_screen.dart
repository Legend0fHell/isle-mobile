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

class CameraPreviewContainer extends StatelessWidget {
  final CameraController controller;
  final double trueAspectRatio;
  final double containerSize;

  const CameraPreviewContainer({
    super.key,
    required this.controller,
    required this.trueAspectRatio,
    required this.containerSize,
  });

  @override
  Widget build(BuildContext context) {
    final previewWidth =
        trueAspectRatio > 1 ? containerSize * trueAspectRatio : containerSize;
    final previewHeight =
        trueAspectRatio < 1 ? containerSize / trueAspectRatio : containerSize;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: OverflowBox(
          maxWidth: previewWidth,
          maxHeight: previewHeight,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: controller.description.lensDirection == CameraLensDirection.front
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0), // horizontal flip
                  child: CameraPreview(controller),
                )
              : CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final HandLandmarkService _handLandmarkService = handLandmarkService;
  final RecognitionService _recognitionService = RecognitionService();

  double _trueAspectRatio = 1.0;
  bool _isCameraPermissionGranted = false;
  bool _isProcessing = false;
  bool _isDisposed = false;

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
    if (state == AppLifecycleState.resumed && !_isDisposed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive || 
               state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.detached) {
      // Ensure complete cleanup when app is detached
      _cleanupResources();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _isCameraPermissionGranted = status.isGranted;
      });
    }
  }

  // Function to handle hand landmark updates
  void _onHandLandmarkUpdate() {
    if (_isDisposed || !mounted) return;
    
    final landmarks = _handLandmarkService.currentLandmarks;
    if (landmarks != null) {
      _recognitionHandsign(landmarks);
    }
  }

  Future<void> _recognitionHandsign(landmarksResult) async {
    if (_isDisposed) return;
    
    // Capture the context before async gap
    final BuildContext currentContext = context;
    
    if (landmarksResult == null ||
        (landmarksResult['landmarks'] as List<dynamic>).isEmpty) {
      // No landmarks detected, clear recognition
      _updateRecognitionState(null);
    } else {
      // Landmarks detected, update recognition state
      // Process landmarks on a separate isolate via the service
      final result = await _recognitionService.processHandLandmarks(
        landmarksResult,
      );

      if (_isDisposed) return;

      if (result != null && result.confidence > 0.59 && mounted) {
        _updateRecognitionState(result);

        // Update the UI asynchronously
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentContext.mounted && !_isDisposed) {
            Provider.of<TextInputService>(
              currentContext,
              listen: false,
            ).addCharacter(result);
          }
        });
      } else {
        // No valid recognition result, clear recognition
        _updateRecognitionState(null);
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;
    
    // Check camera permission
    if (!_isCameraPermissionGranted) {
      await _requestCameraPermission();
      if (!_isCameraPermissionGranted) {
        return;
      }
    }

    // Capture the context before async gap
    final BuildContext currentContext = context;

    if (mounted && !_isDisposed) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      // Fully dispose of previous camera resources if needed
      if (_cameraService.isInitialized) {
        _stopCamera();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (_isDisposed) return;

      // Initialize services
      await _cameraService.initialize();
      await _handLandmarkService.initialize();
      await _recognitionService.initialize();

      if (_isDisposed) return;

      // Start camera stream
      await _cameraService.startImageStream();

      final aspectRatio = _cameraService.controller!.value.aspectRatio;
      final orientation = _cameraService.controller!.description.sensorOrientation;

      double fixedAspectRatio = aspectRatio * 0.934375; //?
      if (orientation == 90 || orientation == 270) {
        fixedAspectRatio = 1 / fixedAspectRatio;
      }

      _trueAspectRatio = fixedAspectRatio; // assign to a state field

      // Process frames
      _subscription = _cameraService.imageStream.listen(_processImage);

      // Listen for hand landmarks
      // Remove previous listener if exists (to avoid duplicates)
      _handLandmarkService.removeListener(_onHandLandmarkUpdate);
      _handLandmarkService.addListener(_onHandLandmarkUpdate);
    } catch (e) {
      AppLogger.error('Error in _initializeCamera: $e');
      if (currentContext.mounted && !_isDisposed) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Camera initialization error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    // Don't process another frame if we're still processing, disposed, or if the widget is unmounted
    if (_isProcessing || _isDisposed || !mounted) return;

    // Set processing flag to prevent multiple simultaneous processing
    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

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
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _stopCamera() {
    _subscription?.cancel();
    _subscription = null;
    _cameraService.stopImageStream();
  }
  
  void _cleanupResources() {
    _stopCamera();
    _cameraService.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    
    _cleanupResources();
    _animationController.dispose();
    
    super.dispose();
  }

  // Update the UI when recognition changes
  void _updateRecognitionState(RecognitionResult? result) {
    if (_isDisposed || !mounted) return;
    
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
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (!_isCameraPermissionGranted) {
      return _buildPermissionRequest();
    }

    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return _buildLoading();
    }    

    double contextWidth = MediaQuery.of(context).size.width;

    return Text(
      "idle"
    );

    /*return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Simple camera preview with square crop
              Center(
                child: CameraPreviewContainer(controller: _cameraService.controller!, trueAspectRatio: _trueAspectRatio, containerSize: contextWidth * 0.9)
              ),

              // Processing area indicator with animated feedback - made larger
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: contextWidth * 0.9, // Larger rectangle
                      height: contextWidth * 0.9, // Larger rectangle
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _borderColorAnimation.value ?? Colors.yellow,
                          width: 3, // Slightly thicker border
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Only show guidance when no hand is detected
                          if (_lastRecognition == null)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.front_hand_outlined,
                                    color:
                                        _borderColorAnimation.value ??
                                        Colors.yellow,
                                    size: 50, // Larger icon
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Place hand here",
                                    style: TextStyle(
                                      color:
                                          _borderColorAnimation.value ??
                                          Colors.yellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18, // Larger text
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

              // Model status indicator (without processing circle)
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
                    '${_handLandmarkService.delegateType} | ${_handLandmarkService.inferenceTime}ms',
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
              final String currentWord = service.currentWord;

              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current word display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: .1),
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        currentWord.isEmpty ? "..." : currentWord,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: currentWord.isEmpty ? Colors.grey : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Full text display
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            service.text,
                            style: const TextStyle(fontSize: 20),
                          ),
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
                        IconButton(
                          icon: const Icon(Icons.cameraswitch),
                          onPressed: () async {
                            if (_isDisposed) return;
                            
                            // Capture the context before async gap
                            final BuildContext currentContext = context;
                            
                            // Disable processing while switching cameras
                            setState(() {
                              _isProcessing = true;
                            });
                            
                            try {
                              final success = await _cameraService.toggleCamera();
                              
                              if (!success && currentContext.mounted && !_isDisposed) {
                                // Show error snackbar if camera switch failed
                                ScaffoldMessenger.of(currentContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to switch camera. Please try again.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              // Show error message
                              if (currentContext.mounted && !_isDisposed) {
                                ScaffoldMessenger.of(currentContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Camera error: ${e.toString()}'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                              AppLogger.error('Error in camera switch button: $e');
                            } finally {
                              // Re-enable processing
                              if (mounted && !_isDisposed) {
                                setState(() {
                                  _isProcessing = false;
                                });
                              }
                            }
                          },
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
    ); */
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