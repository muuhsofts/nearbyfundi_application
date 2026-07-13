import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import 'storage_service.dart';

/// Standard API response wrapper
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

  /// Parse JSON response from Laravel backend.
  /// Handles both `"success": true` and `"status": "success"` formats.
  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    success: json['success'] ?? (json['status'] == 'success'),
    message: json['message'] ?? 'No message from server',
    data: json['data'],
    errors: json['errors'] as Map<String, dynamic>?,
  );
}

/// Main API service – handles all HTTP requests to the backend.
class ApiService {
  late final Dio _dio;
  void Function()? onSessionExpired;

  // Expose Dio for WebSocket URL construction
  Dio get dio => _dio;

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

  /// 1. Register a new customer (email, name, password, optional phone)
  Future<ApiResponse> register(Map<String, dynamic> data) =>
      _post('/v1/auth/register', data: data);

  /// 2. Register a new Fundi (technician) with profile photo and services
  Future<ApiResponse> registerFundi(Map<String, dynamic> data) async {
    // If profile_photo is a File path, send as multipart
    if (data.containsKey('profile_photo') && data['profile_photo'] is String) {
      final file = File(data['profile_photo']);
      if (await file.exists()) {
        final formData = FormData();

        // Add all fields except profile_photo
        data.forEach((key, value) {
          if (key == 'profile_photo') return;
          if (key == 'service_ids' && value is List) {
            for (var id in value) {
              formData.fields.add(MapEntry('service_ids[]', id.toString()));
            }
          } else if (value != null) {
            formData.fields.add(MapEntry(key, value.toString()));
          }
        });

        // Add profile photo
        formData.files.add(
          MapEntry('profile_photo', await MultipartFile.fromFile(file.path)),
        );

        return _post('/v1/auth/register-fundi', data: formData);
      }
    }
    // Fallback: send as JSON (without file)
    return _post('/v1/auth/register-fundi', data: data);
  }

  /// 3. Login – identifier can be email or phone (backend checks both)
  Future<ApiResponse> login(String identifier, String password) =>
      _post('/v1/auth/login', data: {'email': identifier, 'password': password});

  /// 4. Verify OTP – optionally pass FCM token
  Future<ApiResponse> verifyOtp(String email, String otp, {String? fcmToken}) =>
      _post('/v1/auth/verify-otp', data: {
        'email': email,
        'otp': otp,
        if (fcmToken != null) 'fcm_token': fcmToken,
      });

  /// 5. Resend OTP for email verification
  Future<ApiResponse> resendOtp(String email) =>
      _post('/v1/auth/resend-otp', data: {'email': email});

  /// 6. Request password reset OTP
  Future<ApiResponse> forgotPassword(String email) =>
      _post('/v1/auth/forgot-password', data: {'email': email});

  /// 7. Reset password with OTP
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

  /// 8. Logout user
  Future<ApiResponse> logout() => _post('/v1/auth/logout');

  /// 9. Get current user profile
  Future<ApiResponse> getProfile() => _get('/v1/auth/me');

  /// 10. Update user profile (name, phone, locale)
  Future<ApiResponse> updateProfile(Map<String, dynamic> data) =>
      _put('/v1/auth/profile', data: data);

  /// 11. Change user password
  Future<ApiResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _post('/v1/auth/change-password', data: {
    'current_password': currentPassword,
    'password': newPassword,
    'password_confirmation': newPassword,
  });

  /// 12. Update user locale/language preference
  Future<ApiResponse> updateLocale(String locale) =>
      _post('/v1/auth/locale', data: {'locale': locale});

  /// 13. Update device token for push notifications
  Future<ApiResponse> updateDeviceToken(String token) =>
      _post('/v1/device-token', data: {'token': token});

  /// 14. Delete user account
  Future<ApiResponse> deleteAccount() => _delete('/v1/auth/account');

  // ============================================================
  //  SERVICES
  // ============================================================

  /// 15. Get all services
  Future<ApiResponse> getServices() => _get('/v1/services');

