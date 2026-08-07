// widgets/safe_youtube_embed.dart
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

  String? _extractVideoId(String input) {
    // Try built-in converter first
    String? id = YoutubePlayer.convertUrlToId(input);

    // Fallback: manual regex
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

    // Handle iframe embed
    if (id == null || id.isEmpty) {
      final iframeRegex = RegExp(r'src="([^"]+)"');
      final match = iframeRegex.firstMatch(input);
      if (match != null) {
        final url = match.group(1);
        if (url != null) {
          return _extractVideoId(url);
        }
      }
    }

    if (id != null && id.isNotEmpty) {
      id = id.split('?')[0].split('#')[0];
      if (id.length >= 11) {
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
      final videoId = _extractVideoId(widget.videoUrl);

      if (videoId != null && videoId.isNotEmpty) {
        _videoId = videoId;
        _controller = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            isLive: false,
            loop: false,
            disableDragSeek: false,
            forceHD: false,
            useHybridComposition: true,
          ),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not extract video ID';
          });
        }
      }
    } catch (e) {
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
    if (_isLoading) {
      return Container(
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_videoId == null || _controller == null) {
      return Container(
        height: widget.height,
        color: Colors.grey.shade900,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline, color: Colors.grey.shade600, size: 48),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Video unavailable',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
            debugPrint('✅ YouTube Player ready');
          },
        ),
      ),
    );
  }
}