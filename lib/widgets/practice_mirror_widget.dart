import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Import the hand sign detector related files
import '../services/text_input_service.dart';
import '../models/recognition_model.dart';
import 'hand_sign_detector_widget.dart';

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
  bool _showReferenceVideo = true;
  String? _lastDetectedSign;
  HandSignDetectorController? _handSignDetectorController;
  bool _isAssessmentAvailable = false;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _handSignDetectorController = HandSignDetectorController(
      toggleCamera: () async {
        // Default implementation
        return false;
      },
    );

    // Initialize YouTube controller if URL is available
    _initializeYouTubeController();
  }

  @override
  void didUpdateWidget(PracticeMirrorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize YouTube controller if URL changes
    if (oldWidget.referenceVideoUrl != widget.referenceVideoUrl) {
      _initializeYouTubeController();
    }
  }

  void _initializeYouTubeController() {
    if (widget.referenceVideoUrl != null && widget.referenceVideoUrl!.isNotEmpty) {
      // Extract YouTube video ID from URL
      final videoId = _extractYouTubeId(widget.referenceVideoUrl!);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            loop: true,
          ),
        );
      }
    }
  }

  String? _extractYouTubeId(String url) {
    // Handle various YouTube URL formats
    RegExp regExp = RegExp(
      r'^.*(youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      return match.group(2);
    }
    return null;
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              if (_isAssessmentAvailable) _buildAssessmentSection(),
              // Add extra padding at the bottom to avoid being cut off by navigation
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoComparisonSection(BoxConstraints constraints) {
    // Calculate appropriate size based on screen width
    // Use the minimum of width/2 (for side-by-side layout) or a fixed maximum
    final bool isWideScreen = constraints.maxWidth > 600;

    // For wide screens, each video gets roughly half the width minus padding
    // For narrow screens, each video gets full width
    final double videoWidth = isWideScreen
        ? (constraints.maxWidth - 48) / 2  // Account for padding and middle spacing
        : constraints.maxWidth - 32;       // Account for horizontal padding

    // Limit max height to maintain reasonable proportions
    final double maxVideoHeight = isWideScreen ? 250 : videoWidth * 0.75;

    // Make sure hand detector has a defined square size that fits within constraints
    final double handDetectorSize = maxVideoHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: isWideScreen
      // Horizontal layout for larger screens
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: videoWidth / 2,
            child: _buildVideoContainer(_buildReferenceVideoWidget(), maxVideoHeight),
          ),
          const SizedBox(width: 16.0),
          SizedBox(
            width: videoWidth / 2,
            child: _buildVideoContainer(
                _buildHandSignDetectorWidget(handDetectorSize),
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
              _buildHandSignDetectorWidget(handDetectorSize),
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
      clipBehavior: Clip.hardEdge, // Enforce clipping to prevent overflow
      child: child,
    );
  }

  Widget _buildHandSignDetectorWidget(double containerHeight) {
    return SizedBox(
      height: containerHeight,
      width: containerHeight, // Make it square
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0, // Force a perfect square
          child: HandSignDetectorWidget(
            // Pass explicit dimensions instead of just previewWidth
            previewWidth: containerHeight * 0.9, // Slightly smaller to ensure no overflow
            showDetectionFeedback: true,
            showRecognitionInfo: true,
            showModelStatus: false,
            showGuidance: true,
            confidenceThreshold: 0.65,
            controller: _handSignDetectorController,
            onHandSignDetected: _onHandSignDetected,
            bottomWidget: null, // No bottom widget as we manage the layout
          ),
        ),
      ),
    );
  }

  void _onHandSignDetected(RecognitionResult result) {
    setState(() {
      _lastDetectedSign = result.character;
      _isAssessmentAvailable = true;
    });

    // Optional: Show a temporary indication
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Detected sign: ${result.character}'),
        duration: const Duration(seconds: 1),
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
            onPressed: () async {
              final result = await _handSignDetectorController?.toggleCamera() ?? false;
              if (!result) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to switch camera')),
                  );
                }
              }
            },
            tooltip: 'Switch Camera',
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isAssessmentAvailable = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Evaluate Practice',
              style: TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: Icon(_showReferenceVideo
                ? Icons.video_library
                : Icons.videocam),
            onPressed: _canToggleVideoSource() ? _toggleVideoSource : null,
            color: _canToggleVideoSource() ? null : Colors.grey,
            tooltip: _showReferenceVideo
                ? 'Hide Reference'
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Self-Assessment:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_lastDetectedSign != null)
                Text(
                  'Last detected sign: $_lastDetectedSign',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
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

      // Return YouTube player if controller is initialized
      if (_youtubeController != null) {
        return YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blueAccent,
          progressColors: const ProgressBarColors(
            playedColor: Colors.blueAccent,
            handleColor: Colors.blueAccent,
          ),
        );
      } else {
        // Show error if YouTube ID couldn't be extracted
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red),
              SizedBox(height: 8),
              Text(
                'Invalid YouTube URL',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        );
      }
    } else {
      return const Center(
        child: Text(
          'Reference video hidden',
          style: TextStyle(color: Colors.grey),
        ),
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
    // Can toggle if there is a reference video
    return widget.referenceVideoUrl != null &&
        widget.referenceVideoUrl!.isNotEmpty;
  }

  void _toggleVideoSource() {
    setState(() {
      _showReferenceVideo = !_showReferenceVideo;
    });
  }
}