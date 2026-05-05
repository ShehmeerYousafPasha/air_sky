import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        if (Platform.isAndroid) {
          return android;
        }
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5VVKVlcwhG2BuUz5S-QA4RkCXXIlO7so',
    appId: '1:968530155421:web:f4b1ccc985348943e70174',
    messagingSenderId: '968530155421',
    projectId: 'airsky-book-fly-785767',
    authDomain: 'airsky-book-fly-785767.firebaseapp.com',
    storageBucket: 'airsky-book-fly-785767.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjTPnulDyiVnvzepO0F_yUfbZ_0Uqi0qs',
    appId: '1:968530155421:android:50b1daee100dc0e6e70174',
    messagingSenderId: '968530155421',
    projectId: 'airsky-book-fly-785767',
    storageBucket: 'airsky-book-fly-785767.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.airSky',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.airSky',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC5VVKVlcwhG2BuUz5S-QA4RkCXXIlO7so',
    appId: '1:968530155421:web:1826e9d05bb57560e70174',
    messagingSenderId: '968530155421',
    projectId: 'airsky-book-fly-785767',
    authDomain: 'airsky-book-fly-785767.firebaseapp.com',
    storageBucket: 'airsky-book-fly-785767.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}



