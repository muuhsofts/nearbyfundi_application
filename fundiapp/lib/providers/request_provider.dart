// lib/providers/request_provider.dart

import 'package:flutter/material.dart';
import '../models/request.dart';
import '../services/api_service.dart';

class RequestProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // State
  List<ServiceRequest> _requests = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  double _submissionProgress = 0.0;

  // Getters
  List<ServiceRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  double get submissionProgress => _submissionProgress;

  // Status-specific getters
  List<ServiceRequest> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();

  List<ServiceRequest> get acceptedRequests =>
      _requests.where((r) => r.isAccepted).toList();

  List<ServiceRequest> get completedRequests =>
      _requests.where((r) => r.isCompleted).toList();

  List<ServiceRequest> get activeRequests =>
      _requests.where((r) => r.isActive).toList();

  // Counts
  int get pendingCount => pendingRequests.length;
  int get acceptedCount => acceptedRequests.length;
  int get completedCount => completedRequests.length;
  int get activeCount => activeRequests.length;
  int get totalCount => _requests.length;

  // Check if there's an active request with a specific technician
  bool hasActiveRequest(int technicianId) {
    return _requests.any((r) =>
    r.technicianId == technicianId && r.isActive);
  }

  // Load all requests
  Future<void> loadMyRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.getMyRequests();

      if (res.success && res.data != null) {
        final data = res.data;
        List<dynamic> requestsData;

        // Handle different response formats
        if (data is List) {
          requestsData = data;
        } else if (data is Map && data.containsKey('data')) {
          if (data['data'] is List) {
            requestsData = data['data'];
          } else if (data['data'] is Map && data['data'].containsKey('data')) {
            requestsData = data['data']['data'] as List? ?? [];
          } else {
            requestsData = [];
          }
        } else {
          requestsData = [];
        }

        _requests = requestsData
            .map((e) => ServiceRequest.fromJson(e))
            .toList();
      } else {
        _error = res.message ?? 'Failed to load requests';
        _requests = [];
      }
    } catch (e) {
      _error = 'Failed to load requests: $e';
      _requests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create a new request
  Future<bool> createRequest({
    required int technicianId,
    required int serviceId,
    required String description,
  }) async {
    if (_isSubmitting) return false;

    _submissionProgress = 0.0;
    _isSubmitting = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    void updateProgress(double value) {
      _submissionProgress = value;
      notifyListeners();
    }

    try {
      updateProgress(0.1);

      final res = await _api.createRequest({
        'technician_id': technicianId,
        'service_id': serviceId,
        'description': description,
      });

      updateProgress(0.6);
      _isLoading = false;
      _isSubmitting = false;

      if (res.success) {
        _submissionProgress = 1.0;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 300));
        await loadMyRequests();
        return true;
      } else {
        _error = res.message ?? 'Failed to create request';
        _submissionProgress = 0.0;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to create request: $e';
      _isLoading = false;
      _isSubmitting = false;
      _submissionProgress = 0.0;
      notifyListeners();
      return false;
    }
  }

  // Update request status
  Future<bool> updateStatus(int id, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.updateRequestStatus(id, status);

      if (res.success) {
        await loadMyRequests();
        return true;
      } else {
        _error = res.message ?? 'Failed to update status';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to update status: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cancel a request
  Future<bool> cancelRequest(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.cancelRequest(id);

      if (res.success) {
        await loadMyRequests();
        return true;
      } else {
        _error = res.message ?? 'Failed to cancel request';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to cancel request: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Accept request (convenience)
  Future<bool> acceptRequest(int id) async {
    return await updateStatus(id, 'accepted');
  }

  // Reject request (convenience)
  Future<bool> rejectRequest(int id) async {
    return await updateStatus(id, 'rejected');
  }

  // Mark as completed (convenience)
  Future<bool> completeRequest(int id) async {
    return await updateStatus(id, 'completed');
  }

  // Mark as in progress (convenience)
  Future<bool> markInProgress(int id) async {
    return await updateStatus(id, 'in_progress');
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset progress
  void resetProgress() {
    _submissionProgress = 0.0;
    notifyListeners();
  }

  // Refresh (alias)
  Future<void> refresh() async {
    await loadMyRequests();
  }
}