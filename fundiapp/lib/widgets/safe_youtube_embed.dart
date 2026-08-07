import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SafeYoutubeEmbed extends StatefulWidget {
  final String videoUrl;
  final double height;

  const SafeYoutubeEmbed({
    super.key,
    required this.videoUrl,
    this.height = 220,
  });

  @override
  State<SafeYoutubeEmbed> createState() => _SafeYoutubeEmbedState();
}

class _SafeYoutubeEmbedState extends State<SafeYoutubeEmbed> {
  YoutubePlayerController? _controller;
  String? _videoId;
  bool _isLoading = true;
  String? _errorMessage;

  /// Extract YouTube video ID from various formats
  String? _extractVideoId(String input) {
    // First try: Use YoutubePlayer's built-in converter
    String? id = YoutubePlayer.convertUrlToId(input);

    // Second try: Manual regex extraction if built-in fails
    if (id == null || id.isEmpty) {
      final regExp = RegExp(
        r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([^&\n?#]+)',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(input);
      if (match != null && match.groupCount >= 1) {
        id = match.group(1);
      }
    }

    // Third try: Extract from iframe embed code
    if (id == null || id.isEmpty) {
      // Try double quotes
      final iframeRegex = RegExp(r'src="([^"]+)"');
      final match = iframeRegex.firstMatch(input);
      if (match != null) {
        final url = match.group(1);
        if (url != null) {
          // Recursively extract from the URL
          return _extractVideoId(url);
        }
      }

      // Try single quotes
      final iframeRegexSingle = RegExp(r"src='([^']+)'");
      final matchSingle = iframeRegexSingle.firstMatch(input);
      if (matchSingle != null) {
        final url = matchSingle.group(1);
        if (url != null) {
          return _extractVideoId(url);
        }
      }
    }

    // Clean the ID if found
    if (id != null && id.isNotEmpty) {
      // Remove any query parameters or fragments
      id = id.split('?')[0].split('#')[0];

      // Ensure it's a valid YouTube video ID (usually 11 characters)
      if (id.length >= 11) {
        // Take first 11 characters if longer (some URLs might have extra chars)
        return id.substring(0, 11);
      }
    }

    return id;
  }

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    try {
      // Extract video ID from the URL
      final videoId = _extractVideoId(widget.videoUrl);

      if (videoId != null && videoId.isNotEmpty) {
        _videoId = videoId;
        _controller = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,      // Changed to false to prevent Android issues
            mute: false,          // Changed to false to allow audio
            enableCaption: true,  // Changed to true
            isLive: false,
            loop: false,          // Changed to false
            disableDragSeek: false,
            forceHD: false,
            useHybridComposition: true, // Important for Android
          ),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }

        debugPrint('✅ YouTube Player initialized with ID: $videoId');
      } else {
        debugPrint('⚠️ Invalid YouTube URL: ${widget.videoUrl}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not extract video ID';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ YouTube Player Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading video';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading state
    if (_isLoading) {
      return Container(
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
              SizedBox(height: 12),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error if no valid video ID
    if (_videoId == null || _controller == null) {
      return Container(
        height: widget.height,
        color: Colors.black12,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                color: Colors.red.shade700,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                _errorMessage ?? 'Invalid YouTube URL',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Render the YouTube player
    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.grey,
          ),
          onReady: () {
            debugPrint('✅ YouTube Player ready for video: $_videoId');
          },
          onEnded: (data) {
            // Optionally restart the video
            _controller?.seekTo(Duration.zero);
            _controller?.pause();
          },
          bottomActions: [
            const CurrentPosition(),
            ProgressBar(
              isExpanded: true,
              colors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
                backgroundColor: Colors.grey,
                bufferedColor: Colors.grey,
              ),
            ),
            const RemainingDuration(),
          ],
        ),
      ),
    );
  }
}