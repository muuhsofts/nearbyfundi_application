// lib/services/location_sharing_service.dart

import 'technician_heartbeat_service.dart';

class LocationSharingService {
  static final TechnicianHeartbeatService _heartbeat =
  TechnicianHeartbeatService();

  /// Call when technician starts going to customer
  static void startSharing() {
    _heartbeat.start();
  }

  /// Call when job is completed / cancelled
  static void stopSharing() {
    _heartbeat.stop();
  }

  static bool get isSharing => _heartbeat.isRunning;
}