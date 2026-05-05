import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:air_sky/config/app_constants.dart';
import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/app_router.dart';
import 'package:air_sky/config/app_theme.dart';

class AirSkyApp extends ConsumerWidget {
  const AirSkyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyControllerProvider);
    final router = ref.watch(goRouterProvider);
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



