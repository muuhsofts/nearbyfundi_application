// lib/services/badge_service.dart

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Talks to the native MethodChannel ("com.fundiapp/badge") declared in
/// MainActivity.java, which detects the device's launcher (Samsung, Sony,
/// HTC, Huawei, Nova/Apex, etc.) and applies the correct badge protocol
/// for it — so the app-icon badge works on real physical devices instead
/// of only in emulators or on one specific OEM.
class BadgeService {
  static const MethodChannel _channel = MethodChannel('com.fundiapp/badge');

  static Future<void> setBadgeCount(int count) async {
    try {
      if (count > 0) {
        await _channel.invokeMethod('setBadgeCount', {'count': count});
      } else {
        await _channel.invokeMethod('removeBadge');
      }
    } catch (e) {
      // Some launchers genuinely don't support badges at all — that's an
      // OS/OEM limitation, not a bug, so we just log and move on.
      debugPrint('ℹ️ BadgeService: badge not supported on this device: $e');
    }
  }
}