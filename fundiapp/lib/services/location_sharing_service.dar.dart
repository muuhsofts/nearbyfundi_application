// lib/services/location_sharing_service.dart

import 'technician_heartbeat_service.dart';

/// Facade for live location sharing while a Fundi is on the way / in progress.
/// All heavy lifting is done by [TechnicianHeartbeatService].
class LocationSharingService {
  LocationSharingService._(); // prevent instantiation

  static final TechnicianHeartbeatService _heartbeat =
  TechnicianHeartbeatService();

  /// Call when technician starts going to the customer
  /// (status = on_the_way / in_progress)
  static void startSharing() {
    if (_heartbeat.isRunning) return;
    _heartbeat.start();
  }

  /// Call when the job is completed, cancelled or rejected
  static void stopSharing() {
    if (!_heartbeat.isRunning) return;
    _heartbeat.stop();
  }

  /// Whether location/heartbeat is currently active
  static bool get isSharing => _heartbeat.isRunning;
}