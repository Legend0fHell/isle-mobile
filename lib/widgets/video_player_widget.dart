import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? videoUrl;
  final bool showControls;
  final bool autoPlay;
  final bool looping;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.showControls = true,
    this.autoPlay = false,
    this.looping = false,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      setState(() {
        _errorMessage = 'Video URL is missing or empty';
      });
      return;
    }

    try {
      if (widget.videoUrl!.startsWith('http')) {
        _controller = VideoPlayerController.network(widget.videoUrl!);
      } else {
        _controller = VideoPlayerController.asset(widget.videoUrl!);
      }

      await _controller!.initialize();

      if (widget.autoPlay) {
        _controller!.play();
        _isPlaying = true;
      }

      _controller!.setLooping(widget.looping);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: ${e.toString()}';
        _controller = null;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    // Show loading indicator while initializing
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller!),
              if (widget.showControls) _buildPlayPauseOverlay(),
            ],
          ),
        ),
        if (widget.showControls) _buildControls(),
        _buildInstructions(),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
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
            _errorMessage ?? 'Unknown error occurred',
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
                _errorMessage = null;
                _initializeVideoPlayer();
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseOverlay() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black26,
        child: Center(
          child: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 60.0,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlayPause,
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: () {
              _controller!.seekTo(Duration.zero);
              if (!_isPlaying) {
                _togglePlayPause();
              }
            },
          ),
          IconButton(
            icon: Icon(
              widget.looping ? Icons.repeat_one : Icons.repeat,
              color: widget.looping ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _controller!.setLooping(!widget.looping);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tips:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          const Text(
            '• Watch the video multiple times to understand the hand movements',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4.0),
          const Text(
            '• Focus on both hand shape and movement direction',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4.0),
          const Text(
            '• Try to mimic the sign while watching',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: () {
              // Navigate to practice mode
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text(
              'Practice This Sign',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }
}