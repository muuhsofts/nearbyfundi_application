// lib/firebase_options.dart
// Generated manually from your google-services.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // If you also need web, add web configuration below
      throw UnsupportedError('Web not configured yet');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android configuration (from your google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAI8DIC73GaDmuLhyMa-V9LKUV9JowpTXc',
    appId: '1:217153819583:android:76772644eb984f5311c70a',
    messagingSenderId: '217153819583',
    projectId: 'nearbyfundi-8032f',
    storageBucket: 'nearbyfundi-8032f.firebasestorage.app',
  );

  // iOS configuration – you need to add an iOS app in Firebase Console
  // and download GoogleService-Info.plist to get these values.
  // For now, placeholder – replace with your actual iOS credentials.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'nearbyfundi-8032f',
    storageBucket: 'nearbyfundi-8032f.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.nearbyfundi',
  );

  // macOS configuration – similar to iOS, if needed.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'nearbyfundi-8032f',
    storageBucket: 'nearbyfundi-8032f.firebasestorage.app',
  );
}