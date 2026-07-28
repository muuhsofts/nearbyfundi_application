class TechnicianService {
  final int id;
  final String name;

  TechnicianService({required this.id, required this.name});

  factory TechnicianService.fromJson(Map<String, dynamic> json) => TechnicianService(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

// ─── UPDATED PORTFOLIO ITEM WITH SOCIAL LINKS ──────────────────────────
class PortfolioItem {
  final int id;
  final String image;
  final String? description;
  final String? createdAt;

  // NEW: social links from the API
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? twitter;
  final String? telegram;

  PortfolioItem({
    required this.id,
    required this.image,
    this.description,
    this.createdAt,
    this.instagram,
    this.facebook,
    this.tiktok,
    this.twitter,
    this.telegram,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    // The social links might be inside a nested 'social_links' object
    // or directly in the portfolio JSON.
    final socialLinks = json['social_links'] as Map<String, dynamic>?;

    return PortfolioItem(
      id: json['id'] ?? 0,
      image: json['image'] ?? '',
      description: json['description'],
      createdAt: json['created_at'],
      instagram: socialLinks?['instagram'] ?? json['instagram'],
      facebook: socialLinks?['facebook'] ?? json['facebook'],
      tiktok: socialLinks?['tiktok'] ?? json['tiktok'],
      twitter: socialLinks?['twitter'] ?? json['twitter'],
      telegram: socialLinks?['telegram'] ?? json['telegram'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image,
    'description': description,
    'created_at': createdAt,
    'instagram': instagram,
    'facebook': facebook,
    'tiktok': tiktok,
    'twitter': twitter,
    'telegram': telegram,
  };

  /// Returns true if at least one social link is not null/empty.
  bool get hasSocialLinks {
    return instagram != null ||
        facebook != null ||
        tiktok != null ||
        twitter != null ||
        telegram != null;
  }
}

// ─── TECHNICIAN MODEL (unchanged except the portfolio parsing) ──────────
class Technician {
  final int id;
  final int userId;
  final String name;
  final String? email;
  final String? phone;
  final String? profilePhoto;
  final String? bio;
  final int experience;
  final double rating;
  final double? hourlyRate;
  final double distanceKm;
  final String? area;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final bool verified;
  final List<String> services;
  final List<TechnicianService> serviceObjects;
  final List<PortfolioItem> portfolios;

  Technician({
    required this.id,
    this.userId = 0,
    required this.name,
    this.email,
    this.phone,
    this.profilePhoto,
    this.bio,
    this.experience = 0,
    this.rating = 0.0,
    this.hourlyRate,
    this.distanceKm = 0.0,
    this.area,
    this.latitude,
    this.longitude,
    this.isOnline = false,
    this.verified = false,
    this.services = const [],
    this.serviceObjects = const [],
    this.portfolios = const [],
  });

  factory Technician.fromJson(Map<String, dynamic> json, {bool isDetail = false}) {
    // Helper to safely cast Map to Map<String, dynamic>
    Map<String, dynamic> safeCast(Map<dynamic, dynamic> map) {
      return Map<String, dynamic>.from(map);
    }

    // Helper to safely cast List to List<Map<String, dynamic>>
    List<Map<String, dynamic>> safeCastList(List<dynamic> list) {
      return list.map((item) {
        if (item is Map<dynamic, dynamic>) {
          return Map<String, dynamic>.from(item);
        } else if (item is Map<String, dynamic>) {
          return item;
        } else {
          return <String, dynamic>{};
        }
      }).where((item) => item.isNotEmpty).toList();
    }

    // Extract data from different possible response structures
    Map<String, dynamic> data = json;

    if (json['technician'] != null && json['technician'] is Map) {
      data = json['technician'] is Map<dynamic, dynamic>
          ? Map<String, dynamic>.from(json['technician'] as Map<dynamic, dynamic>)
          : json['technician'] as Map<String, dynamic>;
    } else if (json['data'] != null && json['data'] is Map) {
      data = json['data'] is Map<dynamic, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map<dynamic, dynamic>)
          : json['data'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? user;
    if (data['user'] != null && data['user'] is Map) {
      user = data['user'] is Map<dynamic, dynamic>
          ? Map<String, dynamic>.from(data['user'] as Map<dynamic, dynamic>)
          : data['user'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? tech;
    if (data['technician'] != null && data['technician'] is Map) {
      tech = data['technician'] is Map<dynamic, dynamic>
          ? Map<String, dynamic>.from(data['technician'] as Map<dynamic, dynamic>)
          : data['technician'] as Map<String, dynamic>;
    }

    // ---- Get name, email, phone, user_id ----
    String name = data['name'] ?? '';
    if (name.isEmpty && user != null) name = user['name'] ?? '';
    if (name.isEmpty && tech != null) name = tech['name'] ?? '';
    if (name.isEmpty) name = 'Unknown';

    String? email = data['email'] ?? user?['email'] ?? tech?['email'];
    String? phone = data['phone'] ?? user?['phone'] ?? tech?['phone'];

    int userId = data['user_id'] ?? 0;
    if (userId == 0 && user != null) userId = user['id'] ?? 0;
    if (userId == 0 && tech != null) userId = tech['user_id'] ?? 0;

    // ---- Parse services ----
    List<String> serviceNames = [];
    List<TechnicianService> serviceObjs = [];

    dynamic servicesData = data['services'] ?? tech?['services'] ?? user?['services'] ?? data['service_objects'];

    if (servicesData is List) {
      if (servicesData.isNotEmpty) {
        if (servicesData.first is Map) {
          final safeList = safeCastList(servicesData);
          serviceObjs = safeList.map((e) => TechnicianService.fromJson(e)).toList();
          serviceNames = serviceObjs.map((s) => s.name).toList();
        } else if (servicesData.first is String) {
          serviceNames = servicesData.whereType<String>().toList();
          serviceObjs = serviceNames.asMap().entries.map((entry) {
            return TechnicianService(id: entry.key + 1, name: entry.value);
          }).toList();
        }
      }
    } else if (servicesData is Map) {
      try {
        final serviceMap = servicesData is Map<dynamic, dynamic>
            ? Map<String, dynamic>.from(servicesData)
            : servicesData as Map<String, dynamic>;
        final serviceObj = TechnicianService.fromJson(serviceMap);
        serviceObjs = [serviceObj];
        serviceNames = [serviceObj.name];
      } catch (_) {}
    }

    if (serviceObjs.isEmpty && json['services'] != null) {
      final origServices = json['services'];
      if (origServices is List && origServices.isNotEmpty && origServices.first is Map) {
        final safeList = safeCastList(origServices);
        serviceObjs = safeList.map((e) => TechnicianService.fromJson(e)).toList();
        serviceNames = serviceObjs.map((s) => s.name).toList();
      }
    }

    // ---- Parse portfolios (only for detail view) ----
    List<PortfolioItem> portfolios = [];
    if (isDetail) {
      dynamic portfoliosData = data['portfolios'] ?? tech?['portfolios'];
      if (portfoliosData != null && portfoliosData is List) {
        final safeList = safeCastList(portfoliosData);
        // ✅ Use the updated PortfolioItem.fromJson that parses social links
        portfolios = safeList.map((e) => PortfolioItem.fromJson(e)).toList();
      }
    }

    // ---- Parse numeric fields ----
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    String? profilePhoto = data['profile_photo'] ?? tech?['profile_photo'];
    String? bio = data['bio'] ?? tech?['bio'];
    String? area = data['area'] ?? tech?['area'];
    double? latitude = parseNullableDouble(data['latitude'] ?? tech?['latitude']);
    double? longitude = parseNullableDouble(data['longitude'] ?? tech?['longitude']);
    double? hourlyRate = parseNullableDouble(data['hourly_rate'] ?? tech?['hourly_rate']);
    int experience = parseInt(data['experience'] ?? tech?['experience']);
    double rating = parseDouble(data['rating'] ?? tech?['rating']);
    bool isOnline = data['is_online'] ?? tech?['is_online'] ?? false;
    bool verified = data['verified'] ?? tech?['verified'] ?? false;

    return Technician(
      id: data['id'] ?? tech?['id'] ?? json['id'] ?? 0,
      userId: userId,
      name: name,
      email: email,
      phone: phone,
      profilePhoto: profilePhoto,
      bio: bio,
      experience: experience,
      rating: rating,
      hourlyRate: hourlyRate,
      distanceKm: parseDouble(data['distance'] ?? data['distance_km'] ?? 0.0),
      area: area,
      latitude: latitude,
      longitude: longitude,
      isOnline: isOnline,
      verified: verified,
      services: serviceNames,
      serviceObjects: serviceObjs,
      portfolios: portfolios,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'email': email,
    'phone': phone,
    'profile_photo': profilePhoto,
    'bio': bio,
    'experience': experience,
    'rating': rating,
    'hourly_rate': hourlyRate,
    'distance_km': distanceKm,
    'area': area,
    'latitude': latitude,
    'longitude': longitude,
    'is_online': isOnline,
    'verified': verified,
    'services': services,
    'service_objects': serviceObjects.map((s) => s.toJson()).toList(),
    'portfolios': portfolios.map((p) => p.toJson()).toList(),
  };
}