  // ============================================================
  //  TECHNICIANS (Customer side)
  // ============================================================

  /// 16. Get nearby technicians by coordinates
  Future<ApiResponse> getNearbyTechnicians({
    required double lat,
    required double lng,
    int radius = 10,
    int? serviceId,
  }) => _get('/v1/technicians/nearby', query: {
    'lat': lat,
    'lng': lng,
    'radius': radius,
    if (serviceId != null) 'service_id': serviceId,
  });

  /// 17. Search technicians by place name (OpenStreetMap)
  Future<ApiResponse> searchTechniciansByPlace({
    required String place,
    int? serviceId,
    int radius = 10,
  }) => _get('/v1/technicians/nearby-by-place', query: {
    'place': place,
    if (serviceId != null) 'service_id': serviceId,
    'radius': radius,
  });

  /// 18. Get technician detail by ID
  Future<ApiResponse> getTechnicianDetail(int id) =>
      _get('/v1/technicians/$id');

  // ============================================================
  //  TECHNICIAN PROFILE (Fundi side)
  // ============================================================

  /// 19. Get the authenticated technician's profile
  Future<ApiResponse> getTechnicianProfile() =>
      _get('/v1/technicians/profile');

  /// 20. Update technician services
  Future<ApiResponse> updateTechnicianServices(List<int> serviceIds) =>
      _put('/v1/technicians/services', data: {'service_ids': serviceIds});

  /// 21. Toggle technician online status
  Future<ApiResponse> toggleTechnicianOnline(bool isOnline) =>
      _post('/v1/technicians/toggle-online', data: {'is_online': isOnline});

  /// 22. Update technician location
  Future<ApiResponse> updateTechnicianLocation(double latitude, double longitude) =>
      _post('/v1/technicians/update-location', data: {
        'latitude': latitude,
        'longitude': longitude,
      });

  /// 23. Send heartbeat to keep technician online
  Future<ApiResponse> sendTechnicianHeartbeat({
    double? latitude,
    double? longitude,
  }) => _post('/v1/technicians/heartbeat', data: {
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  });

  /// 24. Upload technician profile photo
  Future<ApiResponse> uploadTechnicianPhoto(File imageFile) async {
    final formData = FormData.fromMap({
      'profile_photo': await MultipartFile.fromFile(
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
    });
    return _post('/v1/technicians/upload-photo', data: formData);
  }

  // ============================================================
  //  PORTFOLIOS
  // ============================================================

  /// 25. Get technician portfolio by technician ID
  Future<ApiResponse> getTechnicianPortfolio(int technicianId) =>
      _get('/v1/portfolios/$technicianId');

  /// 26. Get my portfolios (authenticated technician)
  Future<ApiResponse> getMyPortfolios() =>
      _get('/v1/portfolios/my');

  /// 27. Create a new portfolio item
  Future<ApiResponse> createPortfolio({
    required File imageFile,
    String? description,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
      if (description != null) 'description': description,
    });
    return _post('/v1/portfolios', data: formData);
  }

  /// 28. Update portfolio item
  Future<ApiResponse> updatePortfolio(int id, {
    File? imageFile,
    String? description,
  }) async {
    if (imageFile != null) {
      final formData = FormData.fromMap({
        '_method': 'PUT',
        if (description != null) 'description': description,
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      });
      return _post('/v1/portfolios/$id', data: formData);
    }
    return _put('/v1/portfolios/$id', data: {
      if (description != null) 'description': description,
    });
  }

  /// 29. Delete portfolio item
  Future<ApiResponse> deletePortfolio(int id) =>
      _delete('/v1/portfolios/$id');

  // ============================================================
  //  REQUESTS (Booking)
  // ============================================================

  /// 30. Create a new service request
  Future<ApiResponse> createRequest(Map<String, dynamic> data) =>
      _post('/v4/requests', data: data);

  /// 31. Get my requests
  Future<ApiResponse> getMyRequests() => _get('/v4/my-requests');

