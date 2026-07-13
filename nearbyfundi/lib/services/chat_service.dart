// lib/services/chat_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as path;
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService = ApiService();

  // State
  final ValueNotifier<List<ChatConversation>> conversations = ValueNotifier([]);
  final ValueNotifier<List<ChatMessage>> currentMessages = ValueNotifier([]);
  final ValueNotifier<int> totalUnreadCount = ValueNotifier(0);
  final ValueNotifier<bool> isTyping = ValueNotifier(false);

  WebSocketChannel? _channel;
  String? _token;
  ChatUser? _currentUser;

  // ✅ Public getter for current user
  ChatUser? get currentUser => _currentUser;

  // Active subscriptions
  final Set<int> _subscribedUsers = {};

  void initialize({required String token, required ChatUser currentUser}) {
    _token = token;
    _currentUser = currentUser;
    _apiService.onSessionExpired = _handleSessionExpired;

    // Load initial data
    loadConversations();
    loadUnreadCount();
  }

  void _handleSessionExpired() {
    // Handle session expiry
    conversations.value = [];
    currentMessages.value = [];
    totalUnreadCount.value = 0;
  }

  // ============================================================
  //  WEB SOCKET CONNECTION
  // ============================================================

  void connectWebSocket() {
    if (_channel != null) return;

    try {
      // Construct WebSocket URL with token
      final wsUrl = _getWebSocketUrl();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
            (message) => _handleWebSocketMessage(message),
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _reconnectWebSocket();
        },
        onDone: () {
          debugPrint('WebSocket disconnected');
          _reconnectWebSocket();
        },
      );

      debugPrint('WebSocket connected');
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
      _reconnectWebSocket();
    }
  }

  String _getWebSocketUrl() {
    // Replace http with ws and add token
    final baseUrl = _apiService.dio.options.baseUrl;
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    return '$wsBase/chat/ws?token=$_token';
  }

  void _reconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;

    // Attempt to reconnect after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (_token != null) {
        connectWebSocket();
      }
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final event = data['event'] as String?;

      switch (event) {
        case 'new_message':
          _handleNewMessage(data['data']);
          break;
        case 'message_read':
          _handleMessageRead(data['data']);
          break;
        case 'user_typing':
          _handleUserTyping(data['data']);
          break;
        case 'user_online':
          _handleUserOnline(data['data']);
          break;
        case 'user_offline':
          _handleUserOffline(data['data']);
          break;
        default:
          debugPrint('Unknown WebSocket event: $event');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    final message = ChatMessage.fromJson(data);

    // Add to current messages if in the same conversation
    final currentMessagesList = currentMessages.value;
    if (currentMessagesList.isNotEmpty &&
        currentMessagesList.first.conversationId == message.conversationId) {
      currentMessagesList.insert(0, message);
      currentMessages.value = currentMessagesList;
    }

    // Update conversations list
    _updateConversationWithMessage(message);

    // Update unread count
    if (message.receiverId == _currentUser?.id) {
      totalUnreadCount.value += 1;
    }
  }

  void _handleMessageRead(dynamic data) {
    final messageId = data['message_id'] as int?;
    if (messageId == null) return;

    // Update message read status in current messages
    final messages = currentMessages.value;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = ChatMessage(
        id: messages[index].id,
        conversationId: messages[index].conversationId,
        senderId: messages[index].senderId,
        senderName: messages[index].senderName,
        senderType: messages[index].senderType,
        receiverId: messages[index].receiverId,
        messageType: messages[index].messageType,
        content: messages[index].content,
        isRead: true,
        readAt: data['read_at'],
        isDelivered: messages[index].isDelivered,
        deliveredAt: messages[index].deliveredAt,
        createdAt: messages[index].createdAt,
        file: messages[index].file,
        voiceDuration: messages[index].voiceDuration,
      );
      currentMessages.value = messages;
    }

    // Update unread count
    loadUnreadCount();
  }

  void _handleUserTyping(dynamic data) {
    final userId = data['user_id'] as int?;
    final typing = data['is_typing'] as bool? ?? false;

    // Only show typing indicator if the user is in the current conversation
    final messages = currentMessages.value;
    if (messages.isNotEmpty) {
      final conversationId = messages.first.conversationId;
      try {
        final conversation = conversations.value.firstWhere(
              (c) => c.id == conversationId,
        );
        if (conversation.otherParty.id == userId) {
          isTyping.value = typing;
        }
      } catch (_) {
        // Conversation not found
      }
    }
  }

  void _handleUserOnline(dynamic data) {
    final userId = data['user_id'] as int?;
    if (userId == null) return;

    // Update online status in conversations
    final convs = conversations.value;
    for (var i = 0; i < convs.length; i++) {
      if (convs[i].otherParty.id == userId) {
        final updated = ChatConversation(
          id: convs[i].id,
          customerId: convs[i].customerId,
          fundiId: convs[i].fundiId,
          customer: convs[i].customer,
          fundi: convs[i].fundi,
          otherParty: ChatUser(
            id: convs[i].otherParty.id,
            name: convs[i].otherParty.name,
            email: convs[i].otherParty.email,
            phone: convs[i].otherParty.phone,
            avatar: convs[i].otherParty.avatar,
            isOnline: true,
            lastSeen: convs[i].otherParty.lastSeen,
            fcmToken: convs[i].otherParty.fcmToken,
          ),
          lastMessage: convs[i].lastMessage,
          unreadCount: convs[i].unreadCount,
          lastMessageAt: convs[i].lastMessageAt,
          isActive: convs[i].isActive,
        );
        convs[i] = updated;
        conversations.value = convs;
        break;
      }
    }
  }

  void _handleUserOffline(dynamic data) {
    final userId = data['user_id'] as int?;
    if (userId == null) return;

    // Update online status in conversations
    final convs = conversations.value;
    for (var i = 0; i < convs.length; i++) {
      if (convs[i].otherParty.id == userId) {
        final updated = ChatConversation(
          id: convs[i].id,
          customerId: convs[i].customerId,
          fundiId: convs[i].fundiId,
          customer: convs[i].customer,
          fundi: convs[i].fundi,
          otherParty: ChatUser(
            id: convs[i].otherParty.id,
            name: convs[i].otherParty.name,
            email: convs[i].otherParty.email,
            phone: convs[i].otherParty.phone,
            avatar: convs[i].otherParty.avatar,
            isOnline: false,
            lastSeen: data['last_seen'] ?? convs[i].otherParty.lastSeen,
            fcmToken: convs[i].otherParty.fcmToken,
          ),
          lastMessage: convs[i].lastMessage,
          unreadCount: convs[i].unreadCount,
          lastMessageAt: convs[i].lastMessageAt,
          isActive: convs[i].isActive,
        );
        convs[i] = updated;
        conversations.value = convs;
        break;
      }
    }
  }

  void _updateConversationWithMessage(ChatMessage message) {
    final convs = conversations.value;
    final index = convs.indexWhere((c) => c.id == message.conversationId);

    if (index != -1) {
      // Update existing conversation
      final conv = convs[index];
      final updated = ChatConversation(
        id: conv.id,
        customerId: conv.customerId,
        fundiId: conv.fundiId,
        customer: conv.customer,
        fundi: conv.fundi,
        otherParty: conv.otherParty,
        lastMessage: message,
        unreadCount: conv.unreadCount + (message.receiverId == _currentUser?.id ? 1 : 0),
        lastMessageAt: message.createdAt ?? conv.lastMessageAt,
        isActive: conv.isActive,
      );
      convs.removeAt(index);
      convs.insert(0, updated);
      conversations.value = convs;
    } else {
      // This shouldn't happen, but just in case
      loadConversations();
    }
  }

  // ============================================================
  //  API METHODS
  // ============================================================

  Future<ChatConversation> createConversation({
    required int customerId,
    required int fundiId,
  }) async {
    try {
      final response = await _apiService.getOrCreateConversation(
        customerId: customerId,
        fundiId: fundiId,
      );

      if (response.success && response.data != null) {
        final conversation = ChatConversation.fromJson(response.data);
        // Add to conversations list if not already there
        final convs = conversations.value;
        if (!convs.any((c) => c.id == conversation.id)) {
          convs.insert(0, conversation);
          conversations.value = convs;
        }
        return conversation;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      throw Exception('Failed to create conversation: $e');
    }
  }

  Future<void> loadConversations() async {
    try {
      final response = await _apiService.getConversations();

      if (response.success && response.data != null) {
        final data = response.data as List;
        final loaded = data.map((item) => ChatConversation.fromJson(item)).toList();
        conversations.value = loaded;
      } else {
        debugPrint('Failed to load conversations: ${response.message}');
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<List<ChatMessage>> getMessages({
    required int conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiService.getMessages(
        conversationId: conversationId,
        limit: limit,
        offset: offset,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final messagesList = data['messages'] as List? ?? [];
        final messages = messagesList.map((item) => ChatMessage.fromJson(item)).toList();
        currentMessages.value = messages;
        return messages;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      throw Exception('Failed to load messages: $e');
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
      String? filePath;
      if (file != null && await file.exists()) {
        filePath = file.path;
      }

      final response = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content,
        filePath: filePath,
        messageType: messageType,
        voiceDuration: voiceDuration,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('message')) {
          final message = ChatMessage.fromJson(data['message']);
          // Add to current messages
          final messages = currentMessages.value;
          messages.insert(0, message);
          currentMessages.value = messages;

          // Update conversation
          _updateConversationWithMessage(message);

          return message;
        } else {
          throw Exception('No message data in response');
        }
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> markConversationAsRead(int conversationId) async {
    try {
      final response = await _apiService.markConversationAsRead(conversationId);

      if (response.success) {
        // Update conversation unread count
        final convs = conversations.value;
        final index = convs.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          final conv = convs[index];
          convs[index] = ChatConversation(
            id: conv.id,
            customerId: conv.customerId,
            fundiId: conv.fundiId,
            customer: conv.customer,
            fundi: conv.fundi,
            otherParty: conv.otherParty,
            lastMessage: conv.lastMessage,
            unreadCount: 0,
            lastMessageAt: conv.lastMessageAt,
            isActive: conv.isActive,
          );
          conversations.value = convs;
        }

        // Mark messages in current view as read
        final messages = currentMessages.value;
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].conversationId == conversationId && !messages[i].isRead) {
            messages[i] = ChatMessage(
              id: messages[i].id,
              conversationId: messages[i].conversationId,
              senderId: messages[i].senderId,
              senderName: messages[i].senderName,
              senderType: messages[i].senderType,
              receiverId: messages[i].receiverId,
              messageType: messages[i].messageType,
              content: messages[i].content,
              isRead: true,
              readAt: DateTime.now().toIso8601String(),
              isDelivered: messages[i].isDelivered,
              deliveredAt: messages[i].deliveredAt,
              createdAt: messages[i].createdAt,
              file: messages[i].file,
              voiceDuration: messages[i].voiceDuration,
            );
          }
        }
        currentMessages.value = messages;

        // Update unread count
        loadUnreadCount();
      }
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      final response = await _apiService.deleteMessage(messageId);

      if (response.success) {
        // Remove from current messages
        final messages = currentMessages.value;
        messages.removeWhere((m) => m.id == messageId);
        currentMessages.value = messages;

        // Update conversation last message if needed
        loadConversations();
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> addReaction(int messageId, String reaction) async {
    try {
      final response = await _apiService.addReaction(messageId, reaction);

      if (!response.success) {
        debugPrint('Failed to add reaction: ${response.message}');
      }
    } catch (e) {
      debugPrint('Error adding reaction: $e');
    }
  }

  Future<void> sendTypingStatus({
    required int conversationId,
    required bool typing,
  }) async {
    try {
      await _apiService.sendTypingStatus(
        conversationId: conversationId,
        isTyping: typing,
      );
    } catch (e) {
      // Don't throw - typing status is not critical
      debugPrint('Error sending typing status: $e');
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final response = await _apiService.getUnreadCount();

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        totalUnreadCount.value = data['total_unread'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  // ============================================================
  //  SUBSCRIPTION METHODS
  // ============================================================

  void subscribeToUser(int userId) {
    if (_subscribedUsers.contains(userId)) return;
    _subscribedUsers.add(userId);
    _sendSubscriptionMessage('subscribe', userId);
  }

  void unsubscribeFromUser(int userId) {
    if (!_subscribedUsers.contains(userId)) return;
    _subscribedUsers.remove(userId);
    _sendSubscriptionMessage('unsubscribe', userId);
  }

  void _sendSubscriptionMessage(String action, int userId) {
    if (_channel == null) return;

    try {
      final message = jsonEncode({
        'action': action,
        'user_id': userId,
      });
      _channel!.sink.add(message);
    } catch (e) {
      debugPrint('Error sending subscription message: $e');
    }
  }

  // ============================================================
  //  DISPOSAL
  // ============================================================

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    conversations.dispose();
    currentMessages.dispose();
    totalUnreadCount.dispose();
    isTyping.dispose();
  }
}