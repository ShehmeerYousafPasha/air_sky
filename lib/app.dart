import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:air_sky/config/app_constants.dart';
import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/app_router.dart';
import 'package:air_sky/config/app_theme.dart';

/// Root widget for the AirSky application.
///
/// Sets up:
/// - ScreenUtil for responsive design (base design: 390x844)
/// - Material Design theme (light and dark modes)
/// - GoRouter for navigation with auth guards
/// - Theme mode and currency preference watchers
/// - Status bar styling that adapts to theme
class AirSkyApp extends ConsumerWidget {
  const AirSkyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch currency preference for dynamic formatting
    ref.watch(currencyControllerProvider);
    
    // Get router instance with redirect logic
    final router = ref.watch(goRouterProvider);
    
    // Watch theme mode changes
    final themeMode = ref.watch(themeModeControllerProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          builder: (BuildContext context, Widget? routedChild) {
            // Ensure status bar icon colors match active theme
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final SystemUiOverlayStyle overlayStyle = isDark
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                    systemStatusBarContrastEnforced: true,
                  )
                : SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: const Color(0xFF20314A),
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                    systemStatusBarContrastEnforced: true,
                  );

            // Some Android devices ignore AnnotatedRegion updates intermittently;
            // this ensures status bar icon contrast always tracks the active theme.
            SystemChrome.setSystemUIOverlayStyle(overlayStyle);

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: routedChild ?? const SizedBox.shrink(),
            );
          },
          routerConfig: router,
        );
      },
    );
  }
}



