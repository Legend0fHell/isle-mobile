import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Import the hand sign detector related files
import '../models/recognition_model.dart';
import 'hand_sign_detector_widget.dart';

class PracticeMirrorWidget extends StatefulWidget {
  final String? referenceVideoUrl;
  final String instructions;
  final String? targetSign;
  final Function(String)? onSignDetected;
  final bool initialVideoOn;

  const PracticeMirrorWidget({
    Key? key,
    this.referenceVideoUrl,
    required this.instructions,
    this.targetSign,
    this.onSignDetected,
    required this.initialVideoOn,
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
  bool _isPracticeSuccessful = false;
  bool _hasShownSuccessMessage = false;

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

    // Reset practice status if target sign changes
    if (oldWidget.targetSign != widget.targetSign) {
      setState(() {
        _isPracticeSuccessful = false;
        _lastDetectedSign = null;
        _isAssessmentAvailable = false;
        _hasShownSuccessMessage = false;
      });
    }
  }

  void _initializeYouTubeController() {
    if (widget.referenceVideoUrl != null && widget.referenceVideoUrl!.isNotEmpty) {
      // Extract YouTube video ID from URL
      _showReferenceVideo = widget.initialVideoOn;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.instructions,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (widget.targetSign != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.track_changes, color: Colors.blue[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Target Sign: ${widget.targetSign}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildVideoComparisonSection(constraints),
              _buildControlsSection(),
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

      // Check if detected sign matches target sign
      if (widget.targetSign != null &&
          result.character.toUpperCase() == widget.targetSign!.toUpperCase()) {
        _isPracticeSuccessful = true;
      }
    });

    // Notify parent widget about the detected sign
    if (widget.onSignDetected != null) {
      widget.onSignDetected!(result.character);
    }

    // Show success message only once per target sign
    if (_isPracticeSuccessful && !_hasShownSuccessMessage) {
      setState(() {
        _hasShownSuccessMessage = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perfect! You signed "${result.character}" correctly!',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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