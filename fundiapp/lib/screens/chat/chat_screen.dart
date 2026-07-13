// lib/screens/chat/chat_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';
import '../../l10n/app_localizations.dart';
import '../../services/voice_recording_service.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceRecordingService _voiceService = VoiceRecordingService();

  bool _isTyping = false;
  bool _isSending = false;
  bool _showEmojiPicker = false;

  // Voice recording states
  bool _isRecording = false;
  bool _isPlayingVoice = false;
  String? _recordingPath;
  double _amplitude = 0.0;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _markConversationAsRead();
      _subscribeToUser();
    });

    _voiceService.onRecordingStarted = _onRecordingStarted;
    _voiceService.onRecordingStopped = _onRecordingStopped;
    _voiceService.onAmplitudeChanged = _onAmplitudeChanged;
    _voiceService.onPlaybackStarted = _onPlaybackStarted;
    _voiceService.onPlaybackFinished = _onPlaybackFinished;
    _voiceService.onPlaybackPositionChanged = _onPlaybackPositionChanged;
    _voiceService.onPlaybackDurationChanged = _onPlaybackDurationChanged;
    _voiceService.onError = _onVoiceError;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  void _subscribeToUser() {
    final provider = context.read<ChatProvider>();
    provider.subscribeToUser(widget.conversation.otherParty.id);
  }

  Future<void> _loadMessages() async {
    final provider = context.read<ChatProvider>();
    await provider.getMessages(conversationId: widget.conversation.id);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markConversationAsRead() async {
    await context
        .read<ChatProvider>()
        .markConversationAsRead(widget.conversation.id);
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() => _isSending = true);

    try {
      await context.read<ChatProvider>().sendMessage(
        conversationId: widget.conversation.id,
        content: text,
        messageType: 'text',
      );
      _scrollToBottom();
      await _sendTypingStatus(false);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToSend}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendTypingStatus(bool typing) async {
    if (_isTyping != typing) {
      _isTyping = typing;
      await context.read<ChatProvider>().sendTypingStatus(
        conversationId: widget.conversation.id,
        typing: typing,
      );
    }
  }

  // ============================================
  // FILE PICKING METHODS
  // ============================================

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) {
      await _sendFile(File(image.path), 'image', '📷 Image');
    }
  }

  Future<void> _pickCamera() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) {
      await _sendFile(File(image.path), 'image', '📷 Photo');
    }
  }

  Future<void> _pickFile() async {
    try {
      // ✅ Use static method pickFiles() – works in all recent versions
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileName = result.files.first.name;
        await _sendFile(file, 'file', '📎 $fileName');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendFile(File file, String type, String content) async {
    setState(() => _isSending = true);
    try {
      await context.read<ChatProvider>().sendMessage(
        conversationId: widget.conversation.id,
        file: file,
        messageType: type,
        content: content,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        String errorMsg = type == 'image'
            ? l10n.failedToSendImage
            : l10n.failedToSendFile;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMsg: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // ============================================
  // VOICE RECORDING METHODS
  // ============================================

  void _startVoiceRecording() async {
    try {
      await _voiceService.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _stopVoiceRecording() async {
    try {
      final path = await _voiceService.stopRecording();
      if (path != null && mounted) {
        final file = File(path);
        await _sendFile(file, 'voice', '🎤 Voice message');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelVoiceRecording() async {
    await _voiceService.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
  }

  void _playVoiceMessage(String path) async {
    try {
      if (_voiceService.isPlaying) {
        await _voiceService.stopPlayback();
        setState(() {
          _isPlayingVoice = false;
        });
      } else {
        await _voiceService.playRecording(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play voice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // VOICE SERVICE CALLBACKS
  // ============================================

  void _onRecordingStarted() {
    setState(() {
      _isRecording = true;
      _recordingDuration = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration++);
    });
  }

  void _onRecordingStopped(String path) {
    setState(() {
      _isRecording = false;
      _recordingPath = path;
    });
    _recordingTimer?.cancel();
  }

  void _onAmplitudeChanged(double amplitude) {
    setState(() {
      _amplitude = amplitude;
    });
  }

  void _onPlaybackStarted() {
    setState(() => _isPlayingVoice = true);
  }

  void _onPlaybackFinished() {
    setState(() {
      _isPlayingVoice = false;
      _playbackPosition = Duration.zero;
    });
  }

  void _onPlaybackPositionChanged(Duration position) {
    setState(() => _playbackPosition = position);
  }

  void _onPlaybackDurationChanged(Duration duration) {
    setState(() => _playbackDuration = duration);
  }

  void _onVoiceError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================
  // FILE DOWNLOAD/DELETE METHODS
  // ============================================

  Future<void> _downloadFile(ChatMessage message) async {
    if (message.file == null) return;

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.storagePermissionDenied)),
          );
          return;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.photosPermissionDenied)),
          );
          return;
        }
      }

      String savePath;
      final fileName = message.file!.name ?? 'file_${message.id}';
      final extension = message.file!.extension ?? '';
      final fullFileName = extension.isNotEmpty ? '$fileName.$extension' : fileName;

      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory == null) throw Exception('Could not access storage');
        final downloadDir = Directory('${directory.path}/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        savePath = '${downloadDir.path}/$fullFileName';
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}/$fullFileName';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}/$fullFileName';
      }

      final provider = context.read<ChatProvider>();
      final result = await provider.downloadFile(message.id, savePath);

      if (result != null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${l10n.fileDownloaded}: $fullFileName'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFile.open(savePath),
              ),
            ),
          );
        }
      } else {
        throw Exception('Download failed');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.downloadFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(ChatMessage message) async {
    if (message.file == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = context.read<ChatProvider>();
      final success = await provider.deleteFile(message.id);
      if (success && mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fileDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ============================================
  // CONVERSATION DELETE
  // ============================================

  Future<void> _deleteConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this entire conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = context.read<ChatProvider>();
      final success = await provider.deleteConversation(widget.conversation.id);
      if (success && mounted) {
        Navigator.pop(context);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.conversationDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ============================================
  // BUILD METHODS
  // ============================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(context, theme, l10n),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.currentMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.currentMessages.isEmpty) {
                  return _buildEmptyState(context, l10n);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  reverse: true,
                  itemCount: provider.currentMessages.length,
                  itemBuilder: (context, index) {
                    final message = provider.currentMessages[
                    provider.currentMessages.length - 1 - index];
                    final isCurrentUser = message.senderType == 'fundi';

                    return MessageBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                      onLongPress: () {
                        _showMessageOptions(context, message);
                      },
                      onDownload: message.file != null
                          ? () => _downloadFile(message)
                          : null,
                      onDeleteFile: message.file != null && message.senderType == 'fundi'
                          ? () => _deleteFile(message)
                          : null,
                      onPlayVoice: message.isVoice && message.file?.url != null
                          ? () => _playVoiceMessage(message.file!.url!)
                          : null,
                      isPlaying: _isPlayingVoice,
                      playbackPosition: _playbackPosition,
                      playbackDuration: _playbackDuration,
                    );
                  },
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, provider, child) {
              if (provider.isTyping) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TypingIndicator(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _buildMessageInput(context, theme, l10n),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final otherParty = widget.conversation.otherParty;

    return AppBar(
      backgroundColor: const Color(0xFF075E54),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: otherParty.avatar != null
                ? ClipOval(
              child: Image.network(
                otherParty.avatar!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  otherParty.name.isNotEmpty ? otherParty.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
                : Text(
              otherParty.name.isNotEmpty ? otherParty.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherParty.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  otherParty.isOnline ? l10n.online : l10n.lastSeen,
                  style: TextStyle(
                    fontSize: 12,
                    color: otherParty.isOnline
                        ? Colors.lightGreenAccent
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoCallScreen(
                  userName: otherParty.name,
                  userId: otherParty.id.toString(),
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.phone, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VoiceCallScreen(
                  userName: otherParty.name,
                  userId: otherParty.id.toString(),
                ),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'delete_conversation') {
              _deleteConversation();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_profile',
              child: Text('View Profile'),
            ),
            const PopupMenuItem(
              value: 'clear_chat',
              child: Text('Clear Chat'),
            ),
            const PopupMenuItem(
              value: 'delete_conversation',
              child: Text(
                'Delete Conversation',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade200,
            child: Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMessagesYet,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sayHelloToStart,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              PopupMenuButton<String>(
                icon: Icon(Icons.attach_file, color: Colors.grey.shade600, size: 26),
                onSelected: (value) {
                  if (value == 'camera') _pickCamera();
                  else if (value == 'gallery') _pickImage();
                  else if (value == 'document') _pickFile();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'camera',
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt, size: 22),
                        SizedBox(width: 12),
                        Text('Camera'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'gallery',
                    child: Row(
                      children: [
                        Icon(Icons.photo_library, size: 22),
                        SizedBox(width: 12),
                        Text('Gallery'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'document',
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file, size: 22),
                        SizedBox(width: 12),
                        Text('Document'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: (text) {
                      setState(() {});
                      _sendTypingStatus(text.isNotEmpty);
                    },
                    decoration: InputDecoration(
                      hintText: l10n.typeAMessage,
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: Colors.grey.shade600,
                  size: 26,
                ),
                onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
              ),
              if (_textController.text.trim().isNotEmpty)
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF075E54),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.send, color: Colors.white, size: 22),
                    onPressed: _isSending ? null : _sendMessage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onLongPress: _startVoiceRecording,
                  onLongPressEnd: (_) => _stopVoiceRecording(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red.withOpacity(0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isRecording)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                            child: _buildAmplitudeWaveform(),
                          ),
                        IconButton(
                          icon: Icon(
                            _isRecording ? Icons.stop_circle : Icons.mic,
                            color: _isRecording ? Colors.red : Colors.grey.shade600,
                            size: 26,
                          ),
                          onPressed: null,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.red, size: 12),
                const SizedBox(width: 8),
                const Text(
                  'Recording...',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_recordingDuration}s',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _cancelVoiceRecording,
                ),
              ],
            ),
          ),
        if (_showEmojiPicker)
          Container(
            height: 300,
            color: Colors.white,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                final text = _textController.text;
                _textController.text = '$text${emoji.emoji}';
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
                setState(() {});
              },
              onBackspacePressed: () {
                final text = _textController.text;
                if (text.isNotEmpty) {
                  _textController.text = text.substring(0, text.length - 1);
                  _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textController.text.length),
                  );
                }
              },
              // ✅ Omit config to use defaults – avoids version-specific class name issues
            ),
          ),
      ],
    );
  }

  Widget _buildAmplitudeWaveform() {
    const bars = 6;
    // Ensure amplitude is a double
    final amplitude = (_amplitude * 100).clamp(5, 100).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(bars, (index) {
        // Convert height to double
        final height = (amplitude / 100 * 20 * (0.5 + 0.5 * (index / bars)))
            .clamp(4, 20)
            .toDouble();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (message.content != null && message.content!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.content_copy, color: Colors.blue),
                  title: Text(l10n.copy),
                  onTap: () {
                    Navigator.pop(context);
                    if (message.content != null) {
                      Clipboard.setData(ClipboardData(text: message.content!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.messageCopied),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              if (message.file != null)
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.green),
                  title: Text(l10n.downloadFile),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadFile(message);
                  },
                ),
              if (message.file != null && message.senderType == 'fundi')
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(l10n.deleteFile, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteFile(message);
                  },
                ),
              if (message.isVoice && message.file?.url != null)
                ListTile(
                  leading: Icon(
                    _isPlayingVoice ? Icons.pause : Icons.play_arrow,
                    color: Colors.blue,
                  ),
                  title: Text(_isPlayingVoice ? 'Pause Voice' : 'Play Voice'),
                  onTap: () {
                    Navigator.pop(context);
                    _playVoiceMessage(message.file!.url!);
                  },
                ),
              if (message.senderType == 'fundi')
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(l10n.deleteMessage, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<ChatProvider>().deleteMessage(message.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.messageDeleted),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}