import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;
  bool _isYouTube = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) {
      setState(() => _errorMessage = 'Video URL is missing or empty');
      return;
    }

    final videoId = YoutubePlayer.convertUrlToId(url);
    _isYouTube = videoId != null;

    try {
      if (_isYouTube) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId!,
          flags: YoutubePlayerFlags(
            autoPlay: widget.autoPlay,
            mute: false,
            loop: widget.looping,
            controlsVisibleAtStart: widget.showControls,
          ),
        );
        setState(() => _isInitialized = true);
      } else {
        _videoController = url.startsWith('http')
            ? VideoPlayerController.network(url)
            : VideoPlayerController.asset(url);

        await _videoController!.initialize();

        if (widget.autoPlay) {
          _videoController!.play();
          _isPlaying = true;
        }

        _videoController!.setLooping(widget.looping);
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: ${e.toString()}';
        _videoController = null;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) return _buildErrorWidget();

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Video player container with fixed aspect ratio
                Container(
                  width: constraints.maxWidth,
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.5, // Limit height to 50% of available space
                  ),
                  child: AspectRatio(
                    aspectRatio: _isYouTube
                        ? 16 / 9
                        : _videoController!.value.aspectRatio,
                    child: _isYouTube
                        ? YoutubePlayer(
                      controller: _youtubeController!,
                      showVideoProgressIndicator: true,
                    )
                        : Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_videoController!),
                        if (widget.showControls) _buildPlayPauseOverlay(),
                      ],
                    ),
                  ),
                ),
                if (!(_isYouTube) && widget.showControls) _buildControls(),
                _buildInstructions(),
              ],
            ),
          );
        }
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: const TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _initializePlayer();
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
              _videoController!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: () {
              _videoController!.seekTo(Duration.zero);
              if (!_isPlaying) _togglePlayPause();
            },
          ),
          IconButton(
            icon: Icon(
              widget.looping ? Icons.repeat_one : Icons.repeat,
              color: widget.looping ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _videoController!.setLooping(!widget.looping);
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
          const Text('Tips:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '• Watch the video multiple times to understand the hand movements',
            style: TextStyle(fontSize: 16),
            softWrap: true,
          ),
          const Text(
            '• Focus on both hand shape and movement direction',
            style: TextStyle(fontSize: 16),
            softWrap: true,
          ),
          const Text(
            '• Try to mimic the sign while watching',
            style: TextStyle(fontSize: 16),
            softWrap: true,
          ),
          const SizedBox(height: 16),
          FractionallySizedBox(
            widthFactor: 1.0, // Takes full width
            child: ElevatedButton(
              onPressed: () {
                // Navigate to practice mode
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Practice This Sign', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    if (_videoController == null) return;

    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }
}