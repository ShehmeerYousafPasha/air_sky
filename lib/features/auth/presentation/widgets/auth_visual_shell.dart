import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:air_sky/core/theme/app_theme.dart';

class AuthVisualShell extends StatelessWidget {
  const AuthVisualShell({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.leadingIcon,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData leadingIcon;
  final Widget child;

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
                left: -54.w,
                child: Container(
                  width: 220.w,
                  height: 220.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4DA6FF).withValues(alpha: 0.2),
                  ),
                ),
              ),
              Positioned(
                bottom: -92.h,
                right: -42.w,
                child: Container(
                  width: 250.w,
                  height: 250.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned(
                top: 34.h,
                right: 26.w,
                child: Transform.rotate(
                  angle: -0.34,
                  child: Icon(
                    Icons.airplanemode_active_rounded,
                    size: 56.sp,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFF2E73C5).withValues(alpha: 0.18),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 14.h,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 460.w),
                    child:
                        Container(
                              padding: EdgeInsets.fromLTRB(
                                20.w,
                                20.h,
                                20.w,
                                18.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? <Color>[
                                          const Color(
                                            0xFF0D223A,
                                          ).withValues(alpha: 0.76),
                                          const Color(
                                            0xFF122D4B,
                                          ).withValues(alpha: 0.7),
                                        ]
                                      : <Color>[
                                          Colors.white.withValues(alpha: 0.95),
                                          const Color(
                                            0xFFF2F8FF,
                                          ).withValues(alpha: 0.9),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(28.r),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : const Color(0xFFD6E8FC),
                                ),
                                boxShadow: AppTheme.softShadows(context),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 6.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            999.r,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              Icons.verified_rounded,
                                              size: 14.sp,
                                              color: theme.colorScheme.primary,
                                            ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              badgeLabel,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        width: 44.w,
                                        height: 44.w,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            13.r,
                                          ),
                                        ),
                                        child: Icon(
                                          leadingIcon,
                                          color: theme.colorScheme.primary,
                                          size: 24.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14.h),
                                  Text(
                                    title,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.1,
                                        ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    subtitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 18.h),
                                  child,
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
