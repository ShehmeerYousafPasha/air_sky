import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/config/app_constants.dart';
import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/route_paths.dart';
import 'package:air_sky/config/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _flowTimer;
  late final AnimationController _logoDullController;

  String _resolveLoadingStage(double progress) {
    if (progress < 0.34) {
      return 'Checking itinerary cache';
    }
    if (progress < 0.67) {
      return 'Syncing fare radar';
    }
    return 'Preparing runway';
  }

  @override
  void initState() {
    super.initState();
    _logoDullController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _startFlow();
  }

  void _startFlow() {
    _flowTimer?.cancel();
    _flowTimer = Timer(const Duration(milliseconds: 2400), () async {
      final bool onboardingDone = ref.read(onboardingCompletedProvider);
      if (!onboardingDone) {
        if (mounted) {
          context.go(RoutePaths.onboarding);
        }
        return;
      }

      final bool isGuest = ref.read(guestModeProvider);
      final user = await ref.read(authStateChangesProvider.future);

      if (!mounted) {
        return;
      }

      if (user != null || isGuest) {
        context.go(RoutePaths.home);
        return;
      }

      context.go(RoutePaths.login);
    });
  }

  @override
  void dispose() {
    _flowTimer?.cancel();
    _logoDullController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.skyGradient(isDark)),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -80.h,
                left: -46.w,
                child: Container(
                  width: 210.w,
                  height: 210.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4DA6FF).withValues(alpha: 0.22),
                  ),
                ),
              ),
              Positioned(
                top: 78.h,
                right: -52.w,
                child: Container(
                  width: 170.w,
                  height: 170.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned(
                bottom: -94.h,
                right: -38.w,
                child: Container(
                  width: 260.w,
                  height: 260.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.17),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _logoDullController,
                    builder: (BuildContext context, _) {
                      return CustomPaint(
                        painter: _SkyGridPainter(
                          progress: _logoDullController.value,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _logoDullController,
                    builder: (BuildContext context, _) {
                      return _BackgroundPlaneMark(
                        progress: _logoDullController.value,
                      );
                    },
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22.w),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 500.w),
                    child: AnimatedBuilder(
                      animation: _logoDullController,
                      builder: (BuildContext context, _) {
                        final double progress =
                            (_logoDullController.value * 0.96) + 0.04;
                        final int progressPercent = (progress * 100)
                            .clamp(0, 100)
                            .round();
                        final String stage = _resolveLoadingStage(progress);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _SplashBrandLockup(
                              theme: theme,
                              isDark: isDark,
                              progress: progress,
                            ),
                            SizedBox(height: 26.h),
                            _SplashStatusCard(
                              theme: theme,
                              isDark: isDark,
                              stage: stage,
                              progress: progress,
                              progressPercent: progressPercent,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Text(
                    'Setting up your AirSky cockpit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.72)
                          : const Color(0xFF3B658D),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ).animate(delay: 260.ms).fadeIn(duration: 420.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBrandLockup extends StatelessWidget {
  const _SplashBrandLockup({
    required this.theme,
    required this.isDark,
    required this.progress,
  });

  final ThemeData theme;
  final bool isDark;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double eased = Curves.easeOut.transform(progress.clamp(0, 1));
    final double takeoffPhase = ((eased - 0.68) / 0.32).clamp(0, 1);
    final double innerPlaneLift = -9.h * Curves.easeOut.transform(takeoffPhase);
    final double innerPlaneAngle = -0.22 - (0.36 * takeoffPhase);
    final double travel = 62.w * eased;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
              width: 186.w,
              height: 162.h,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Transform.rotate(
                    angle: 0.18,
                    child: Container(
                      width: 150.w,
                      height: 150.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(42.r),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFF8DBCF0).withValues(alpha: 0.72),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -0.10,
                    child: Container(
                      width: 118.w,
                      height: 118.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32.r),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? <Color>[
                                  const Color(0xFF24486E),
                                  const Color(0xFF132D4B),
                                ]
                              : <Color>[
                                  const Color(0xFFEAF4FF),
                                  const Color(0xFFD6E9FF),
                                ],
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : const Color(0xFF8EBDF2),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color:
                                (isDark
                                        ? const Color(0xFF081423)
                                        : const Color(0xFF4A8FDF))
                                    .withValues(alpha: 0.32),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned(
                            top: 18.h,
                            left: 18.w,
                            child: Text(
                              'AIR',
                              style: theme.textTheme.labelLarge?.copyWith(
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : const Color(0xFF1A4C83),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 37.h,
                            left: 18.w,
                            child: Text(
                              'SKY',
                              style: theme.textTheme.titleMedium?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0E3F76),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 15.w,
                            right: 15.w,
                            bottom: 20.h,
                            child: Container(
                              height: 5.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999.r),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.24)
                                    : const Color(0xFFACCEF3),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 17.w,
                            right: 17.w,
                            bottom: 22.h,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List<Widget>.generate(5, (int index) {
                                return Container(
                                  width: 8.w,
                                  height: 1.6.h,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.62)
                                        : const Color(
                                            0xFF3F7CB9,
                                          ).withValues(alpha: 0.62),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Positioned(
                            left: 15.w + travel,
                            bottom: 25.h + innerPlaneLift,
                            child: Transform.rotate(
                              angle: innerPlaneAngle,
                              child: Icon(
                                Icons.flight_takeoff_rounded,
                                size: 37.sp,
                                color: isDark
                                    ? const Color(0xFFE9F5FF)
                                    : const Color(0xFF0E56AC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 430.ms)
            .scale(begin: const Offset(0.86, 0.86), curve: Curves.easeOutBack),
        SizedBox(height: 20.h),
        Text(
          AppConstants.appName.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 3.4,
            color: isDark ? Colors.white : const Color(0xFF123F73),
          ),
        ).animate(delay: 90.ms).fadeIn(duration: 360.ms).slideY(begin: 0.15),
        SizedBox(height: 6.h),
        Text(
          'Travel intelligence, ready for takeoff',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? Colors.white.withValues(alpha: 0.78)
                : const Color(0xFF446B92),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ).animate(delay: 160.ms).fadeIn(duration: 360.ms),
      ],
    );
  }
}

class _SplashStatusCard extends StatelessWidget {
  const _SplashStatusCard({
    required this.theme,
    required this.isDark,
    required this.stage,
    required this.progress,
    required this.progressPercent,
  });

  final ThemeData theme;
  final bool isDark;
  final String stage;
  final double progress;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  const Color(0xFF0E233D).withValues(alpha: 0.72),
                  const Color(0xFF163252).withValues(alpha: 0.68),
                ]
              : <Color>[
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFF2F8FF).withValues(alpha: 0.91),
                ],
        ),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFD6E8FC),
        ),
        boxShadow: AppTheme.softShadows(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  stage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _TakeoffProgressLine(
            progress: progress,
            isDark: isDark,
            theme: theme,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.12);
  }
}

class _TakeoffProgressLine extends StatelessWidget {
  const _TakeoffProgressLine({
    required this.progress,
    required this.isDark,
    required this.theme,
  });

  final double progress;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final double rawProgress = progress.clamp(0, 1);
    final double clamped = Curves.easeOutCubic.transform(rawProgress);
    final double takeoffPhase = ((clamped - 0.62) / 0.38).clamp(0, 1);
    final double lift = -14.h * Curves.easeOut.transform(takeoffPhase);
    final double cruiseBob =
        math.sin(clamped * 10) * 0.7.h * (1 - takeoffPhase);
    final double planeAngle = -0.08 - (0.52 * takeoffPhase);

    return SizedBox(
      height: 36.h,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double chipSize = 28.w;
          final double iconSize = 16.w;
          final double maxLeft = (constraints.maxWidth - chipSize).clamp(
            0,
            constraints.maxWidth,
          );
          final double planeLeft = maxLeft * clamped;
          final double planeCenterX = planeLeft + (chipSize / 2);
          final double fillWidth = constraints.maxWidth * clamped;
          final double trailWidth = planeCenterX.clamp(0, constraints.maxWidth);

          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 16.h,
                child: Container(
                  height: 7.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999.r),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFCCE0F7),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 16.h,
                child: Container(
                  width: fillWidth,
                  height: 7.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999.r),
                    gradient: LinearGradient(
                      colors: <Color>[
                        theme.colorScheme.primary,
                        isDark
                            ? const Color(0xFF7DD6FF)
                            : const Color(0xFF52A3FF),
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 0.4,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 18.h,
                child: Container(
                  width: trailWidth,
                  height: 3.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999.r),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        theme.colorScheme.primary.withValues(alpha: 0),
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                        theme.colorScheme.primary.withValues(alpha: 0.36),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: planeLeft,
                top: 4.h + cruiseBob + lift,
                child: Transform.rotate(
                  angle: planeAngle,
                  alignment: Alignment.center,
                  child: Container(
                    width: chipSize,
                    height: chipSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isDark
                            ? <Color>[
                                const Color(0xFF21446D),
                                const Color(0xFF122A46),
                              ]
                            : <Color>[
                                const Color(0xFFE7F3FF),
                                const Color(0xFFD4E9FF),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.28)
                            : const Color(0xFF8CBDF2),
                        width: 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color:
                              (isDark
                                      ? const Color(0xFF061120)
                                      : const Color(0xFF317DD8))
                                  .withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.flight_takeoff_rounded,
                      size: iconSize,
                      color: isDark
                          ? const Color(0xFFEAF5FF)
                          : const Color(0xFF0B56AC),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SkyGridPainter extends CustomPainter {
  const _SkyGridPainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double clamped = progress.clamp(0, 1);

    final Paint linePaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF124885)).withValues(
        alpha: 0.045 - (0.015 * clamped),
      )
      ..strokeWidth = 1;

    const double gap = 48;
    for (double x = -size.height * 0.22; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + (size.height * 0.22), size.height),
        linePaint,
      );
    }

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = (isDark ? Colors.white : const Color(0xFF0F4D91)).withValues(
        alpha: 0.12 - (0.04 * clamped),
      );

    final Rect ellipse = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.62),
      width: size.width * 1.28,
      height: size.height * 0.84,
    );
    canvas.drawArc(ellipse, 3.7 + (0.15 * clamped), 1.4, false, arcPaint);
    canvas.drawArc(ellipse, 0.32 - (0.18 * clamped), 1.0, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SkyGridPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _BackgroundPlaneMark extends StatelessWidget {
  const _BackgroundPlaneMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double clamped = progress.clamp(0, 1);
    final double dullPhase = clamped <= 0.7 ? clamped / 0.7 : 1;

    final Color planeColor =
        Color.lerp(
          theme.colorScheme.primary,
          theme.colorScheme.onSurface.withValues(alpha: 0.72),
          dullPhase * 0.82,
        ) ??
        theme.colorScheme.primary;

    final double opacity = (0.32 - (0.12 * dullPhase)).clamp(0, 1);
    final double size = 330.w - (42.w * dullPhase);
    final double translateY = 8.h + (22.h * clamped);

    return Center(
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.rotate(
          angle: -0.54 + (0.10 * dullPhase),
          child: Opacity(
            opacity: opacity,
            child: Icon(
              Icons.airplanemode_active_rounded,
              size: size,
              color: planeColor,
            ),
          ),
        ),
      ),
    );
  }
}



