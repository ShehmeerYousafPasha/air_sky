import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:air_sky/app.dart';
import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/services/firebase_bootstrap.dart';
import 'package:air_sky/services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await Hive.initFlutter();
  await LocalStorageService.initialize();
  final FirebaseBootstrapResult bootstrapResult =
      await FirebaseBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: <Override>[
        firebaseBootstrapProvider.overrideWithValue(bootstrapResult),
      ],
      child: const AirSkyApp(),
    ),
  );
}
