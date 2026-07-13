// lib/screens/chat/chat_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';  // ADD THIS IMPORT
import '../../providers/chat_provider.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _markConversationAsRead();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          _scrollController.position.maxScrollExtent,
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


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _isSending = true);
      try {
        await context.read<ChatProvider>().sendMessage(
          conversationId: widget.conversation.id,
          file: File(image.path),
          messageType: 'image',
          content: '📷 Image',
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.failedToSendImage}: $e'),
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
  }

  Future<void> _pickFile() async {
    try {
      // For version 10.3.10, we use FilePicker.platform.pickFiles
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        setState(() => _isSending = true);
        try {
          await context.read<ChatProvider>().sendMessage(
            conversationId: widget.conversation.id,
            file: file,
            messageType: 'file',
            content: '📎 ${result.files.first.name}',
          );
          _scrollToBottom();
        } catch (e) {
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l10n.failedToSendFile}: $e'),
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
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToSendFile}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVoice() async {
    // Note: For voice recording, you'd typically use a recording package
    // This is a placeholder - you can implement actual voice recording
    // using packages like record, flutter_sound, etc.
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.voiceRecordingComingSoon),
        backgroundColor: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: screenWidth > 600 ? 20 : 18,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                widget.conversation.otherParty.name[0].toUpperCase(),
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.otherParty.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.conversation.otherParty.isOnline)
                  Text(
                    l10n.online,
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options (clear chat, view profile, etc.)
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.currentMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.currentMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noMessagesYet,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          l10n.sayHelloToStart,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  reverse: true,
                  itemCount: provider.currentMessages.length,
                  itemBuilder: (context, index) {
                    final message = provider.currentMessages[
                    provider.currentMessages.length - 1 - index];
                    // Fixed: Determine if current user by comparing sender ID with current user
                    // We'll use a different approach - pass isCurrentUser from provider
                    final isCurrentUser = message.senderType == 'customer';

                    return MessageBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                      onLongPress: () {
                        _showMessageOptions(context, message);
                      },
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
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo button
          IconButton(
            icon: Icon(Icons.photo, color: theme.primaryColor, size: screenWidth > 600 ? 28 : 24),
            onPressed: _isSending ? null : _pickImage,
          ),
          // Attachment button
          IconButton(
            icon: Icon(Icons.attach_file, color: theme.primaryColor, size: screenWidth > 600 ? 28 : 24),
            onPressed: _isSending ? null : _pickFile,
          ),
          // Voice button (optional)
          IconButton(
            icon: Icon(Icons.mic, color: theme.primaryColor, size: screenWidth > 600 ? 28 : 24),
            onPressed: _isSending ? null : _pickVoice,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              onChanged: (text) {
                setState(() {});
                _sendTypingStatus(text.isNotEmpty);
              },
              decoration: InputDecoration(
                hintText: l10n.typeAMessage,
                hintStyle: theme.textTheme.bodySmall,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey.shade100,
                filled: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Icon(
              Icons.send,
              color: _textController.text.trim().isNotEmpty
                  ? theme.primaryColor
                  : Colors.grey,
              size: screenWidth > 600 ? 28 : 24,
            ),
            onPressed:
            _textController.text.trim().isNotEmpty && !_isSending
                ? _sendMessage
                : null,
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            if (message.content != null && message.content!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: Text(l10n.copy),
                onTap: () {
                  Navigator.pop(context);
                  if (message.content != null) {
                    Clipboard.setData(ClipboardData(text: message.content!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.messageCopied),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.delete),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().deleteMessage(message.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.messageDeleted),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}