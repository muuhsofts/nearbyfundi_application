// lib/providers/chat_provider.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatConversation> get conversations => _chatService.conversations.value;
  List<ChatMessage> get currentMessages => _chatService.currentMessages.value;
  int get totalUnread => _chatService.totalUnreadCount.value;
  bool get isTyping => _chatService.isTyping.value;

  // ✅ Use public getter
  ChatUser? get currentUser => _chatService.currentUser;

  bool isLoading = false;
  String? _error;

  String? get error => _error;

  ChatProvider() {
    _chatService.conversations.addListener(_onConversationsChanged);
    _chatService.currentMessages.addListener(_onMessagesChanged);
    _chatService.totalUnreadCount.addListener(_onUnreadChanged);
    _chatService.isTyping.addListener(_onTypingChanged);
  }

  void _onConversationsChanged() => notifyListeners();
  void _onMessagesChanged() => notifyListeners();
  void _onUnreadChanged() => notifyListeners();
  void _onTypingChanged() => notifyListeners();

  void initialize({required String token, required ChatUser currentUser}) {
    _chatService.initialize(token: token, currentUser: currentUser);
    _chatService.connectWebSocket();
  }

  Future<void> refreshConversations() async {
    isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _chatService.loadConversations();
    } catch (e) {
      _error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatConversation> createConversation({
    required int customerId,
    required int fundiId,
  }) async {
    try {
      _error = null;
      return await _chatService.createConversation(
        customerId: customerId,
        fundiId: fundiId,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<List<ChatMessage>> getMessages({
    required int conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      _error = null;
      isLoading = true;
      notifyListeners();
      return await _chatService.getMessages(
        conversationId: conversationId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    String? content,
    File? file,
    String messageType = 'text',
    int? voiceDuration,
  }) async {
    try {
      _error = null;
      return await _chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        file: file,
        messageType: messageType,
        voiceDuration: voiceDuration,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> markConversationAsRead(int conversationId) async {
    try {
      _error = null;
      await _chatService.markConversationAsRead(conversationId);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      _error = null;
      await _chatService.deleteMessage(messageId);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> addReaction(int messageId, String reaction) async {
    try {
      _error = null;
      await _chatService.addReaction(messageId, reaction);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> sendTypingStatus({
    required int conversationId,
    required bool typing,
  }) async {
    try {
      await _chatService.sendTypingStatus(
        conversationId: conversationId,
        typing: typing,
      );
    } catch (e) {
      // Don't set error for typing status
    }
  }

  /// ✅ Helper method to check if a message is from the current user
  bool isCurrentUserMessage(ChatMessage message) {
    return message.senderId == _chatService.currentUser?.id;
  }

  void subscribeToUser(int userId) {
    _chatService.subscribeToUser(userId);
  }

  void unsubscribeFromUser(int userId) {
    _chatService.unsubscribeFromUser(userId);
  }

  @override
  void dispose() {
    _chatService.conversations.removeListener(_onConversationsChanged);
    _chatService.currentMessages.removeListener(_onMessagesChanged);
    _chatService.totalUnreadCount.removeListener(_onUnreadChanged);
    _chatService.isTyping.removeListener(_onTypingChanged);
    _chatService.dispose();
    super.dispose();
  }
}