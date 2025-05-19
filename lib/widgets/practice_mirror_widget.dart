import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'video_player_widget.dart';

class PracticeMirrorWidget extends StatefulWidget {
  final String? referenceVideoUrl;
  final String instructions;

  const PracticeMirrorWidget({
    Key? key,
    this.referenceVideoUrl,
    required this.instructions,
  }) : super(key: key);

  @override
  _PracticeMirrorWidgetState createState() => _PracticeMirrorWidgetState();
}

class _PracticeMirrorWidgetState extends State<PracticeMirrorWidget> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = true;
  String? _recordedVideoPath;
  bool _showReferenceVideo = true;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _cameraErrorMessage = 'No cameras available on this device';
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _cameraErrorMessage = 'Failed to initialize camera: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraErrorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.instructions,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              _buildVideoComparisonSection(constraints),
              _buildControlsSection(),
              if (_recordedVideoPath != null) _buildAssessmentSection(),
              // Add extra padding at the bottom to avoid being cut off by navigation
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoComparisonSection(BoxConstraints constraints) {
    // Calculate appropriate height based on screen width to maintain aspect ratio
    // Limiting height to avoid being too tall on wide screens
    final double maxVideoHeight = constraints.maxWidth > 600
        ? 250
        : constraints.maxWidth * 0.4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: constraints.maxWidth > 600
      // Horizontal layout for larger screens
          ? Row(
        children: [
          Expanded(
            child: _buildVideoContainer(_buildReferenceVideoWidget(), maxVideoHeight),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: _buildVideoContainer(
                _isCameraInitialized
                    ? CameraPreview(_cameraController!)
                    : const Center(child: CircularProgressIndicator()),
                maxVideoHeight
            ),
          ),
        ],
      )
      // Vertical layout for smaller screens
          : Column(
        children: [
          _buildVideoContainer(_buildReferenceVideoWidget(), maxVideoHeight),
          const SizedBox(height: 16.0),
          _buildVideoContainer(
              _isCameraInitialized
                  ? CameraPreview(_cameraController!)
                  : const Center(child: CircularProgressIndicator()),
              maxVideoHeight
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContainer(Widget child, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: child,
      ),
    );
  }

  Widget _buildControlsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 16.0,
        runSpacing: 16.0,
        children: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
          ElevatedButton(
            onPressed: _isRecording ? _stopRecording : _startRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _isRecording ? 'Stop Recording' : 'Record Practice',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: Icon(_showReferenceVideo
                ? Icons.video_library
                : Icons.videocam),
            onPressed: _canToggleVideoSource() ? _toggleVideoSource : null,
            color: _canToggleVideoSource() ? null : Colors.grey,
            tooltip: _showReferenceVideo
                ? 'Show Your Recording'
                : 'Show Reference',
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Self-Assessment:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          LayoutBuilder(
            builder: (context, constraints) {
              // Decide between row and column based on available width
              if (constraints.maxWidth >= 450) {
                return Row(
                  children: [
                    Expanded(child: _buildAssessmentButton('Needs Work', Colors.red[100]!)),
                    const SizedBox(width: 8.0),
                    Expanded(child: _buildAssessmentButton('Getting There', Colors.orange[100]!)),
                    const SizedBox(width: 8.0),
                    Expanded(child: _buildAssessmentButton('Got It!', Colors.green[100]!)),
                  ],
                );
              } else {
                // Stack vertically for narrow screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAssessmentButton('Needs Work', Colors.red[100]!),
                    const SizedBox(height: 8.0),
                    _buildAssessmentButton('Getting There', Colors.orange[100]!),
                    const SizedBox(height: 8.0),
                    _buildAssessmentButton('Got It!', Colors.green[100]!),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _cameraErrorMessage ?? 'Unknown error occurred',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _cameraErrorMessage = null;
                  _initializeCamera();
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceVideoWidget() {
    if (_showReferenceVideo) {
      if (widget.referenceVideoUrl == null || widget.referenceVideoUrl!.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No reference video available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return VideoPlayerWidget(
        videoUrl: widget.referenceVideoUrl,
        autoPlay: true,
        looping: true,
      );
    } else if (_recordedVideoPath != null) {
      return VideoPlayerWidget(
        videoUrl: _recordedVideoPath,
        autoPlay: true,
        looping: true,
      );
    } else {
      return const Center(
        child: Text('No recording yet'),
      );
    }
  }

  Widget _buildAssessmentButton(String text, Color color) {
    return ElevatedButton(
      onPressed: () {
        // Handle assessment
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You marked this attempt as: $text'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black87,
      ),
      child: Text(text),
    );
  }

  bool _canToggleVideoSource() {
    // Can only toggle if there is both a reference video and a recorded video
    return _recordedVideoPath != null &&
        widget.referenceVideoUrl != null &&
        widget.referenceVideoUrl!.isNotEmpty;
  }

  Future<void> _switchCamera() async {
    if (_cameraController == null) return;

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras available')),
        );
        return;
      }

      final newCamera = _isFrontCamera
          ? cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      )
          : cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      if (mounted) {
        await _cameraController!.dispose();

        _cameraController = CameraController(
          newCamera,
          ResolutionPreset.medium,
          enableAudio: true,
        );

        await _cameraController!.initialize();

        setState(() {
          _isFrontCamera = !_isFrontCamera;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch camera: ${e.toString()}')),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || _cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: ${e.toString()}')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedVideoPath = videoFile.path;
        _showReferenceVideo = false; // Switch to show recorded video
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video recorded successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save recording: ${e.toString()}')),
      );
    }
  }

  void _toggleVideoSource() {
    if (_recordedVideoPath == null ||
        widget.referenceVideoUrl == null ||
        widget.referenceVideoUrl!.isEmpty) {
      return; // Can't toggle if either video is missing
    }

    setState(() {
      _showReferenceVideo = !_showReferenceVideo;
    });
  }
}