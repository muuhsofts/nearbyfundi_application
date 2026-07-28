import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/technician.dart';

class TechnicianProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Technician> _technicians = [];
  Technician? _currentTechnician;
  Technician? _myTechnician;
  bool _isLoading = false;
  String? _error;

  // The geocoded origin point of the last place search
  double? _searchLat;
  double? _searchLng;
  String? _searchPlace;

  // ─── Last search parameters (for refresh) ──────────────────────────
  String? _lastPlace;
  int? _lastServiceId;
  int _lastRadius = 20;

  List<Technician> get technicians => _technicians;
  Technician? get currentTechnician => _currentTechnician;
  Technician? get technician => _myTechnician;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double? get searchLat => _searchLat;
  double? get searchLng => _searchLng;
  String? get searchPlace => _searchPlace;
  bool get hasSearchOrigin => _searchLat != null && _searchLng != null;

  // ─── Refresh last search ────────────────────────────────────────────
  Future<void> refreshLastSearch() async {
    if (_lastPlace != null && _lastPlace!.isNotEmpty) {
      await searchByPlace(
        place: _lastPlace!,
        serviceId: _lastServiceId,
        radius: _lastRadius,
      );
    }
  }

  // ─── Search by place name ──────────────────────────────────────────
  Future<void> searchByPlace({
    required String place,
    int? serviceId,
    int radius = 20,
  }) async {
    // Store last search parameters
    _lastPlace = place;
    _lastServiceId = serviceId;
    _lastRadius = radius;

    _setLoading(true);
    try {
      final res = await _api.searchTechniciansByPlace(
        place: place,
        serviceId: serviceId,
        radius: radius,
      );
      _handlePlaceSearchResponse(res);
    } catch (e) {
      _error = e.toString();
      _technicians = [];
      _searchLat = null;
      _searchLng = null;
      _searchPlace = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Search by coordinates ──────────────────────────────────────────
  Future<void> fetchNearby({
    required double lat,
    required double lng,
    int? serviceId,
    int radius = 20,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.getNearbyTechnicians(
        lat: lat,
        lng: lng,
        radius: radius,
        serviceId: serviceId,
      );
      _handleListResponse(res);
    } catch (e) {
      _error = e.toString();
      _technicians = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Get technician detail (without portfolios) ────────────────────
  Future<void> fetchTechnicianDetail(int id) async {
    _isLoading = true;
    _error = null;
    _currentTechnician = null;
    notifyListeners();

    try {
      final res = await _api.getTechnicianDetail(id);
      if (res.success && res.data != null) {
        _currentTechnician = Technician.fromJson(res.data, isDetail: true);
        _error = null;
      } else {
        _error = res.message;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Fetch technician WITH portfolios ──────────────────────────────
  Future<void> fetchTechnicianWithPortfolios(int id) async {
    _isLoading = true;
    _error = null;
    _currentTechnician = null;
    notifyListeners();

    try {
      final detailRes = await _api.getTechnicianDetail(id);
      if (!detailRes.success || detailRes.data == null) {
        _error = detailRes.message;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final tech = Technician.fromJson(detailRes.data, isDetail: false);

      final portfolioRes = await _api.getTechnicianPortfolio(id);
      List<PortfolioItem> portfolioItems = [];

      if (portfolioRes.success && portfolioRes.data != null) {
        final data = portfolioRes.data as Map<String, dynamic>;
        final portfoliosData = data['portfolios'] as List? ?? [];
        portfolioItems = portfoliosData.map((p) => PortfolioItem.fromJson(p)).toList();
      }

      _currentTechnician = Technician(
        id: tech.id,
        userId: tech.userId,
        name: tech.name,
        email: tech.email,
        phone: tech.phone,
        profilePhoto: tech.profilePhoto,
        bio: tech.bio,
        experience: tech.experience,
        rating: tech.rating,
        hourlyRate: tech.hourlyRate,
        distanceKm: tech.distanceKm,
        area: tech.area,
        latitude: tech.latitude,
        longitude: tech.longitude,
        isOnline: tech.isOnline,
        verified: tech.verified,
        services: tech.services,
        serviceObjects: tech.serviceObjects,
        portfolios: portfolioItems,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Get own technician profile ─────────────────────────────────────
  Future<void> fetchMyProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.getTechnicianProfile();
      if (res.success && res.data != null) {
        _myTechnician = Technician.fromJson(res.data, isDetail: true);
        _error = null;
      } else {
        _error = res.message;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Update services ─────────────────────────────────────────────────
  Future<void> updateServices(List<int> serviceIds) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.updateTechnicianServices(serviceIds);
      if (res.success && res.data != null) {
        _myTechnician = Technician.fromJson(res.data, isDetail: true);
        _error = null;
      } else {
        _error = res.message;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Toggle online status ───────────────────────────────────────────
  Future<void> toggleOnline(bool isOnline) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.toggleTechnicianOnline(isOnline);
      if (res.success && res.data != null) {
        _myTechnician = Technician.fromJson(res.data, isDetail: true);
        _error = null;
      } else {
        _error = res.message;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Update location ─────────────────────────────────────────────────
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.updateTechnicianLocation(latitude, longitude);
      if (res.success) {
        if (_myTechnician != null) {
          _myTechnician = Technician(
            id: _myTechnician!.id,
            userId: _myTechnician!.userId,
            name: _myTechnician!.name,
            email: _myTechnician!.email,
            phone: _myTechnician!.phone,
            profilePhoto: _myTechnician!.profilePhoto,
            bio: _myTechnician!.bio,
            experience: _myTechnician!.experience,
            rating: _myTechnician!.rating,
            hourlyRate: _myTechnician!.hourlyRate,
            distanceKm: _myTechnician!.distanceKm,
            area: _myTechnician!.area,
            latitude: latitude,
            longitude: longitude,
            isOnline: _myTechnician!.isOnline,
            verified: _myTechnician!.verified,
            services: _myTechnician!.services,
            serviceObjects: _myTechnician!.serviceObjects,
            portfolios: _myTechnician!.portfolios,
          );
        }
        _error = null;
      } else {
        _error = res.message;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Clear methods ──────────────────────────────────────────────────
  void clearTechnicians() {
    _technicians = [];
    _searchLat = null;
    _searchLng = null;
    _searchPlace = null;
    _error = null;
    notifyListeners();
  }

  void clearDetail() {
    _currentTechnician = null;
    _error = null;
    notifyListeners();
  }

  // ─── Private helpers ─────────────────────────────────────────────────
  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
    notifyListeners();
  }

  // ─── Response handlers ──────────────────────────────────────────────

  void _handleListResponse(ApiResponse res) {
    if (res.success && res.data != null) {
      List dataList;

      if (res.data is Map) {
        if (res.data['technicians'] != null) {
          dataList = res.data['technicians'] as List;
        } else if (res.data['data'] != null) {
          dataList = res.data['data'] as List;
        } else {
          dataList = [];
        }
      } else if (res.data is List) {
        dataList = res.data as List;
      } else {
        dataList = [];
      }

      _technicians = dataList
          .where((e) => e != null)
          .map((e) => Technician.fromJson(e, isDetail: false))
          .toList();
      _error = null;
    } else {
      _error = res.message;
      _technicians = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  void _handlePlaceSearchResponse(ApiResponse res) {
    if (res.success && res.data != null) {
      final data = res.data;

      List rawList = [];
      Map<String, dynamic>? searchMeta;

      if (data is Map) {
        if (data['technicians'] != null) {
          rawList = data['technicians'] as List;
        } else if (data['data'] != null) {
          rawList = data['data'] as List;
        }
        if (data['search'] != null && data['search'] is Map) {
          searchMeta = Map<String, dynamic>.from(data['search'] as Map);
        }
      } else if (data is List) {
        rawList = data;
      }

      _technicians = rawList
          .where((e) => e != null)
          .map((e) => Technician.fromJson(e, isDetail: false))
          .toList();

      if (searchMeta != null) {
        final lat = searchMeta['latitude'];
        final lng = searchMeta['longitude'];
        _searchLat = lat is num ? lat.toDouble() : double.tryParse('$lat');
        _searchLng = lng is num ? lng.toDouble() : double.tryParse('$lng');
        _searchPlace = searchMeta['place'] as String?;
      } else {
        _searchLat = null;
        _searchLng = null;
        _searchPlace = null;
      }

      _error = null;
    } else {
      _error = res.message;
      _technicians = [];
      _searchLat = null;
      _searchLng = null;
      _searchPlace = null;
    }
    _isLoading = false;
    notifyListeners();
  }
}