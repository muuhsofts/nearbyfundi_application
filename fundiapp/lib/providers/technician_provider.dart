import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/technician.dart';

class TechnicianProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  Technician? _technician;
  bool _isLoading = false;
  String? _error;

  Technician? get technician => _technician;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TechnicianProvider() {
    _initConnectivityListener();
  }

  // ---- Connectivity auto-online/offline ----
  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((event) {
      final hasConnection = _hasConnection(event);
      _updateOnlineStatus(hasConnection);
    });
    Connectivity().checkConnectivity().then((result) {
      final hasConnection = _hasConnection(result);
      _updateOnlineStatus(hasConnection);
    });
  }

  bool _hasConnection(dynamic connectivityResult) {
    if (connectivityResult is List<ConnectivityResult>) {
      return connectivityResult.any((r) => r != ConnectivityResult.none);
    } else if (connectivityResult is ConnectivityResult) {
      return connectivityResult != ConnectivityResult.none;
    }
    return false;
  }

  Future<void> _updateOnlineStatus(bool hasConnection) async {
    if (_technician == null) return;
    final currentOnline = _technician!.isOnline;
    final targetOnline = hasConnection;
    if (currentOnline != targetOnline) {
      await _toggleOnline(targetOnline);
    }
  }

  Future<void> _toggleOnline(bool online) async {
    _setLoading(true);
    final res = await _api.toggleOnlineStatus(online);
    if (res.success) {
      await fetchMyProfile();
    } else {
      _error = res.message;
    }
    _setLoading(false);
  }

  // ---- Profile Photo Upload ----
  Future<bool> uploadProfilePhoto(File imageFile) async {
    _setLoading(true);
    final res = await _api.uploadProfilePhoto(imageFile);
    if (res.success) {
      await fetchMyProfile();
      _setLoading(false);
      return true;
    }
    _error = res.message;
    _setLoading(false);
    return false;
  }

  // ---- Profile Fetch & Update ----
  Future<void> fetchMyProfile() async {
    _setLoading(true);
    final res = await _api.getMyTechnicianProfile();
    if (res.success && res.data != null) {
      _technician = Technician.fromJson(res.data, isDetail: true);
    } else {
      _error = res.message;
    }
    _setLoading(false);
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    final res = await _api.updateTechnicianProfile(data);
    if (res.success) {
      await fetchMyProfile();
      _setLoading(false);
      return true;
    }
    _error = res.message;
    _setLoading(false);
    return false;
  }

  Future<bool> updateServices(List<int> serviceIds) async {
    _setLoading(true);
    final res = await _api.updateTechnicianServices(serviceIds);
    if (res.success) {
      await fetchMyProfile();
      _setLoading(false);
      return true;
    }
    _error = res.message;
    _setLoading(false);
    return false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
    notifyListeners();
  }
}