// lib/widgets/message_bubble.dart

import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../utils/image_utils.dart';
import '../l10n/app_localizations.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final VoidCallback? onLongPress;
  final VoidCallback? onDownload;
  final VoidCallback? onDeleteFile;
  final VoidCallback? onPlayVoice;
  final bool isPlaying;
  final Duration playbackPosition;
  final Duration playbackDuration;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onLongPress,
    this.onDownload,
    this.onDeleteFile,
    this.onPlayVoice,
    this.isPlaying = false,
    this.playbackPosition = Duration.zero,
    this.playbackDuration = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = message.messageType == 'image';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment:
        isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: isImage
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? const Color(0xFFDCF8C6)
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                    bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessageContent(context),
                    const SizedBox(height: 2),
                    _buildTimestamp(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = Theme.of(context);

    switch (message.messageType) {
      case 'text':
        return Text(
          message.content ?? '',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            height: 1.3,
          ),
        );

      case 'image':
        final imageUrl = message.file?.url ?? '';
        final fullUrl = ImageUtils.getFullImageUrl(imageUrl);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    fullUrl,
                    width: 220,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 220,
                      height: 200,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                ),
                if (onDownload != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: onDownload,
                    ),
                  ),
              ],
            ),
            if (message.content != null && message.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(message.content!),
              ),
          ],
        );

      case 'voice':
        return Row(
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: theme.primaryColor,
                size: 32,
              ),
              onPressed: onPlayVoice,
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: playbackDuration.inMilliseconds > 0
                    ? playbackPosition.inMilliseconds /
                    playbackDuration.inMilliseconds
                    : 0,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(theme.primaryColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${message.voiceDuration ?? 0}s',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        );

      case 'file':
        return Row(
          children: [
            Icon(Icons.insert_drive_file, color: theme.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.file?.name ?? 'File',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onDownload != null)
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: onDownload,
              ),
          ],
        );

      case 'video':
        return GestureDetector(
          onTap: onDownload,
          child: Container(
            width: 220,
            height: 150,
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.play_circle_filled, size: 60, color: Colors.white),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimestamp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt, l10n),
          style: TextStyle(
            fontSize: 11,
            color: isCurrentUser ? Colors.black54 : Colors.grey.shade600,
          ),
        ),
        if (isCurrentUser) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 16,
            color: message.isRead ? Colors.blue[700] : Colors.grey[400],
          ),
        ],
      ],
    );
  }

  String _formatTime(String? timestamp, AppLocalizations l10n) {
    if (timestamp == null) return '';
    try {
      final parsed = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(parsed);
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return l10n.justNow;
    } catch (_) {
      return '';
    }
  }
}