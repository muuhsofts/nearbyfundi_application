// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

/// Standard API response wrapper.
class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final Map<String, dynamic>? errors;
  final bool sessionExpired;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.sessionExpired = false,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    success: json['success'] ?? (json['status'] == 'success'),
    message: json['message'] ?? 'No message from server',
    data: json['data'],
    errors: json['errors'] as Map<String, dynamic>?,
  );
}

/// Main API service – handles all HTTP requests.
class ApiService {
  late final Dio _dio;
  void Function()? onSessionExpired;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          await StorageService.clearAll();
          onSessionExpired?.call();
        }
        return handler.next(e);
      },
    ));
  }

  // ============================================================
  //  AUTH ENDPOINTS
  // ============================================================

  /// Register a new customer.
  Future<ApiResponse> register(Map<String, dynamic> data) =>
      _post('/v1/auth/register', data: data);

  /// Register a new Fundi (technician).
  Future<ApiResponse> registerFundi(Map<String, dynamic> data) async {
    if (data.containsKey('profile_photo') && data['profile_photo'] is String) {
      final file = File(data['profile_photo']);
      final formData = FormData();

      data.forEach((key, value) {
        if (key == 'profile_photo') {
          // skip – added as file below
        } else if (key == 'service_ids' && value is List) {
          for (var id in value) {
            formData.fields.add(MapEntry('service_ids[]', id.toString()));
          }
        } else if (value != null) {
          formData.fields.add(MapEntry(key, value.toString()));
        }
      });

      formData.files.add(
        MapEntry('profile_photo', await MultipartFile.fromFile(file.path)),
      );

      return _post('/v1/auth/register-fundi', data: formData);
    }
    return _post('/v1/auth/register-fundi', data: data);
  }

  /// Login – `identifier` can be email or phone (backend checks both).
  Future<ApiResponse> login(String identifier, String password) =>
      _post('/v1/auth/login', data: {'email': identifier, 'password': password});

  /// Verify OTP.
  Future<ApiResponse> verifyOtp(String email, String otp, {String? fcmToken}) =>
      _post('/v1/auth/verify-otp', data: {
        'email': email,
        'otp': otp,
        if (fcmToken != null) 'fcm_token': fcmToken,
      });

  /// Request password reset OTP.
  Future<ApiResponse> forgotPassword(String email) =>
      _post('/v1/auth/forgot-password', data: {'email': email});

  /// Reset password with OTP.
  Future<ApiResponse> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) => _post('/v1/auth/reset-password', data: {
    'email': email,
    'otp': otp,
    'password': password,
    'password_confirmation': password,
  });

  /// Logout.
  Future<ApiResponse> logout() => _post('/v1/auth/logout');

  /// Get current user profile.
  Future<ApiResponse> getProfile() => _get('/v1/auth/me');

  /// Update user profile.
  Future<ApiResponse> updateProfile(Map<String, dynamic> data) =>
      _put('/v1/auth/profile', data: data);

  /// Change password.
  Future<ApiResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _post('/v1/auth/change-password', data: {
    'current_password': currentPassword,
    'password': newPassword,
    'password_confirmation': newPassword,
  });

  /// Update user locale.
  Future<ApiResponse> updateLocale(String locale) =>
      _post('/v1/auth/locale', data: {'locale': locale});

  /// Update FCM device token.
  Future<ApiResponse> updateDeviceToken(String token) =>
      _post('/v1/device-token', data: {'token': token});

  /// Delete account.
  Future<ApiResponse> deleteAccount() => _delete('/v1/auth/account');

  // ============================================================
  //  SERVICES
  // ============================================================

  /// Get list of all services.
  Future<ApiResponse> getServices() => _get('/v1/services');

  // ============================================================
  //  FUNDI – PROFILE & SERVICES
  // ============================================================

  Future<ApiResponse> getMyTechnicianProfile() =>
      _get('/v2/technicians/profile');

  Future<ApiResponse> updateTechnicianProfile(Map<String, dynamic> data) =>
      _put('/v2/technicians/profile', data: data);

  Future<ApiResponse> updateTechnicianServices(List<int> serviceIds) =>
      _post('/v2/technicians/services', data: {'service_ids': serviceIds});

  Future<ApiResponse> toggleOnlineStatus(bool online) =>
      _patch('/v2/technicians/online-status', data: {'is_online': online});

  // ============================================================
  //  FUNDI – HEARTBEAT & LOCATION
  // ============================================================

  Future<ApiResponse> sendHeartbeat() =>
      _post('/v2/technicians/heartbeat');

  Future<ApiResponse> updateLocation({
    required double latitude,
    required double longitude,
  }) => _post('/v2/technicians/location', data: {
    'latitude': latitude,
    'longitude': longitude,
  });

  Future<ApiResponse> resendOtp(String email) =>
      _post('/v1/auth/resend-otp', data: {'email': email});

  // ============================================================
  //  FUNDI – PROFILE PHOTO
  // ============================================================

  Future<ApiResponse> uploadProfilePhoto(File imageFile) async {
    final formData = FormData.fromMap({
      'profile_photo': await MultipartFile.fromFile(imageFile.path),
    });
    return _post('/v2/technicians/profile/photo', data: formData);
  }

  // ============================================================
  //  FUNDI – POSTS
  // ============================================================

  Future<ApiResponse> getMyPosts() => _get('/v5/my-posts');

  Future<ApiResponse> createPost(Map<String, dynamic> data) async {
    if (data.containsKey('image') && data['image'] is String && data['image'].isNotEmpty) {
      final file = File(data['image']);
      if (await file.exists()) {
        final formData = FormData.fromMap({
          'title': data['title'],
          'content': data['content'],
          'image': await MultipartFile.fromFile(file.path),
        });
        return _post('/v5/posts', data: formData);
      }
    }
    return _post('/v5/posts', data: {
      'title': data['title'],
      'content': data['content'],
    });
  }

  Future<ApiResponse> updatePost(int id, Map<String, dynamic> data) async {
    if (data.containsKey('image') && data['image'] is String && data['image'].isNotEmpty) {
      final file = File(data['image']);
      if (await file.exists()) {
        final formData = FormData.fromMap({
          '_method': 'PUT',
          'title': data['title'],
          'content': data['content'],
          'image': await MultipartFile.fromFile(file.path),
        });
        return _post('/v5/posts/$id', data: formData);
      }
    }
    return _put('/v5/posts/$id', data: {
      'title': data['title'],
      'content': data['content'],
    });
  }

  Future<ApiResponse> deletePost(int id) => _delete('/v5/posts/$id');

  // ============================================================
  //  FUNDI – PORTFOLIO (UPDATED: always send social fields)
  // ============================================================

  /// Get portfolios of the authenticated technician.
  Future<ApiResponse> getMyPortfolios() => _get('/v3/portfolios/my');

  /// Create a new portfolio item (with optional social links).
  Future<ApiResponse> createPortfolio(Map<String, dynamic> data) async {
    if (data.containsKey('image') && data['image'] is String && data['image'].isNotEmpty) {
      final file = File(data['image']);
      if (await file.exists()) {
        final formData = FormData();
        // Add all fields – even if they are null, send empty string
        data.forEach((key, value) {
          if (key == 'image') {
            // skip – added as file below
          } else {
            // Always add the field, using empty string if null
            formData.fields.add(MapEntry(key, value?.toString() ?? ''));
          }
        });
        formData.files.add(
          MapEntry('image', await MultipartFile.fromFile(file.path)),
        );
        return _post('/v3/portfolios', data: formData);
      }
    }
    // If no image (should not happen as image is required), send as JSON
    return _post('/v3/portfolios', data: data);
  }

  /// Update an existing portfolio item (including social links).
  Future<ApiResponse> updatePortfolio(int id, Map<String, dynamic> data) async {
    if (data.containsKey('image') && data['image'] is String && data['image'].isNotEmpty) {
      final file = File(data['image']);
      if (await file.exists()) {
        final formData = FormData();
        data.forEach((key, value) {
          if (key == 'image') {
            // skip – added as file below
          } else {
            // Always add the field, using empty string if null
            formData.fields.add(MapEntry(key, value?.toString() ?? ''));
          }
        });
        formData.files.add(
          MapEntry('image', await MultipartFile.fromFile(file.path)),
        );
        formData.fields.add(MapEntry('_method', 'PUT'));
        return _post('/v3/portfolios/$id', data: formData);
      }
    }
    return _put('/v3/portfolios/$id', data: data);
  }

  /// Delete a portfolio item.
  Future<ApiResponse> deletePortfolio(int id) => _delete('/v3/portfolios/$id');

  /// Update social links for a specific portfolio.
  Future<ApiResponse> updatePortfolioSocialLinks(int id, Map<String, dynamic> socialLinks) =>
      _put('/v3/portfolios/$id/social-links', data: socialLinks);

  /// Public: Get all portfolios (optionally filtered by technician).
  Future<ApiResponse> getPortfolios({int? technicianId, int page = 1}) =>
      _get('/v3/portfolios', query: {
        'page': page,
        if (technicianId != null) 'technician_id': technicianId,
      });

  /// Public: Get portfolios by a specific technician ID.
  Future<ApiResponse> getPortfoliosByTechnician(int technicianId) =>
      _get('/v3/portfolios/technician/$technicianId');

  // ============================================================
  //  REQUESTS
  // ============================================================

  Future<ApiResponse> createRequest(Map<String, dynamic> data) =>
      _post('/v4/requests', data: data);

  Future<ApiResponse> getMyRequests() => _get('/v4/my-requests');

  Future<ApiResponse> updateRequestStatus(int id, String status) =>
      _patch('/v4/requests/$id/status', data: {'status': status});

  Future<ApiResponse> cancelRequest(int id) =>
      _delete('/v4/requests/$id/cancel');

  // ============================================================
  //  BLOG
  // ============================================================

  Future<ApiResponse> getPosts({int page = 1, int? technicianId}) =>
      _get('/v1/posts', query: {
        'page': page,
        if (technicianId != null) 'technician_id': technicianId,
      });

  Future<ApiResponse> getPostDetail(int id) => _get('/v1/posts/$id');

  Future<ApiResponse> likePost(int postId) =>
      _post('/v5/posts/$postId/like');

  Future<ApiResponse> commentOnPost(int postId, String comment) =>
      _post('/v5/posts/$postId/comments', data: {'content': comment});

  Future<ApiResponse> deleteComment(int id) => _delete('/v5/comments/$id');

  // ============================================================
  //  STATIC PAGES
  // ============================================================

  Future<ApiResponse> getAbout() => _get('/v1/about');
  Future<ApiResponse> getFaqs() => _get('/v1/faqs');
  Future<ApiResponse> getTerms() => _get('/v1/terms');

  // ============================================================
  //  CONTACT
  // ============================================================

  Future<ApiResponse> sendContactMessage(Map<String, dynamic> data) =>
      _post('/v1/contact', data: data);

  // ============================================================
  //  CHAT ENDPOINTS (V14)
  // ============================================================

  Future<ApiResponse> getOrCreateConversation({
    required int customerId,
    required int fundiId,
  }) => _post('/v14/chat/conversation', data: {
    'customer_id': customerId,
    'fundi_id': fundiId,
  });

  Future<ApiResponse> getConversations() =>
      _get('/v14/chat/conversations');

  Future<ApiResponse> getMessages({
    required int conversationId,
    int limit = 50,
    int offset = 0,
  }) => _get('/v14/chat/conversations/$conversationId/messages', query: {
    'limit': limit,
    'offset': offset,
  });

  Future<ApiResponse> sendMessage({
    required int conversationId,
    String? content,
    String? filePath,
    String messageType = 'text',
    int? voiceDuration,
  }) async {
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final formData = FormData.fromMap({
          'conversation_id': conversationId,
          'content': content ?? '',
          'message_type': messageType,
          if (voiceDuration != null) 'voice_duration': voiceDuration,
          'file': await MultipartFile.fromFile(file.path),
        });
        return _post('/v14/chat/send', data: formData);
      }
    }
    final jsonData = {
      'conversation_id': conversationId,
      'content': content ?? '',
      'message_type': messageType,
      if (voiceDuration != null) 'voice_duration': voiceDuration,
    };
    return _post('/v14/chat/send', data: jsonData);
  }

  Future<ApiResponse> markMessageAsRead(int messageId) =>
      _put('/v14/chat/messages/$messageId/read');

  Future<ApiResponse> markConversationAsRead(int conversationId) =>
      _post('/v14/chat/conversations/$conversationId/read');

  Future<ApiResponse> deleteMessage(int messageId) =>
      _delete('/v14/chat/messages/$messageId');

  Future<ApiResponse> addReaction(int messageId, String reaction) =>
      _post('/v14/chat/messages/$messageId/reaction', data: {
        'reaction': reaction,
      });

  Future<ApiResponse> removeReaction(int messageId) =>
      _delete('/v14/chat/messages/$messageId/reaction');

  Future<ApiResponse> getUnreadCount() => _get('/v14/chat/unread');

  Future<ApiResponse> uploadChatFile(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    return _post('/v14/chat/upload', data: formData);
  }

  Future<ApiResponse> sendTypingStatus({
    required int conversationId,
    required bool isTyping,
  }) => _post('/v14/chat/typing', data: {
    'conversation_id': conversationId,
    'is_typing': isTyping,
  });

  Future<ApiResponse> downloadChatFile(int messageId) =>
      _get('/v14/chat/files/$messageId/download', query: {
        'download': 'true',
      });

  Future<String?> downloadChatFileToPath(int messageId, String savePath) async {
    try {
      final token = await StorageService.getToken();
      await _dio.download(
        '/v14/chat/files/$messageId/download?download=true',
        savePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          responseType: ResponseType.bytes,
        ),
      );
      return savePath;
    } catch (e) {
      debugPrint('❌ Download file error: $e');
      return null;
    }
  }

  Future<ApiResponse> getFileInfo(int messageId) =>
      _get('/v14/chat/files/$messageId/info');

  Future<ApiResponse> deleteFile(int messageId) =>
      _delete('/v14/chat/files/$messageId');

  Future<ApiResponse> deleteConversation(int conversationId) =>
      _delete('/v14/chat/conversations/$conversationId');

  // ============================================================
  //  NOTIFICATION ENDPOINTS (V15)
  // ============================================================

  Future<ApiResponse> getNotifications() =>
      _get('/v15/notifications');

  Future<ApiResponse> getUnreadNotificationCount() =>
      _get('/v15/notifications/unread-count');

  Future<ApiResponse> markNotificationAsRead(String notificationId) =>
      _put('/v15/notifications/$notificationId/read');

  Future<ApiResponse> markAllNotificationsAsRead() =>
      _put('/v15/notifications/read-all');

  Future<ApiResponse> deleteNotification(String notificationId) =>
      _delete('/v15/notifications/$notificationId');

  Future<ApiResponse> clearNotifications() =>
      _delete('/v15/notifications/clear');

  // ============================================================
  //  PRIVATE HELPERS
  // ============================================================

  Future<ApiResponse> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return ApiResponse.fromJson(res.data);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> _post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(path, data: data);
      return ApiResponse.fromJson(res.data);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> _put(String path, {dynamic data}) async {
    try {
      final res = await _dio.put(path, data: data);
      return ApiResponse.fromJson(res.data);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> _patch(String path, {dynamic data}) async {
    try {
      final res = await _dio.patch(path, data: data);
      return ApiResponse.fromJson(res.data);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> _delete(String path) async {
    try {
      final res = await _dio.delete(path);
      return ApiResponse.fromJson(res.data);
    } catch (e) {
      return _handleError(e);
    }
  }

  ApiResponse _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return ApiResponse(
          success: false,
          message: 'Invalid credentials.',
          sessionExpired: true,
        );
      }
      if (error.response?.statusCode == 422 && error.response?.data is Map) {
        return ApiResponse(
          success: false,
          message: error.response!.data['message'] ?? 'Validation failed',
          errors: error.response!.data['errors'],
        );
      }
      if (error.response?.data is Map) {
        return ApiResponse(
          success: false,
          message: error.response!.data['message'] ?? 'Something went wrong',
        );
      }
    }
    return ApiResponse(
      success: false,
      message: 'Network error. Please check your connection.',
    );
  }
}