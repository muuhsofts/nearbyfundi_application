import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/request.dart';

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

  int get pendingCount => _requests.where((r) => r.isPending).length;
  int get acceptedCount => _requests.where((r) => r.isAccepted).length;
  int get completedCount => _requests.where((r) => r.isCompleted).length;
  int get rejectedCount => _requests.where((r) => r.isRejected).length;
  int get cancelledCount => _requests.where((r) => r.isCancelled).length;
  int get activeCount => _requests.where((r) => r.isActive).length;

  bool hasActiveRequest(int technicianId) {
    return _requests.any((r) =>
    r.technicianId == technicianId && r.isActive);
  }

  Future<void> loadMyRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final res = await _api.getMyRequests();
    if (res.success && res.data != null) {
      final rawData = res.data;
      List dataList;

      if (rawData is List) {
        dataList = rawData;
      } else if (rawData is Map) {
        dataList = (rawData['data'] ??
            rawData['requests'] ??
            rawData['results'] ??
            []) as List;
      } else {
        dataList = [];
      }

      _requests = dataList
          .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _error = res.message ?? 'Failed to load requests';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new service request – must be called with named parameters.
  Future<bool> createRequest({
    required int technicianId,
    required int serviceId,
    required String description,
    int? categoryId,
    double? latitude,
    double? longitude,
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

    updateProgress(0.1);

    // Now passing named arguments – matches ApiService.createRequest exactly
    final res = await _api.createRequest(
      technicianId: technicianId,
      serviceId: serviceId,
      description: description,
      categoryId: categoryId,
      latitude: latitude,
      longitude: longitude,
    );

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
      debugPrint('Create request error: ${res.message}');
      return false;
    }
  }

  Future<bool> cancelRequest(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final res = await _api.cancelRequest(id);
    if (res.success) {
      await loadMyRequests();
      return true;
    }

    _error = res.message;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateRequestStatus(int id, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final res = await _api.updateRequestStatus(id, status);
    if (res.success) {
      await loadMyRequests();
      return true;
    }

    _error = res.message;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  void resetProgress() {
    _submissionProgress = 0.0;
    notifyListeners();
  }
}