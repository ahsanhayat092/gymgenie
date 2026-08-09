// PLACEHOLDER firebase_options.dart
//
// This file intentionally contains no real Firebase configuration.
// Run `flutterfire configure` in the project root to regenerate it with
// your own Firebase project settings. This file must compile as-is so the
// project builds before configuration.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] placeholder.
///
/// Throws [UnsupportedError] for every platform until the real options are
/// generated via `flutterfire configure`.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again: '
        'flutterfire configure',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'run `flutterfire configure` to generate firebase_options.dart.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'run `flutterfire configure` to generate firebase_options.dart.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'run `flutterfire configure` to generate firebase_options.dart.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3toCq6uhnM1H6ZeblpSzx6Cnd2M0RVz8',
    appId: '1:347100417684:ios:881cf1eaf55967835b6e81',
    messagingSenderId: '347100417684',
    projectId: 'gymgenie-a5380',
    storageBucket: 'gymgenie-a5380.firebasestorage.app',
    androidClientId: '347100417684-cf1fv9pk3murkrr1qc8olvdiejv4fub8.apps.googleusercontent.com',
    iosClientId: '347100417684-bu5npcns3mihat8ddl7f9rd0r0l5gt3n.apps.googleusercontent.com',
    iosBundleId: 'com.example.gymgenie',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpGub2J6QSTv8X3qzFGqoTfGSllvZAJQE',
    appId: '1:347100417684:android:efbd4e2e13b5ce815b6e81',
    messagingSenderId: '347100417684',
    projectId: 'gymgenie-a5380',
    storageBucket: 'gymgenie-a5380.firebasestorage.app',
  );
}
