// lib/screens/chat/chat_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_user.dart';
import '../../l10n/app_localizations.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    final user = authProvider.user;
    final token = authProvider.token;

    if (user != null && token != null) {
      final chatUser = ChatUser(
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        avatar: null,
        isOnline: false,
        lastSeen: null,
        fcmToken: null,
      );

      chatProvider.initialize(
        token: token,
        currentUser: chatUser,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.chat,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0.5,
        actions: [
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      chatProvider.refreshConversations();
                    },
                  ),
                  if (chatProvider.totalUnread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          chatProvider.totalUnread > 9 ? '9+' : '${chatProvider.totalUnread}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chatProvider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noConversationsYet,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startChattingWithFundis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.refreshConversations(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: chatProvider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = chatProvider.conversations[index];
                return _ConversationTile(
                  conversation: conversation,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatScreen(conversation: conversation),
                      ),
                    ).then((_) {
                      chatProvider.refreshConversations();
                    });
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: conversation.unreadCount > 0
              ? theme.primaryColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade300,
              child: Text(
                conversation.otherParty.name.isNotEmpty
                    ? conversation.otherParty.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherParty.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(conversation.lastMessageAt, l10n),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage?.content ?? l10n.noMessagesYet,
                          style: TextStyle(
                            fontSize: 14,
                            color: conversation.unreadCount > 0
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conversation.unreadCount > 9
                                ? '9+'
                                : '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateTime, AppLocalizations l10n) {
    if (dateTime == null) return '';
    try {
      final DateTime parsed = DateTime.parse(dateTime);
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