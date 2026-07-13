// lib/models/technician.dart
import 'package:fundiapp/models/portfolio.dart';

class Technician {
  final int id;
  final String name;
  final String? phone;
  final String? profilePhoto;
  final String? nida;
  final String? bio;
  final int experience;
  final double rating;
  final double? hourlyRate;
  final String? area;
  final bool isOnline;
  final List<String> services;
  final List<TechnicianService> serviceObjects;
  final List<PortfolioItem> portfolios;

  Technician({
    required this.id,
    required this.name,
    this.phone,
    this.profilePhoto,
    this.nida,
    this.bio,
    this.experience = 0,
    this.rating = 0.0,
    this.hourlyRate,
    this.area,
    this.isOnline = false,
    this.services = const [],
    this.serviceObjects = const [],
    this.portfolios = const [],
  });

  factory Technician.fromJson(Map<String, dynamic> json, {bool isDetail = false}) {
    String name = json['name'] ?? '';
    if (name.isEmpty && json['user'] != null && json['user']['name'] != null) {
      name = json['user']['name'];
    }

    String? phone = json['phone'];
    if (phone == null && json['user'] != null && json['user']['phone'] != null) {
      phone = json['user']['phone'];
    }

    String? profilePhoto = json['profile_photo'];
    if (profilePhoto == null && json['user'] != null && json['user']['profile_photo'] != null) {
      profilePhoto = json['user']['profile_photo'];
    }

    String? nida = json['nida'];

    int parseExperience(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    List<String> serviceNames = [];
    List<TechnicianService> serviceObjs = [];

    if (json['services'] != null && json['services'] is List) {
      final raw = json['services'] as List;
      for (var item in raw) {
        if (item is Map<String, dynamic>) {
          final s = TechnicianService.fromJson(item);
          serviceObjs.add(s);
          serviceNames.add(s.name);
        } else if (item is String) {
          serviceNames.add(item);
        }
      }
    }

    if (json['service_objects'] != null && json['service_objects'] is List) {
      serviceObjs = (json['service_objects'] as List)
          .map((e) => TechnicianService.fromJson(e as Map<String, dynamic>))
          .toList();
      serviceNames = serviceObjs.map((s) => s.name).toList();
    }

    bool parseOnline(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return false;
    }

    return Technician(
      id: json['id'] ?? 0,
      name: name,
      phone: phone,
      profilePhoto: profilePhoto,
      nida: nida,
      bio: json['bio'],
      experience: parseExperience(json['experience']),
      rating: parseDouble(json['rating']),
      hourlyRate: json['hourly_rate'] != null ? parseDouble(json['hourly_rate']) : null,
      area: json['area'],
      isOnline: parseOnline(json['is_online']),
      services: serviceNames,
      serviceObjects: serviceObjs,
      portfolios: isDetail && json['portfolios'] != null
          ? (json['portfolios'] as List)
          .where((e) => e != null)
          .map((p) => PortfolioItem.fromJson(p))
          .toList()
          : [],
    );
  }
}

class TechnicianService {
  final int id;
  final String name;
  TechnicianService({required this.id, required this.name});
  factory TechnicianService.fromJson(Map<String, dynamic> json) => TechnicianService(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
  );
}