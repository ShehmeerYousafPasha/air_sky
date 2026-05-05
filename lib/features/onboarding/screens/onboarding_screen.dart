import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/route_paths.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingItem> _items = <_OnboardingItem>[
    _OnboardingItem(
      title: 'Discover Flights',
      subtitle:
          'Explore route combinations and nearby airport options in seconds.',
      badge: 'Smart Route Finder',
      routeHint: 'LHE -> DXB  |  from \$187',
      highlights: <String>['Nearby airport suggestions', 'Flexible date view'],
      icon: Icons.travel_explore_rounded,
      color: Color(0xFF0F6FD9),
      image:
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=1200',
    ),
    _OnboardingItem(
      title: 'Compare Prices',
      subtitle:
          'Blend cheapest and fastest picks with practical stop-time filters.',
      badge: 'Price Intelligence',
      routeHint: 'KHI -> IST  |  best combo 6h 45m',
      highlights: <String>['Fare trend insights', 'Clear filter controls'],
      icon: Icons.query_stats_rounded,
      color: Color(0xFF0EA47A),
      image:
          'https://images.unsplash.com/photo-1502920917128-1aa500764b86?w=1200',
    ),
    _OnboardingItem(
      title: 'Book Easily',
      subtitle:
          'Finish booking quickly with prefilled details, seat maps, and QR tickets.',
      badge: 'Fast Checkout',
      routeHint: 'ISB -> DOH  |  seat + ticket in minutes',
      highlights: <String>['Auto-filled passenger form', 'Tickets in My Trips'],
      icon: Icons.airplane_ticket_rounded,
      color: Color(0xFFF49B24),
      image:
          'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=1200',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();

    if (!mounted) {
      return;
    }

    final user = ref.read(authStateChangesProvider).valueOrNull;
    final bool isGuest = ref.read(guestModeProvider);

    context.go((user != null || isGuest) ? RoutePaths.home : RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _currentPage == _items.length - 1;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const <Color>[
                    Color(0xFF0F172A),
                    Color(0xFF13253D),
                    Color(0xFF1C3558),
                  ]
                : const <Color>[
                    Color(0xFFDDEEFF),
                    Color(0xFFEFF7FF),
                    Color(0xFFF8FCFF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -78.h,
                left: -46.w,
                child: Container(
                  width: 210.w,
                  height: 210.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF62B7FF).withValues(alpha: 0.20),
                  ),
                ),
              ),
              Positioned(
                bottom: -92.h,
                right: -42.w,
                child: Container(
                  width: 260.w,
                  height: 260.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 7.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.flight_takeoff_rounded,
                                size: 15.sp,
                                color: theme.colorScheme.primary,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'Welcome to AirSky',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _items.length,
                        onPageChanged: (int value) {
                          setState(() {
                            _currentPage = value;
                          });
                        },
                        itemBuilder: (BuildContext context, int index) {
                          final _OnboardingItem item = _items[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF0E223A,
                                    ).withValues(alpha: 0.62)
                                  : Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(26.r),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : theme.colorScheme.outlineVariant,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.26 : 0.08,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(13.w),
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(19.r),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: <Widget>[
                                          Image.network(
                                            item.image,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  BuildContext context,
                                                  Object error,
                                                  StackTrace? _,
                                                ) => Container(
                                                  color: item.color.withValues(
                                                    alpha: 0.14,
                                                  ),
                                                  child: Icon(
                                                    item.icon,
                                                    color: item.color,
                                                    size: 88.sp,
                                                  ),
                                                ),
                                            loadingBuilder:
                                                (
                                                  BuildContext context,
                                                  Widget child,
                                                  ImageChunkEvent? progress,
                                                ) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return Shimmer.fromColors(
                                                    baseColor: theme
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    highlightColor: theme
                                                        .colorScheme
                                                        .surface,
                                                    child: Container(
                                                      color: theme
                                                          .colorScheme
                                                          .surfaceContainer,
                                                    ),
                                                  );
                                                },
                                          ),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: <Color>[
                                                  Colors.black.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  Colors.black.withValues(
                                                    alpha: 0.62,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12.h,
                                            left: 12.w,
                                            child: _OnboardingFeatureChip(
                                              label: item.badge,
                                              icon: Icons.auto_awesome_rounded,
                                            ),
                                          ),
                                          Positioned(
                                            top: 12.h,
                                            right: 12.w,
                                            child: Container(
                                              width: 44.w,
                                              height: 44.w,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.22,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                item.icon,
                                                color: Colors.white,
                                                size: 23.sp,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 12.w,
                                            right: 12.w,
                                            bottom: 12.h,
                                            child: Container(
                                              padding: EdgeInsets.fromLTRB(
                                                12.w,
                                                11.h,
                                                12.w,
                                                11.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.18,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14.r),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.28),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    item.routeHint,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  Text(
                                                    item.title,
                                                    style: theme
                                                        .textTheme
                                                        .titleLarge
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    item.subtitle,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.95,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          height: 1.3,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ).animate().fadeIn(duration: 320.ms).scale(),
                                  ),
                                  SizedBox(height: 12.h),
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: item.highlights
                                        .map(
                                          (String value) =>
                                              _OnboardingFeatureChip(
                                                label: value,
                                              ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ).animate(delay: 70.ms).fadeIn(duration: 350.ms);
                        },
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_items.length, (
                        int index,
                      ) {
                        final bool isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          width: isActive ? 25.w : 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 14.h),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (isLast) {
                            await _finish();
                            return;
                          }
                          await _pageController.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                        },
                        icon: Icon(
                          isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(isLast ? 'Start Exploring' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingFeatureChip extends StatelessWidget {
  const _OnboardingFeatureChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFE9F3FF),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.20)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14.sp, color: theme.colorScheme.primary),
            SizedBox(width: 5.w),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.routeHint,
    required this.highlights,
    required this.icon,
    required this.color,
    required this.image,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String routeHint;
  final List<String> highlights;
  final IconData icon;
  final Color color;
  final String image;
}



