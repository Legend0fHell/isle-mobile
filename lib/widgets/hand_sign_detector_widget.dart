import 'dart:async';
import 'dart:math';
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
import '../utils/logger.dart';

/// Create a public global interface to the hand sign detector
class HandSignDetectorController {
  Future<bool> Function() toggleCamera;

  HandSignDetectorController({required this.toggleCamera});
}

/// A custom painter to draw hand landmarks and connections
class HandLandmarkPainter extends CustomPainter {
  final List<dynamic>? landmarks;
  final double containerSize;
  final bool isFrontCamera;

  HandLandmarkPainter({
    this.landmarks, 
    required this.containerSize,
    required this.isFrontCamera,
  });

  // Define connections between landmarks to form a hand shape
  final List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],     // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8],     // Index finger
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [13, 17], [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.isEmpty) return;

    // Paint for dots
    final dotPaint = Paint()
      ..color = Colors.red.shade900  // Dark red dots
      ..style = PaintingStyle.fill;

    // Paint for lines
    final linePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;  // Narrower lines

    // Draw connections first (lines)
    for (final connection in connections) {
      final start = connection[0];
      final end = connection[1];

      if (start < landmarks!.length && end < landmarks!.length) {
        final startPoint = _landmarkToPoint(landmarks![start]);
        final endPoint = _landmarkToPoint(landmarks![end]);

        canvas.drawLine(startPoint, endPoint, linePaint);
      }
    }

    // Draw landmarks (dots)
    for (final landmark in landmarks!) {
      final point = _landmarkToPoint(landmark);
      canvas.drawCircle(point, 3.0, dotPaint);  // Slightly smaller dots
    }
  }

  Offset _landmarkToPoint(dynamic landmark) {
    // Convert normalized coordinates to pixel coordinates
    // The x,y coordinates from MediaPipe are normalized (0-1)
    double x = landmark['x'] * containerSize;
    double y = landmark['y'] * containerSize;
    
    // Mirror horizontally if using front camera
    if (isFrontCamera) {
      x = containerSize - x;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(HandLandmarkPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}

/// A widget that handles hand sign detection using the device camera
class HandSignDetectorWidget extends StatefulWidget {
  /// Callback triggered when a hand sign is detected
  final void Function(RecognitionResult)? onHandSignDetected;

  /// Optional widget to display below the camera preview
  final Widget? bottomWidget;

  /// Width of the camera preview container, defaults to 90% of screen width
  final double? previewWidth;

  /// Whether to show the detection feedback (border animation)
  final bool showDetectionFeedback;

  /// Whether to show recognition information
  final bool showRecognitionInfo;

  /// Whether to show model status
  final bool showModelStatus;

  /// Whether to show guidance text when no hand is detected
  final bool showGuidance;
  
  /// Whether to draw hand landmarks
  final bool showHandLandmarks;

  /// Minimum confidence threshold for recognition (0.0 to 1.0)
  final double confidenceThreshold;

  /// Controller to access widget methods from outside
  final HandSignDetectorController? controller;

  /// Consecutive detections needed to accept a character
  final int consecutiveThreshold;

  const HandSignDetectorWidget({
    super.key,
    this.onHandSignDetected,
    this.bottomWidget,
    this.previewWidth,
    this.showDetectionFeedback = true,
    this.showRecognitionInfo = true,
    this.showModelStatus = true,
    this.showGuidance = true,
    this.showHandLandmarks = true,
    this.confidenceThreshold = 0.6,
    this.controller,
    this.consecutiveThreshold = 6,
  });

  @override
  State<HandSignDetectorWidget> createState() => _HandSignDetectorWidgetState();
}

/// This widget handles rendering the camera preview in a properly sized container
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
            child:
                controller.description.lensDirection ==
                        CameraLensDirection.front
                    ? Transform(
                      alignment: Alignment.center,
                      transform:
                          Matrix4.identity()
                            ..scale(-1.0, 1.0, 1.0), // horizontal flip
                      child: CameraPreview(controller),
                    )
                    : CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _HandSignDetectorWidgetState extends State<HandSignDetectorWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final HandLandmarkService _handLandmarkService = handLandmarkService;
  final RecognitionService _recognitionService = RecognitionService();

  double _trueAspectRatio = 1.0;
  bool _isCameraPermissionGranted = false;
  bool _isProcessing = false;
  bool _isDisposed = false;

  // Track the current camera image
  CameraImage? _currentCameraImage;
  
  RecognitionResult? _lastRecognition;
  StreamSubscription? _subscription;
  
  // Timers for controlling processing rates
  Timer? _landmarkTimer;
  Timer? _recognitionTimer;
  Timer? _resetTimer;
  Timer? _flashTimer;
  
  // Consecutive detection tracking
  String? _lastDetectedChar;
  int _consecutiveCount = 0;
  RecognitionResult? _lastRawRecognition;
  DateTime _lastSuccessfulDetectionTime = DateTime.now();
  
  // UI state
  bool _showFlash = false;
  double _confidenceBarValue = 0.0;
  double _consecutiveBarValue = 0.0;

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

    // Set up controller if provided
    if (widget.controller != null) {
      widget.controller!.toggleCamera = toggleCamera;
    }

    _initializeCamera();
  }

  @override
  void didUpdateWidget(HandSignDetectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller if it changed
    if (widget.controller != null) {
      widget.controller!.toggleCamera = toggleCamera;
    }
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

  // Process hand landmarks continuously (100ms interval)
  void _startContinuousLandmarkProcessing() {
    _landmarkTimer?.cancel();
    _recognitionTimer?.cancel();
    
    // Start recognition timer with 250ms interval for stage 2
    _recognitionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _processRecognition();
    });
    
    // Listen to camera image stream
    _subscription?.cancel();
    _subscription = _cameraService.imageStream.listen((image) {
      _currentCameraImage = image;
    });
    
    // Start the reset timer to check for detection timeouts
    _startResetTimer();
    
    // Start adaptive timing for stage 1 landmark detection (target: 80ms cycles)
    _runAdaptiveLandmarkDetection();
  }
  
  // Run landmark detection with adaptive timing targeting 80ms cycles
  void _runAdaptiveLandmarkDetection() {
    if (_isDisposed || !mounted) return;
    
    final cycleStartTime = DateTime.now();
    
    // Process landmarks (stage 1)
    _processLandmarks().then((_) {
      if (_isDisposed || !mounted) return;
      
      // Calculate how long the processing took
      final processingDuration = DateTime.now().difference(cycleStartTime).inMilliseconds;
      
      // Target cycle time is 80ms
      final targetCycleTime = 66;
      
      // Calculate wait time (if processing was faster than target)
      final waitTime = max(0, targetCycleTime - processingDuration);
      
      // Schedule next cycle after appropriate wait time
      Future.delayed(Duration(milliseconds: waitTime), () {
        if (!_isDisposed && mounted) {
          _runAdaptiveLandmarkDetection();
        }
      });
      
      // Log performance metrics periodically (uncomment for debugging)
      // if (processingDuration > targetCycleTime) {
      //   AppLogger.info('Landmark detection taking longer than target: ${processingDuration}ms');
      // }
    });
  }
  
  // Process landmarks from current frame
  Future<void> _processLandmarks() async {
    if (_isDisposed || !mounted || _isProcessing || !_cameraService.isInitialized) {
      return;
    }
    if (_currentCameraImage == null) return;
    
    // Set processing flag to prevent multiple simultaneous processing
    setState(() {
      _isProcessing = true;
    });

    try {
      if (_cameraService.controller != null) {
        // Process the current image
        await _handLandmarkService.processImage(
          _currentCameraImage!,
          _cameraService.controller!.description,
        );
      }
    } catch (e) {
      AppLogger.error('Error processing landmarks: $e');
    } finally {
      // Reset processing flag if widget is still mounted
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  // Process recognition from landmarks (250ms interval)
  void _processRecognition() async {
    if (_isDisposed || !mounted) return;
    
    final landmarks = _handLandmarkService.currentLandmarks;
    if (landmarks != null) {
      // Verify landmarks contain data before processing
      final landmarksList = landmarks['landmarks'] as List<dynamic>?;
      if (landmarksList == null || landmarksList.isEmpty) {
        // No valid landmarks, don't process but don't reset counter either
        return;
      }
      
      // Process landmarks on a separate isolate via the service
      final result = await _recognitionService.processHandLandmarks(landmarks);
      
      if (_isDisposed) return;
      
      if (result != null && result.confidence > widget.confidenceThreshold && mounted) {
        // We have a valid detection, update the last successful time
        _lastSuccessfulDetectionTime = DateTime.now();
        _processConsecutiveDetection(result);
        
        // Show green border when hand is detected
        _animationController.forward();
      }
      // Note: We're not resetting the counter on failed detections anymore
    } else {
      // No landmarks detected
      // Reset the animation if we have no hand landmarks
      _animationController.reverse();
      setState(() {
        _lastRawRecognition = null;
      });
    }
    // Note: We're not resetting the counter when no landmarks are detected
  }
  
  // Process consecutive detection logic
  void _processConsecutiveDetection(RecognitionResult result) {
    if (_isDisposed || !mounted) return;
    
    // Flash effect - more subtle light blue flash
    _triggerFlashEffect();
    
    setState(() {
      _lastRawRecognition = result;
      
      // Smoothly animate the confidence bar
      _animateConfidenceBar(result.confidence);
      
      if (_lastDetectedChar == result.character) {
        // Same character detected again
        _consecutiveCount++;
        
        // Smoothly animate the consecutive bar
        _animateConsecutiveBar(_consecutiveCount / widget.consecutiveThreshold);
        
        // If threshold reached, accept the character
        if (_consecutiveCount >= widget.consecutiveThreshold) {
          _updateRecognitionState(result);
          
          // Notify parent widget of detection
          if (widget.onHandSignDetected != null) {
            widget.onHandSignDetected!(result);
          }
          
          // Update text service if available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_isDisposed) {
              try {
                final textService = Provider.of<TextInputService>(
                  context,
                  listen: false,
                );
                textService.addCharacter(result);
              } catch (e) {
                // TextInputService might not be available in the context
                AppLogger.info('TextInputService not available in context');
              }
            }
          });
          
          // Reset consecutive count after accepting
          _lastDetectedChar = null;
          _consecutiveCount = 0;
          _animateConsecutiveBar(0);
        }
      } else {
        // Different character detected, reset counter
        _lastDetectedChar = result.character;
        _consecutiveCount = 1;
        _animateConsecutiveBar(1 / widget.consecutiveThreshold);
      }
    });
  }
  
  // Trigger flash effect - more subtle light blue flash
  void _triggerFlashEffect() {
    setState(() {
      _showFlash = true;
    });
    
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted && !_isDisposed) {
        setState(() {
          _showFlash = false;
        });
      }
    });
  }
  
  // Animate confidence bar smoothly
  void _animateConfidenceBar(double targetValue) {
    // Cancel any previous animations
    const animationDuration = Duration(milliseconds: 200);
    
    final timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // Smoothly approach target value
        final diff = targetValue - _confidenceBarValue;
        if (diff.abs() < 0.01) {
          _confidenceBarValue = targetValue;
          timer.cancel();
        } else {
          _confidenceBarValue += diff * 0.2; // Move 20% closer each frame
        }
      });
    });
    
    // Safety timeout
    Timer(animationDuration, () {
      timer.cancel();
      if (mounted && !_isDisposed) {
        setState(() {
          _confidenceBarValue = targetValue;
        });
      }
    });
  }
  
  // Animate consecutive bar smoothly
  void _animateConsecutiveBar(double targetValue) {
    // Cancel any previous animations
    const animationDuration = Duration(milliseconds: 200);
    
    final timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // Smoothly approach target value
        final diff = targetValue - _consecutiveBarValue;
        if (diff.abs() < 0.01) {
          _consecutiveBarValue = targetValue;
          timer.cancel();
        } else {
          _consecutiveBarValue += diff * 0.2; // Move 20% closer each frame
        }
      });
    });
    
    // Safety timeout
    Timer(animationDuration, () {
      timer.cancel();
      if (mounted && !_isDisposed) {
        setState(() {
          _consecutiveBarValue = targetValue;
        });
      }
    });
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
      final orientation =
          _cameraService.controller!.description.sensorOrientation;

      double fixedAspectRatio = aspectRatio * 0.934375; //?
      if (orientation == 90 || orientation == 270) {
        fixedAspectRatio = 1 / fixedAspectRatio;
      }

      _trueAspectRatio = fixedAspectRatio; // assign to a state field

      // Start continuous processing
      _startContinuousLandmarkProcessing();
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
    // This method is no longer used for processing images
    // Instead, we use the timers to control processing rates
  }

  void _stopCamera() {
    _subscription?.cancel();
    _subscription = null;
    _landmarkTimer?.cancel();
    _landmarkTimer = null;
    _recognitionTimer?.cancel();
    _recognitionTimer = null;
    _resetTimer?.cancel();
    _resetTimer = null;
    _cameraService.stopImageStream();
    _currentCameraImage = null;
  }

  void _cleanupResources() {
    _stopCamera();
    _cameraService.dispose();
    _currentCameraImage = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    _cleanupResources();
    _animationController.dispose();
    _flashTimer?.cancel();

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

  /// Toggle between front and back camera
  Future<bool> toggleCamera() async {
    if (_isDisposed) return false;

    bool success = false;

    setState(() {
      _isProcessing = true;
    });

    try {
      success = await _cameraService.toggleCamera();
    } catch (e) {
      AppLogger.error('Error toggling camera: $e');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });
      }
    }

    return success;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraPermissionGranted) {
      return _buildPermissionRequest();
    }

    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return _buildLoading();
    }

    double contextWidth = MediaQuery.of(context).size.width;
    double previewSize = widget.previewWidth ?? contextWidth * 0.9;
    
    // Extract landmarks from the current recognition
    List<dynamic>? handLandmarks;
    if (_handLandmarkService.currentLandmarks != null) {
      handLandmarks = _handLandmarkService.currentLandmarks!['landmarks'] as List<dynamic>?;
    }

    // Check if using front camera
    bool isFrontCamera = _cameraService.controller!.description.lensDirection == CameraLensDirection.front;

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Simple camera preview with square crop
              Center(
                child: CameraPreviewContainer(
                  controller: _cameraService.controller!,
                  trueAspectRatio: _trueAspectRatio,
                  containerSize: previewSize,
                ),
              ),

              // Processing area indicator with animated feedback
              if (widget.showDetectionFeedback)
                Center(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Container(
                        width: previewSize,
                        height: previewSize,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _borderColorAnimation.value ?? Colors.yellow,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            // Only show guidance when no hand is detected and guidance is enabled
                            if (_lastRawRecognition == null && widget.showGuidance)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.front_hand_outlined,
                                      color:
                                          _borderColorAnimation.value ??
                                          Colors.yellow,
                                      size: 50,
                                    ),
                                  ],
                                ),
                              ),
                              
                            // Draw hand landmarks if enabled and landmarks are available
                            // Use ClipRect to constrain landmarks to the camera view area
                            if (widget.showHandLandmarks && handLandmarks != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: previewSize,
                                  height: previewSize,
                                  child: CustomPaint(
                                    painter: HandLandmarkPainter(
                                      landmarks: handLandmarks,
                                      containerSize: previewSize,
                                      isFrontCamera: isFrontCamera,
                                    ),
                                    size: Size(previewSize, previewSize),
                                  ),
                                ),
                              ),
                              
                            // Slim HUD positioned at the top right of the camera area
                            if (widget.showRecognitionInfo)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 180,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _showFlash 
                                      ? Colors.lightBlue.withOpacity(0.3) 
                                      : Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // First line: Model status and detection
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Delegate type
                                          Text(
                                            _handLandmarkService.delegateType,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          // Detection with confidence
                                          _lastRawRecognition != null 
                                            ? Row(
                                                children: [
                                                  Text(
                                                    _lastRawRecognition!.character,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "(${(_lastRawRecognition!.confidence * 100).round()}%)",
                                                    style: const TextStyle(
                                                      color: Colors.yellow,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Text(
                                                "...",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 0),
                                      
                                      // Two rows of progress bars
                                      Row(
                                        children: [
                                          // Right-aligned confidence bar (under detection result)
                                          Expanded(
                                            flex: 1,
                                            child: Container(
                                              height: 3,
                                              alignment: Alignment.centerRight,
                                              child: Container(
                                                width: 75,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade800,
                                                  borderRadius: BorderRadius.circular(1.5),
                                                ),
                                                child: Row(
                                                  children: [
                                                    AnimatedContainer(
                                                      duration: const Duration(milliseconds: 300),
                                                      width: 75 * _confidenceBarValue,
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                        color: Colors.yellow,
                                                        borderRadius: BorderRadius.circular(1.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      // Full-width consecutive bar
                                      Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade800,
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              width: 160 * _consecutiveBarValue,
                                              height: 3,
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius: BorderRadius.circular(1.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // Bottom widget if provided
        if (widget.bottomWidget != null) widget.bottomWidget!,
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

  // Start a timer to check for detection timeouts
  void _startResetTimer() {
    _resetTimer?.cancel();
    _resetTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkDetectionTimeout();
    });
  }
  
  // Check if we've had no successful detections for 5 seconds
  void _checkDetectionTimeout() {
    if (_isDisposed || !mounted) return;
    
    final now = DateTime.now();
    final difference = now.difference(_lastSuccessfulDetectionTime).inSeconds;
    
    // If no successful detection for 5 seconds and we have an active detection
    if (difference >= 5 && (_lastDetectedChar != null || _lastRawRecognition != null)) {
      setState(() {
        _lastDetectedChar = null;
        _consecutiveCount = 0;
        _consecutiveBarValue = 0;
        _confidenceBarValue = 0;
        _lastRawRecognition = null;
        
        // Clear the display of the last recognition
        if (_lastRecognition != null) {
          _updateRecognitionState(null);
        }
      });
      
      AppLogger.info('Reset detection state after 5 seconds of inactivity');
    }
  }
}
