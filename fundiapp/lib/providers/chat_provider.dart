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

  bool isLoading = false;

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
    notifyListeners();
    await _chatService.loadConversations();
    isLoading = false;
    notifyListeners();
  }

  Future<ChatConversation> getOrCreateConversation({
    required int customerId,
    required int fundiId,
  }) async {
    return await _chatService.getOrCreateConversation(
      customerId: customerId,
      fundiId: fundiId,
    );
  }

  Future<List<ChatMessage>> getMessages({
    required int conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    return await _chatService.getMessages(
      conversationId: conversationId,
      limit: limit,
      offset: offset,
    );
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    String? content,
    File? file,
    String messageType = 'text',
    int? voiceDuration,
  }) async {
    return await _chatService.sendMessage(
      conversationId: conversationId,
      content: content,
      file: file,
      messageType: messageType,
      voiceDuration: voiceDuration,
    );
  }

  Future<void> markConversationAsRead(int conversationId) async {
    await _chatService.markConversationAsRead(conversationId);
  }

  Future<void> deleteMessage(int messageId) async {
    await _chatService.deleteMessage(messageId);
  }

  Future<void> addReaction(int messageId, String reaction) async {
    await _chatService.addReaction(messageId, reaction);
  }

  Future<void> sendTypingStatus({
    required int conversationId,
    required bool typing,
  }) async {
    await _chatService.sendTypingStatus(
      conversationId: conversationId,
      typing: typing,
    );
  }

  void subscribeToUser(int userId) {
    _chatService.subscribeToUser(userId);
  }

  void unsubscribeFromUser(int userId) {
    _chatService.unsubscribeFromUser(userId);
  }

  // ============================================
  // FILE OPERATIONS
  // ============================================

  Future<String?> downloadFile(int messageId, String savePath) async {
    return await _chatService.downloadFile(messageId, savePath);
  }

  Future<Map<String, dynamic>?> getFileInfo(int messageId) async {
    return await _chatService.getFileInfo(messageId);
  }

  Future<bool> deleteFile(int messageId) async {
    return await _chatService.deleteFile(messageId);
  }

  Future<bool> deleteConversation(int conversationId) async {
    return await _chatService.deleteConversation(conversationId);
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