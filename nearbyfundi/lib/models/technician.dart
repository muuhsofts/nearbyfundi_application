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

class PortfolioItem {
  final int id;
  final String image;
  final String? description;
  final String? createdAt;

  PortfolioItem({
    required this.id,
    required this.image,
    this.description,
    this.createdAt,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) => PortfolioItem(
    id: json['id'] ?? 0,
    image: json['image'] ?? '',
    description: json['description'],
    createdAt: json['created_at'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image,
    'description': description,
    'created_at': createdAt,
  };
}

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

    // If there's a 'technician' key, use that
    if (json['technician'] != null && json['technician'] is Map) {
      data = json['technician'] is Map<dynamic, dynamic>
          ? Map<String, dynamic>.from(json['technician'] as Map<dynamic, dynamic>)
          : json['technician'] as Map<String, dynamic>;
    }
    // If there's a 'data' key, use that
    else if (json['data'] != null && json['data'] is Map) {
      data = json['data'] is Map<dynamic, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map<dynamic, dynamic>)
          : json['data'] as Map<String, dynamic>;
    }

    // Extract user data
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

    // Get name from various possible locations
    String name = data['name'] ?? '';
    if (name.isEmpty && user != null) {
      name = user['name'] ?? '';
    }
    if (name.isEmpty && tech != null) {
      name = tech['name'] ?? '';
    }
    if (name.isEmpty) {
      name = 'Unknown';
    }

    // Get email
    String? email = data['email'];
    if (email == null && user != null) {
      email = user['email'];
    }
    if (email == null && tech != null) {
      email = tech['email'];
    }

    // Get phone
    String? phone = data['phone'];
    if (phone == null && user != null) {
      phone = user['phone'];
    }
    if (phone == null && tech != null) {
      phone = tech['phone'];
    }

    // Get user_id
    int userId = data['user_id'] ?? 0;
    if (userId == 0 && user != null) {
      userId = user['id'] ?? 0;
    }
    if (userId == 0 && tech != null) {
      userId = tech['user_id'] ?? 0;
    }

    // Parse services - check multiple locations
    List<String> serviceNames = [];
    List<TechnicianService> serviceObjs = [];

    // Check data['services'] - this is where the backend sends services
    dynamic servicesData = data['services'];

    // If servicesData is null, check other locations
    if (servicesData == null && tech != null) {
      servicesData = tech['services'];
    }
    if (servicesData == null && user != null) {
      servicesData = user['services'];
    }
    // Check if services are in a nested 'service_objects' field
    if (servicesData == null && data['service_objects'] != null) {
      servicesData = data['service_objects'];
    }

    if (servicesData is List) {
      if (servicesData.isNotEmpty) {
        // Check if first item is a Map (object) or String
        if (servicesData.first is Map) {
          // Parse as TechnicianService objects
          final safeList = safeCastList(servicesData);
          serviceObjs = safeList
              .map((e) => TechnicianService.fromJson(e))
              .toList();
          serviceNames = serviceObjs.map((s) => s.name).toList();
        } else if (servicesData.first is String) {
          // Parse as string names
          serviceNames = servicesData.whereType<String>().toList();
          // Create service objects from names (with dummy IDs)
          serviceObjs = serviceNames.asMap().entries.map((entry) {
            return TechnicianService(
              id: entry.key + 1,
              name: entry.value,
            );
          }).toList();
        }
      }
    } else if (servicesData is Map) {
      // If services data is a single object
      try {
        Map<String, dynamic> serviceMap;
        if (servicesData is Map<dynamic, dynamic>) {
          serviceMap = Map<String, dynamic>.from(servicesData);
        } else {
          serviceMap = servicesData as Map<String, dynamic>;
        }
        final serviceObj = TechnicianService.fromJson(serviceMap);
        serviceObjs = [serviceObj];
        serviceNames = [serviceObj.name];
      } catch (e) {
        // Ignore
      }
    }

    // If still no services, try to get from 'services' array in the original json
    if (serviceObjs.isEmpty && json['services'] != null) {
      final origServices = json['services'];
      if (origServices is List && origServices.isNotEmpty) {
        if (origServices.first is Map) {
          final safeList = safeCastList(origServices);
          serviceObjs = safeList
              .map((e) => TechnicianService.fromJson(e))
              .toList();
          serviceNames = serviceObjs.map((s) => s.name).toList();
        }
      }
    }

    // Parse portfolios (only for detail view)
    List<PortfolioItem> portfolios = [];
    if (isDetail) {
      dynamic portfoliosData = data['portfolios'];
      if (portfoliosData == null && tech != null) {
        portfoliosData = tech['portfolios'];
      }
      if (portfoliosData != null && portfoliosData is List) {
        final safeList = safeCastList(portfoliosData);
        portfolios = safeList
            .map((e) => PortfolioItem.fromJson(e))
            .toList();
      }
    }

    // Parse numeric values safely
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

    // Get profile photo
    String? profilePhoto = data['profile_photo'];
    if (profilePhoto == null && tech != null) {
      profilePhoto = tech['profile_photo'];
    }

    // Get bio
    String? bio = data['bio'];
    if (bio == null && tech != null) {
      bio = tech['bio'];
    }

    // Get area
    String? area = data['area'];
    if (area == null && tech != null) {
      area = tech['area'];
    }

    // Get latitude/longitude
    double? latitude = parseNullableDouble(data['latitude']);
    if (latitude == null && tech != null) {
      latitude = parseNullableDouble(tech['latitude']);
    }

    double? longitude = parseNullableDouble(data['longitude']);
    if (longitude == null && tech != null) {
      longitude = parseNullableDouble(tech['longitude']);
    }

    // Get hourly rate
    double? hourlyRate = parseNullableDouble(data['hourly_rate']);
    if (hourlyRate == null && tech != null) {
      hourlyRate = parseNullableDouble(tech['hourly_rate']);
    }

    // Get experience
    int experience = parseInt(data['experience']);
    if (experience == 0 && tech != null) {
      experience = parseInt(tech['experience']);
    }

    // Get rating
    double rating = parseDouble(data['rating']);
    if (rating == 0.0 && tech != null) {
      rating = parseDouble(tech['rating']);
    }

    // Get online status
    bool isOnline = data['is_online'] ?? false;
    if (!isOnline && tech != null) {
      isOnline = tech['is_online'] ?? false;
    }

    // Get verified status
    bool verified = data['verified'] ?? false;
    if (!verified && tech != null) {
      verified = tech['verified'] ?? false;
    }

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