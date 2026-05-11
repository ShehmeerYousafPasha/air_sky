import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:air_sky/app.dart';
import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/services/firebase_bootstrap.dart';
import 'package:air_sky/services/local_notification_service.dart';
import 'package:air_sky/services/local_storage_service.dart';

/// Application entry point and bootstrap sequence.
///
/// Initialization order:
/// 1. Ensure Flutter bindings are initialized
/// 2. Configure system UI (status bar, overlay style)
/// 3. Initialize Hive for local storage (Boxes for settings, searches, results)
/// 4. Initialize Firebase (Auth, Firestore, Core)
/// 5. Initialize local notifications (Android/iOS/macOS channels)
/// 6. Create ProviderScope and override firebaseBootstrapProvider
/// 7. Run AirSkyApp (which displays SplashScreen first)
///
/// Error handling:
/// - If Firebase fails to initialize, UnavailableAuthRepository is used
/// - Hive failures will crash the app (critical for offline support)
/// - LocalNotificationService failures are non-critical
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI to match app theme
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  final Brightness platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final bool isDarkPlatform = platformBrightness == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    isDarkPlatform
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color(0xFF0F172A),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: true,
          )
        : SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color(0xFF20314A),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: true,
          ),
  );

  // Initialize local storage (Hive)
  await Hive.initFlutter();
  await LocalStorageService.initialize();
  
  // Initialize Firebase
  final FirebaseBootstrapResult bootstrapResult =
      await FirebaseBootstrap.initialize();
  
  // Initialize local notifications
  await LocalNotificationService.instance.initialize();

  // Run app with ProviderScope override for Firebase bootstrap result
  runApp(
    ProviderScope(
      overrides: <Override>[
        firebaseBootstrapProvider.overrideWithValue(bootstrapResult),
      ],
      child: const AirSkyApp(),
    ),
  );
}



