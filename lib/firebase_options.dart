// File generated manually to mirror FlutterFire output.
// ignore_for_file: constant_identifier_names

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAF3o7Gy_6EWwvwyEtxC-E8_CuLdolvqFk',
    appId: '1:179534139162:web:345a890430ac87002f66a3',
    messagingSenderId: '179534139162',
    projectId: 'idlewatch-f2b23',
    authDomain: 'idlewatch-f2b23.firebaseapp.com',
    storageBucket: 'idlewatch-f2b23.firebasestorage.app',
    measurementId: 'G-DT7WWKTS6K',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCPYZE-ZrOe__HX4mrrtY5oQ7X0uyCswWM',
    appId: '1:179534139162:ios:e8c695fedbe843832f66a3',
    messagingSenderId: '179534139162',
    projectId: 'idlewatch-f2b23',
    storageBucket: 'idlewatch-f2b23.firebasestorage.app',
    iosBundleId: 'com.idlewatch.app',
  );

  // Using iOS values as temporary placeholders until Android/macOS apps are
  // registered in Firebase.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPYZE-ZrOe__HX4mrrtY5oQ7X0uyCswWM',
    appId: '1:179534139162:ios:e8c695fedbe843832f66a3',
    messagingSenderId: '179534139162',
    projectId: 'idlewatch-f2b23',
    storageBucket: 'idlewatch-f2b23.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCPYZE-ZrOe__HX4mrrtY5oQ7X0uyCswWM',
    appId: '1:179534139162:ios:e8c695fedbe843832f66a3',
    messagingSenderId: '179534139162',
    projectId: 'idlewatch-f2b23',
    storageBucket: 'idlewatch-f2b23.firebasestorage.app',
    iosBundleId: 'com.idlewatch.app',
  );
}
