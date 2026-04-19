import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/theme/app_theme.dart';
import 'package:air_sky/core/utils/account_required_prompt.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/features/ai_assistant/presentation/widgets/ai_assistant_entry_point.dart';
import 'package:air_sky/features/flights/domain/entities/flight_search_query.dart';
import 'package:air_sky/features/home/presentation/widgets/fare_trend_chart.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _dealsController = PageController(
    viewportFraction: 0.88,
  );
  late final AnimationController _titlePlaneController;
  int _currentDeal = 0;

  @override
  void initState() {
    super.initState();
    _titlePlaneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _titlePlaneController.dispose();
    _dealsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    final List<FlightSearchQuery> recent = ref.watch(recentSearchesProvider);
    final bool isGuest = ref.watch(guestModeProvider);
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final String? firestoreName = ref
        .watch(userProfileNameProvider)
        .valueOrNull;
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final String greet = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final String travelerName = _resolveTravelerName(
      isGuest: isGuest,
      firestoreName: firestoreName,
      authDisplayName: user?.displayName,
      email: user?.email,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 22.w,
              height: 22.w,
              child: AnimatedBuilder(
                animation: _titlePlaneController,
                builder: (BuildContext context, _) {
                  final double progress = _titlePlaneController.value;
                  final double dullPhase = progress <= 0.7 ? progress / 0.7 : 1;
                  final Color planeColor =
                      Color.lerp(
                        theme.colorScheme.primary,
                        theme.colorScheme.onSurface.withValues(alpha: 0.78),
                        dullPhase * 0.75,
                      ) ??
                      theme.colorScheme.primary;
                  final double opacity = (0.98 - (0.32 * dullPhase)).clamp(
                    0,
                    1,
                  );
                  final double size = 28.sp - (2.0.sp * dullPhase);
                  final double translateY = 0.4.h + (1.8.h * progress);

                  return Transform.translate(
                    offset: Offset(0, translateY),
                    child: Transform.rotate(
                      angle: -0.54 + (0.1 * dullPhase),
                      child: Opacity(
                        opacity: opacity,
                        child: Icon(
                          Icons.airplanemode_active_rounded,
                          size: size,
                          color: planeColor,
                          shadows: <Shadow>[
                            Shadow(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'AirSky',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            iconSize: 24.sp,
            tooltip: 'Find Flights',
            onPressed: () => context.push(RoutePaths.search),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            iconSize: 24.sp,
            tooltip: 'Live Flights Map',
            onPressed: () => context.push(RoutePaths.liveMap),
            icon: const Icon(Icons.radar_rounded),
          ),
          IconButton(
            iconSize: 24.sp,
            tooltip: 'My Trips',
            onPressed: () => context.push(RoutePaths.myTrips),
            icon: const Icon(Icons.airplane_ticket_rounded),
          ),
          IconButton(
            iconSize: 24.sp,
            tooltip: 'Profile',
            onPressed: () => context.push(RoutePaths.profile),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          RefreshIndicator(
            onRefresh: () =>
                ref.read(recentSearchesProvider.notifier).refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
              children: <Widget>[
                _HeroBanner(
                  greeting: greet,
                  travelerName: travelerName,
                  dateLabel: now.toTicketDate(),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
                if (isGuest) ...<Widget>[
                  SizedBox(height: 12.h),
                  _GuestUpgradeCard(
                    onTap: () => goToLoginFromGuestSession(context, ref),
                  ),
                ],
                SizedBox(height: 14.h),
                _FindFlightsPromptCard(
                  onTap: () => context.push(RoutePaths.search),
                ),
                SizedBox(height: 12.h),
                const FareTrendChart(),
                SizedBox(height: 14.h),
                _SectionTitle(
                  title: 'Recent searches',
                  action: recent.isEmpty
                      ? null
                      : TextButton.icon(
                          onPressed: () async {
                            await ref
                                .read(recentSearchesProvider.notifier)
                                .clear();
                          },
                          icon: Icon(Icons.close_rounded, size: 16.sp),
                          label: const Text('Clear'),
                        ),
                ),
                SizedBox(height: 8.h),
                if (recent.isEmpty)
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      'No recent searches yet. Your latest routes will appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: recent
                        .map(
                          (search) => ActionChip(
                            label: Text(
                              '${search.fromAirport} -> ${search.toAirport} (${search.date.toTicketDate()})',
                            ),
                            onPressed: () {
                              final formController = ref.read(
                                searchFormControllerProvider.notifier,
                              );
                              formController.setFromAirport(search.fromAirport);
                              formController.setToAirport(search.toAirport);
                              formController.setDate(search.date);
                              formController.setCabinClass(search.cabinClass);
                              formController.setPassengers(search.passengers);
                              context.push(RoutePaths.search);
                            },
                          ),
                        )
                        .toList(),
                  ),
                SizedBox(height: 16.h),
                const _SectionTitle(title: 'Popular destinations'),
                SizedBox(height: 8.h),
                GridView.builder(
                  itemCount: _popularDestinations.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, Object> destination =
                        _popularDestinations[index];
                    return _DestinationCard(
                          destination: destination,
                          onTap: () {
                            ref
                                .read(searchFormControllerProvider.notifier)
                                .setToAirport(
                                  destination['code'] as String? ?? 'DXB',
                                );
                            context.push(RoutePaths.search);
                          },
                        )
                        .animate(delay: (70 * index).ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.08);
                  },
                ),
                SizedBox(height: 16.h),
                const _SectionTitle(title: 'Top deals'),
                SizedBox(height: 10.h),
                SizedBox(
                  height: 178.h,
                  child: PageView.builder(
                    controller: _dealsController,
                    itemCount: _dealCards.length,
                    onPageChanged: (int value) {
                      setState(() {
                        _currentDeal = value;
                      });
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, Object> deal = _dealCards[index];
                      return _DealCard(
                        deal: deal,
                        onTap: () {
                          ref
                              .read(searchFormControllerProvider.notifier)
                              .setToAirport(deal['code'] as String? ?? 'DXB');
                          context.push(RoutePaths.search);
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(_dealCards.length, (
                    int index,
                  ) {
                    final bool active = index == _currentDeal;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: active ? 20.w : 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const AiAssistantEntryPoint(),
        ],
      ),
    );
  }

  static final List<Map<String, Object>>
  _popularDestinations = <Map<String, Object>>[
    <String, Object>{
      'city': 'Dubai',
      'country': 'United Arab Emirates',
      'code': 'DXB',
      'priceUsd': 210,
      'image':
          'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=600',
    },
    <String, Object>{
      'city': 'Doha',
      'country': 'Qatar',
      'code': 'DOH',
      'priceUsd': 180,
      'image':
          'https://images.unsplash.com/photo-1580674285054-bed31e145f59?w=600',
    },
    <String, Object>{
      'city': 'Istanbul',
      'country': 'Turkey',
      'code': 'IST',
      'priceUsd': 295,
      'image':
          'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=600',
    },
    <String, Object>{
      'city': 'Singapore',
      'country': 'Singapore',
      'code': 'SIN',
      'priceUsd': 340,
      'image':
          'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=600',
    },
  ];

  static final List<Map<String, Object>> _dealCards = <Map<String, Object>>[
    <String, Object>{
      'title': 'Weekend steal',
      'route': 'KHI -> DXB',
      'code': 'DXB',
      'priceUsd': 189,
      'image':
          'https://images.unsplash.com/photo-1505761671935-60b3a7427bad?w=1200',
    },
    <String, Object>{
      'title': 'Spring promo',
      'route': 'LHE -> DOH',
      'code': 'DOH',
      'priceUsd': 172,
      'image':
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=1200',
    },
    <String, Object>{
      'title': 'City break',
      'route': 'ISB -> IST',
      'code': 'IST',
      'priceUsd': 268,
      'image':
          'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=1200',
    },
  ];

  String _resolveTravelerName({
    required bool isGuest,
    required String? firestoreName,
    required String? authDisplayName,
    required String? email,
  }) {
    if (isGuest) {
      return 'Guest traveler';
    }
    if (firestoreName != null && firestoreName.trim().isNotEmpty) {
      return firestoreName.trim();
    }
    if (authDisplayName != null && authDisplayName.trim().isNotEmpty) {
      return authDisplayName.trim();
    }
    if (email != null && email.contains('@')) {
      final String handle = email.split('@').first.trim();
      if (handle.isNotEmpty) {
        return handle;
      }
    }
    return 'Traveler';
  }
}

class _FindFlightsPromptCard extends StatelessWidget {
  const _FindFlightsPromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadows(context),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Row(
          children: <Widget>[
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.search_rounded,
                color: theme.colorScheme.primary,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Find flights faster',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Use filters for route, date, passengers, and cabin.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: Size(0, 44.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w),
              ),
              child: const Text('Find'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestUpgradeCard extends StatelessWidget {
  const _GuestUpgradeCard({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Row(
          children: <Widget>[
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.verified_user_outlined,
                color: theme.colorScheme.primary,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Using guest mode',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Sign in to unlock booking, trip sync, payments, and tickets.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            FilledButton(
              onPressed: () async {
                await onTap();
              },
              style: FilledButton.styleFrom(
                minimumSize: Size(0, 40.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.greeting,
    required this.travelerName,
    required this.dateLabel,
  });

  final String greeting;
  final String travelerName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: AppTheme.skyGradient(isDark),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: AppTheme.softShadows(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$greeting, ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: travelerName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4.h),
          Text(
            'Where are you flying next?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18.sp,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Today, $dateLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (action case final Widget trailingAction) trailingAction,
      ],
    );
  }
}

class _DestinationCard extends StatefulWidget {
  const _DestinationCard({required this.destination, required this.onTap});

  final Map<String, Object> destination;
  final VoidCallback onTap;

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double priceUsd = (widget.destination['priceUsd'] as num).toDouble();

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: AppTheme.softShadows(context),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: widget.onTap,
          onHighlightChanged: (bool value) {
            setState(() {
              _pressed = value;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
                child: CachedNetworkImage(
                  imageUrl: widget.destination['image'] as String,
                  height: 104.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (BuildContext context, String url) =>
                      const _ImageShimmerBox(),
                  errorWidget:
                      (BuildContext context, String url, Object error) =>
                          Container(
                            height: 104.h,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.destination['city'] as String,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.destination['country'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      PriceFormatter.format(priceUsd),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
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

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.onTap});

  final Map<String, Object> deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double priceUsd = (deal['priceUsd'] as num).toDouble();

    return Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CachedNetworkImage(
                imageUrl: deal['image'] as String,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String url) =>
                    const _ImageShimmerBox(),
                errorWidget: (BuildContext context, String url, Object error) =>
                    Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.32),
                    ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x22000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        deal['title'] as String,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      deal['route'] as String,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'From ${PriceFormatter.format(priceUsd)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

class _ImageShimmerBox extends StatelessWidget {
  const _ImageShimmerBox();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(color: Theme.of(context).colorScheme.surfaceContainer),
    );
  }
}
