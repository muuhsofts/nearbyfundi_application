// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAI8DIC73GaDmuLhyMa-V9LKUV9JowpTXc',
    appId: '1:217153819583:android:76772644eb984f5311c70a',
    messagingSenderId: '217153819583',
    projectId: 'nearbyfundi-8032f',
    storageBucket: 'nearbyfundi-8032f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAI8DIC73GaDmuLhyMa-V9LKUV9JowpTXc',
    appId: '1:217153819583:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '217153819583',
    projectId: 'nearbyfundi-8032f',
    storageBucket: 'nearbyfundi-8032f.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.nearbyfundi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAI8DIC73GaDmuLhyMa-V9LKUV9JowpTXc',
    appId: '1:217153819583:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: '217153819583',
    projectId: 'nearbyfundi-8032f',
    storageBucket: 'nearbyfundi-8032f.firebasestorage.app',
  );
}