  /// 32. Update request status
  Future<ApiResponse> updateRequestStatus(int id, String status) =>
      _patch('/v4/requests/$id/status', data: {'status': status});

  /// 33. Cancel a request
  Future<ApiResponse> cancelRequest(int id) =>
      _delete('/v4/requests/$id/cancel');

  // ============================================================
  //  BLOG (Posts, Comments, Likes)
  // ============================================================

  /// 34. Get all blog posts
  Future<ApiResponse> getPosts({int page = 1, int? technicianId}) =>
      _get('/v1/posts', query: {
        'page': page,
        if (technicianId != null) 'technician_id': technicianId,
      });

  /// 35. Get post detail by ID
  Future<ApiResponse> getPostDetail(int id) => _get('/v1/posts/$id');

  /// 36. Like/unlike a post
  Future<ApiResponse> likePost(int postId) =>
      _post('/v5/posts/$postId/like');

  /// 37. Add comment to a post
  Future<ApiResponse> commentOnPost(int postId, String comment) =>
      _post('/v5/posts/$postId/comments', data: {'comment': comment});

  /// 38. Delete a comment
  Future<ApiResponse> deleteComment(int id) => _delete('/v5/comments/$id');

  // ============================================================
  //  BLOG POSTS WITH IMAGE UPLOAD (CRUD for technicians)
  // ============================================================

  /// 39. Create a new blog post
  Future<ApiResponse> createPost({
    required String title,
    required String content,
    File? imageFile,
  }) async {
    if (imageFile != null && await imageFile.exists()) {
      final formData = FormData.fromMap({
        'title': title,
        'content': content,
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      });
      return _post('/v5/posts', data: formData);
    }
    return _post('/v5/posts', data: {
      'title': title,
      'content': content,
    });
  }

  /// 40. Update a blog post
  Future<ApiResponse> updatePost(
      int id, {
        String? title,
        String? content,
        File? imageFile,
      }) async {
    if (imageFile != null && await imageFile.exists()) {
      final formData = FormData.fromMap({
        '_method': 'PUT',
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      });
      return _post('/v5/posts/$id', data: formData);
    }
    return _post('/v5/posts/$id', data: {
      '_method': 'PUT',
      if (title != null) 'title': title,
      if (content != null) 'content': content,
    });
  }

  /// 41. Delete a blog post
  Future<ApiResponse> deletePost(int id) => _delete('/v5/posts/$id');

  // ============================================================
  //  STATIC PAGES
  // ============================================================

  /// 42. Get About Us page content
  Future<ApiResponse> getAbout() => _get('/v1/about');

  /// 43. Get FAQs
  Future<ApiResponse> getFaqs() => _get('/v1/faqs');

  /// 44. Get Terms & Conditions
  Future<ApiResponse> getTerms() => _get('/v1/terms');

  // ============================================================
  //  CONTACT
  // ============================================================

  /// 45. Send contact message
  Future<ApiResponse> sendContactMessage(Map<String, dynamic> data) =>
      _post('/v1/contact', data: data);

  // ============================================================
  //  CHAT ENDPOINTS (V14)
  // ============================================================

  /// 46. Get or create a conversation between customer and fundi
  Future<ApiResponse> getOrCreateConversation({
    required int customerId,
    required int fundiId,
  }) => _post('/v14/chat/conversation', data: {
    'customer_id': customerId,
    'fundi_id': fundiId,
  });

  /// 47. Get all conversations for the current user
  Future<ApiResponse> getConversations() => _get('/v14/chat/conversations');

  /// 48. Get messages for a specific conversation
  Future<ApiResponse> getMessages({
    required int conversationId,
    int limit = 50,
    int offset = 0,
  }) => _get('/v14/chat/conversations/$conversationId/messages', query: {
    'limit': limit,
    'offset': offset,
  });

