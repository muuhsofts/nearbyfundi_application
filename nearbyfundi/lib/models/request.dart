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
  });

  // Helper getters for status
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isInProgress => status == 'in_progress';
  bool get isActive => isPending || isAccepted || isInProgress;

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    // Extract technician data - could be nested or direct
    Map<String, dynamic>? technicianData;
    String techName = 'Unknown';
    String? techEmail;
    String? techPhone;
    String? techPhoto;
    String? techArea;
    double? techRating;
    bool? techIsOnline;

    // Try to get technician data from different possible locations
    if (json['technician'] != null) {
      technicianData = json['technician'] is Map
          ? Map<String, dynamic>.from(json['technician'] as Map)
          : null;
    }

    if (technicianData != null) {
      // Try to get technician name from various locations
      // Case 1: technician['user']['name']
      if (technicianData['user'] != null && technicianData['user'] is Map) {
        final userData = technicianData['user'] as Map;
        techName = userData['name']?.toString() ?? techName;
        techEmail = userData['email']?.toString();
        techPhone = userData['phone']?.toString();
        techIsOnline = userData['is_online'] ?? false;
      }

      // Case 2: technician['name'] (direct)
      if (techName == 'Unknown' && technicianData['name'] != null) {
        techName = technicianData['name'].toString();
      }

      // Case 3: technician['user']['name'] with different casing
      if (techName == 'Unknown' && technicianData['user'] != null) {
        final userData = technicianData['user'] as Map;
        if (userData['name'] != null) {
          techName = userData['name'].toString();
        }
      }

      // Get other technician fields
      techPhoto = technicianData['profile_photo']?.toString();
      techArea = technicianData['area']?.toString();

      // Get rating
      if (technicianData['rating'] != null) {
        techRating = double.tryParse(technicianData['rating'].toString()) ?? 0.0;
      }

      // Get online status
      if (technicianData['is_online'] != null) {
        techIsOnline = technicianData['is_online'] is bool
            ? technicianData['is_online']
            : technicianData['is_online'].toString().toLowerCase() == '1';
      }
    }

    // If still no name, try to get from 'technician_name' field
    if (techName == 'Unknown' && json['technician_name'] != null) {
      techName = json['technician_name'].toString();
    }

    // Extract service name
    String serviceName = 'Service';
    if (json['service'] != null && json['service'] is Map) {
      final serviceData = json['service'] as Map;
      serviceName = serviceData['name']?.toString() ?? 'Service';
    }
    if (serviceName == 'Service' && json['service_name'] != null) {
      serviceName = json['service_name'].toString();
    }

    // Extract customer data
    int customerId = 0;
    String? customerName;
    if (json['customer'] != null && json['customer'] is Map) {
      final customerData = json['customer'] as Map;
      customerId = int.tryParse(customerData['id']?.toString() ?? '0') ?? 0;
      customerName = customerData['name']?.toString();
    }

    return ServiceRequest(
      id: json['id'] ?? 0,
      technicianId: json['technician_id'] ?? 0,
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
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
  };
}