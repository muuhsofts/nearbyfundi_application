// models/request.dart
class ServiceRequest {
  final int id;
  final int technicianId;
  final String description;
  final String status;
  final DateTime createdAt;
  final String technicianName;
  final String serviceName;
  final int customerId;
  final String? customerName;
  final String? technicianEmail;
  final String? technicianPhone;
  final String? technicianProfilePhoto;
  final String? technicianArea;
  final double? technicianRating;
  final bool? technicianIsOnline;
  final int? categoryId;
  final String? categoryName;
  final double? latitude;
  final double? longitude;
  final bool hasReview;

  ServiceRequest({
    required this.id,
    required this.technicianId,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.technicianName,
    required this.serviceName,
    this.customerId = 0,
    this.customerName,
    this.technicianEmail,
    this.technicianPhone,
    this.technicianProfilePhoto,
    this.technicianArea,
    this.technicianRating,
    this.technicianIsOnline,
    this.categoryId,
    this.categoryName,
    this.latitude,
    this.longitude,
    this.hasReview = false,
  });

  // ─── STATUS GETTERS ──────────────────────────────────────────────

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isInProgress => status == 'in_progress';
  bool get isOnTheWay => status == 'on_the_way';
  bool get isArrived => status == 'arrived';

  /// True if the request is in a non‑terminal state (from pending to arrived).
  bool get isActive =>
      isPending || isAccepted || isInProgress || isOnTheWay || isArrived;

  // ─── FACTORY ──────────────────────────────────────────────────────

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? technicianData;
    String techName = 'Unknown';
    String? techEmail;
    String? techPhone;
    String? techPhoto;
    String? techArea;
    double? techRating;
    bool? techIsOnline;

    if (json['technician'] != null && json['technician'] is Map) {
      technicianData = Map<String, dynamic>.from(json['technician'] as Map);
    }

    // ─── Extract technician ID from nested object ──────────────────
    int techId = 0;
    if (json['technician_id'] != null) {
      techId = json['technician_id'] as int;
    } else if (technicianData != null && technicianData['id'] != null) {
      techId = technicianData['id'] as int;
    }

    if (technicianData != null) {
      if (technicianData['user'] != null && technicianData['user'] is Map) {
        final userData = technicianData['user'] as Map;
        techName = userData['name']?.toString() ?? techName;
        techEmail = userData['email']?.toString();
        techPhone = userData['phone']?.toString();
        techIsOnline = userData['is_online'] ?? false;
      }
      if (techName == 'Unknown' && technicianData['name'] != null) {
        techName = technicianData['name'].toString();
      }
      techPhoto = technicianData['profile_photo']?.toString();
      techArea = technicianData['area']?.toString();
      if (technicianData['rating'] != null) {
        techRating =
            double.tryParse(technicianData['rating'].toString()) ?? 0.0;
      }
      if (technicianData['is_online'] != null) {
        techIsOnline = technicianData['is_online'] is bool
            ? technicianData['is_online']
            : technicianData['is_online'].toString().toLowerCase() == '1';
      }
    }

    if (techName == 'Unknown' && json['technician_name'] != null) {
      techName = json['technician_name'].toString();
    }

    String serviceName = 'Service';
    if (json['service'] != null && json['service'] is Map) {
      final serviceData = json['service'] as Map;
      serviceName = serviceData['name']?.toString() ?? 'Service';
    }
    if (serviceName == 'Service' && json['service_name'] != null) {
      serviceName = json['service_name'].toString();
    }

    int? categoryId;
    String? categoryName;
    if (json['category'] != null && json['category'] is Map) {
      final categoryData = json['category'] as Map;
      categoryId = categoryData['id'] ?? categoryData['service_categoryID'];
      categoryName = categoryData['name'] ?? categoryData['category_name'];
    }

    int customerId = 0;
    String? customerName;
    if (json['customer'] != null && json['customer'] is Map) {
      final customerData = json['customer'] as Map;
      customerId = int.tryParse(customerData['id']?.toString() ?? '0') ?? 0;
      customerName = customerData['name']?.toString();
    }

    // Extract location fields (if present in the API response)
    double? lat, lng;
    if (json['latitude'] != null) {
      lat = double.tryParse(json['latitude'].toString());
    }
    if (json['longitude'] != null) {
      lng = double.tryParse(json['longitude'].toString());
    }

    // ─── NEW: Parse has_review ──────────────────────────────────────
    bool hasReview = json['has_review'] ?? false;

    return ServiceRequest(
      id: json['id'] ?? 0,
      technicianId: techId,
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      technicianName: techName,
      serviceName: serviceName,
      customerId: customerId,
      customerName: customerName,
      technicianEmail: techEmail,
      technicianPhone: techPhone,
      technicianProfilePhoto: techPhoto,
      technicianArea: techArea,
      technicianRating: techRating,
      technicianIsOnline: techIsOnline,
      categoryId: categoryId,
      categoryName: categoryName,
      latitude: lat,
      longitude: lng,
      hasReview: hasReview,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'technician_id': technicianId,
        'description': description,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'technician_name': technicianName,
        'service_name': serviceName,
        'customer_id': customerId,
        'customer_name': customerName,
        'category_id': categoryId,
        'category_name': categoryName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'has_review': hasReview,
      };
}