  /// 49. Send a message (text, image, file, voice)
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
          'file': await MultipartFile.fromFile(
            file.path,
            filename: path.basename(file.path),
          ),
        });
        return _post('/v14/chat/send', data: formData);
      }
    }
    return _post('/v14/chat/send', data: {
      'conversation_id': conversationId,
      'content': content ?? '',
      'message_type': messageType,
      if (voiceDuration != null) 'voice_duration': voiceDuration,
    });
  }

  /// 50. Mark a message as read
  Future<ApiResponse> markMessageAsRead(int messageId) =>
      _put('/v14/chat/messages/$messageId/read');

  /// 51. Mark all messages in a conversation as read
  Future<ApiResponse> markConversationAsRead(int conversationId) =>
      _post('/v14/chat/conversations/$conversationId/read');

  /// 52. Delete a message
  Future<ApiResponse> deleteMessage(int messageId) =>
      _delete('/v14/chat/messages/$messageId');

  /// 53. Add reaction to a message
  Future<ApiResponse> addReaction(int messageId, String reaction) =>
      _post('/v14/chat/messages/$messageId/reaction', data: {
        'reaction': reaction,
      });

  /// 54. Remove reaction from a message
  Future<ApiResponse> removeReaction(int messageId) =>
      _delete('/v14/chat/messages/$messageId/reaction');

  /// 55. Get total unread count
  Future<ApiResponse> getUnreadCount() => _get('/v14/chat/unread');

  /// 56. Upload a file for chat (returns URL)
  Future<ApiResponse> uploadChatFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: path.basename(file.path),
      ),
    });
    return _post('/v14/chat/upload', data: formData);
  }

  /// 57. Send typing status
  Future<ApiResponse> sendTypingStatus({
    required int conversationId,
    required bool isTyping,
  }) => _post('/v14/chat/typing', data: {
    'conversation_id': conversationId,
    'is_typing': isTyping,
  });

  /// 58. Download chat file (returns file path or bytes)
  Future<ApiResponse> downloadChatFile(int messageId) =>
      _get('/v14/chat/files/$messageId/download', query: {
        'download': 'true',
      });

  /// 59. Get file info (name, size, mime type)
  Future<ApiResponse> getFileInfo(int messageId) =>
      _get('/v14/chat/files/$messageId/info');

  /// 60. Delete a chat file
  Future<ApiResponse> deleteChatFile(int messageId) =>
      _delete('/v14/chat/files/$messageId');

  /// 61. Delete a conversation
  Future<ApiResponse> deleteConversation(int conversationId) =>
      _delete('/v14/chat/conversations/$conversationId');

  // ============================================================
  //  NOTIFICATION ENDPOINTS (V15)
  // ============================================================

  /// 62. Get all notifications for the current user
  Future<ApiResponse> getNotifications() =>
      _get('/v15/notifications');

  /// 63. Get unread notification count
  Future<ApiResponse> getUnreadNotificationCount() =>
      _get('/v15/notifications/unread-count');

  /// 64. Mark a specific notification as read
  Future<ApiResponse> markNotificationAsRead(String notificationId) =>
      _put('/v15/notifications/$notificationId/read');

  /// 65. Mark all notifications as read
  Future<ApiResponse> markAllNotificationsAsRead() =>
      _put('/v15/notifications/read-all');

  /// 66. Delete a notification
  Future<ApiResponse> deleteNotification(String notificationId) =>
      _delete('/v15/notifications/$notificationId');

  /// 67. Clear all notifications
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
          message: 'Invalid Credentials.',
          sessionExpired: true,
        );
      }
      if (error.response?.statusCode == 422 && error.response?.data is Map) {
        final data = error.response!.data as Map<String, dynamic>;
        String errorMessage = data['message'] ?? 'Validation failed';
        if (data.containsKey('errors') && data['errors'] is Map) {
          final errors = data['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            errorMessage = firstError.first.toString();
          }
        }
        return ApiResponse(
          success: false,
          message: errorMessage,
          errors: data['errors'] as Map<String, dynamic>?,
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