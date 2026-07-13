import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  String? _error;
  bool _notificationsEnabled = true;
  String _locale = 'en';

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get notificationsEnabled => _notificationsEnabled;
  String get locale => _locale;

  // ✅ Add this getter
  Locale get currentLocale => Locale(_locale);

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() async {
    _locale = (await StorageService.getLocale()) ?? 'en';
    _notificationsEnabled = (await StorageService.getNotificationsEnabled()) ?? true;
    notifyListeners();
  }

  Future<bool> updateLocale(String newLocale) async {
    _setLoading(true);
    final res = await _api.updateLocale(newLocale);
    if (res.success) {
      _locale = newLocale;
      await StorageService.saveLocale(newLocale);
      _setLoading(false);
      notifyListeners(); // 👈 triggers rebuild
      return true;
    }
    _error = res.message;
    _setLoading(false);
    return false;
  }

  Future<bool> updateNotificationStatus(bool enabled) async {
    _notificationsEnabled = enabled;
    await StorageService.saveNotificationsEnabled(enabled);
    notifyListeners();
    return true;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
    notifyListeners();
  }
}