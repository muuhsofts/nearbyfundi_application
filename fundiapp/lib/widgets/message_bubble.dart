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

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onLongPress,
    this.onDownload,
    this.onDeleteFile, required Duration playbackPosition, required Duration playbackDuration, required bool isPlaying, void Function()? onPlayVoice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isImage = message.messageType == 'image';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
          style: TextStyle(
            color: isCurrentUser ? Colors.black87 : Colors.black87,
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
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 220,
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 220,
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  ),
                ),
                // Download button overlay
                if (onDownload != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.download, color: Colors.white, size: 20),
                        onPressed: onDownload,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ),
                // Delete button for own messages
                if (onDeleteFile != null && isCurrentUser)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                        onPressed: onDeleteFile,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (message.content != null && message.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                child: Text(
                  message.content!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        );

      case 'voice':
        return Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.play_circle_filled,
                color: isCurrentUser ? theme.primaryColor : theme.primaryColor,
                size: 32,
              ),
              onPressed: () {
                // Play voice
              },
            ),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? theme.primaryColor.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCurrentUser ? theme.primaryColor : Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${message.voiceDuration ?? 0}s',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        );

      case 'file':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(),
                    color: isCurrentUser ? Colors.green[700] : Colors.blue[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.file?.name ?? 'File',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (message.file?.size != null)
                          Text(
                            _formatFileSize(message.file!.size!),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Download button
                  if (onDownload != null)
                    IconButton(
                      icon: Icon(
                        Icons.download,
                        color: isCurrentUser ? Colors.green[700] : Colors.blue[700],
                        size: 22,
                      ),
                      onPressed: onDownload,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  // Delete file button (only for own messages)
                  if (onDeleteFile != null && isCurrentUser)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: onDeleteFile,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            if (message.content != null && message.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  message.content!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        );

      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 220,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (onDownload != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.download, color: Colors.white, size: 18),
                        onPressed: onDownload,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (message.content != null && message.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  message.content!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _getFileIcon() {
    final extension = message.file?.extension?.toLowerCase() ?? '';
    final name = message.file?.name?.toLowerCase() ?? '';

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico'].contains(extension)) {
      return Icons.image;
    }
    // PDF
    if (extension == 'pdf') return Icons.picture_as_pdf;
    // Word documents
    if (['doc', 'docx', 'odt'].contains(extension)) return Icons.description;
    // Excel
    if (['xls', 'xlsx', 'csv', 'ods'].contains(extension)) return Icons.table_chart;
    // PowerPoint
    if (['ppt', 'pptx', 'odp'].contains(extension)) return Icons.slideshow;
    // Archives
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) return Icons.folder_zip;
    // Audio
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'm4a'].contains(extension)) {
      return Icons.audiotrack;
    }
    // Video
    if (['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', 'm4v'].contains(extension)) {
      return Icons.video_library;
    }
    // Code files
    if (['js', 'ts', 'jsx', 'tsx', 'html', 'css', 'scss', 'json', 'xml', 'yaml', 'yml'].contains(extension)) {
      return Icons.code;
    }
    // Text files
    if (['txt', 'rtf', 'log'].contains(extension)) return Icons.text_fields;
    // Executable
    if (['exe', 'msi', 'dmg', 'pkg', 'deb', 'rpm'].contains(extension)) {
      return Icons.settings_applications;
    }
    // Database
    if (['sql', 'db', 'sqlite'].contains(extension)) return Icons.storage;
    // Font
    if (['ttf', 'otf', 'woff', 'woff2'].contains(extension)) return Icons.font_download;
    // Default
    return Icons.insert_drive_file;
  }

  Widget _buildTimestamp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
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
      final DateTime parsed = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(parsed);

      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return l10n.justNow;
      }
    } catch (_) {
      return '';
    }
  }
}