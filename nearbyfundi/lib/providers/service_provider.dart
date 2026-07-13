import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/service.dart';

class ServiceProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<Service> _services = [];
  bool _isLoading = false;
  String? _error;

  List<Service> get services => _services;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchServices() async {
    if (_services.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final res = await _api.getServices();
    if (res.success && res.data != null) {
      _services = (res.data as List).map((e) => Service.fromJson(e)).toList();
    } else {
      _error = res.message;
    }

    _isLoading = false;
    notifyListeners();
  }
}