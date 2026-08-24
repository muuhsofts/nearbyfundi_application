// lib/providers/request_provider.dart

import 'package:flutter/material.dart';
import '../models/request.dart';
import '../services/api_service.dart';
import '../services/location_sharing_service.dar.dart';


class RequestProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<ServiceRequest> _requests = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  double _submissionProgress = 0.0;

  List<ServiceRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  double get submissionProgress => _submissionProgress;

  List<ServiceRequest> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();
  List<ServiceRequest> get acceptedRequests =>
      _requests.where((r) => r.isAccepted).toList();
  List<ServiceRequest> get completedRequests =>
      _requests.where((r) => r.isCompleted).toList();
  List<ServiceRequest> get activeRequests =>
      _requests.where((r) => r.isActive).toList();

  int get pendingCount => pendingRequests.length;
  int get acceptedCount => acceptedRequests.length;
  int get completedCount => completedRequests.length;
  int get activeCount => activeRequests.length;
  int get totalCount => _requests.length;

  bool hasActiveRequest(int technicianId) {
    return _requests.any((r) => r.technicianId == technicianId && r.isActive);
  }

  Future<void> loadMyRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.getMyRequests();
      if (res.success && res.data != null) {
        final data = res.data;
        List<dynamic> requestsData;

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

        _requests = requestsData.map((e) => ServiceRequest.fromJson(e)).toList();
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

    try {
      _submissionProgress = 0.1;
      notifyListeners();

      final res = await _api.createRequest({
        'technician_id': technicianId,
        'service_id': serviceId,
        'description': description,
      });

      _submissionProgress = 0.6;
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

  Future<bool> updateStatus(int id, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.updateRequestStatus(id, status);
      if (res.success) {
        // Auto manage location sharing
        if (status == 'on_the_way' || status == 'in_progress') {
          LocationSharingService.startSharing();
        } else if (status == 'completed' ||
            status == 'cancelled' ||
            status == 'rejected') {
          LocationSharingService.stopSharing();
        }

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

  Future<bool> cancelRequest(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.cancelRequest(id);
      if (res.success) {
        LocationSharingService.stopSharing();
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

  // ─── Convenience methods ──────────────────────────────────

  Future<bool> acceptRequest(int id) => updateStatus(id, 'accepted');

  Future<bool> rejectRequest(int id) => updateStatus(id, 'rejected');

  Future<bool> completeRequest(int id) async {
    final success = await updateStatus(id, 'completed');
    if (success) LocationSharingService.stopSharing();
    return success;
  }

  Future<bool> markInProgress(int id) => updateStatus(id, 'in_progress');

  /// Mark as On The Way + start sharing location
  Future<bool> markOnTheWay(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.markOnTheWay(id);
      if (res.success) {
        LocationSharingService.startSharing(); // start GPS
        await loadMyRequests();
        return true;
      } else {
        _error = res.message ?? 'Failed to mark on the way';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to mark on the way: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mark Arrived
  Future<bool> markArrived(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.markArrived(id);
      if (res.success) {
        await loadMyRequests();
        return true;
      } else {
        _error = res.message ?? 'Failed to mark arrived';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to mark arrived: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetProgress() {
    _submissionProgress = 0.0;
    notifyListeners();
  }

  Future<void> refresh() async => await loadMyRequests();
}