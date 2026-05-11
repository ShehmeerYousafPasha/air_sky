import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/route_paths.dart';
import 'package:air_sky/features/auth/screens/login_screen.dart';
import 'package:air_sky/features/auth/screens/signup_screen.dart';
import 'package:air_sky/features/booking/screens/booking_screen.dart';
import 'package:air_sky/features/booking/screens/my_trips_screen.dart';
import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/screens/flight_details_screen.dart';
import 'package:air_sky/features/flights/screens/flight_results_screen.dart';
import 'package:air_sky/features/flights/screens/flight_search_screen.dart';
import 'package:air_sky/features/home/screens/home_screen.dart';
import 'package:air_sky/features/live_map/screens/live_flights_map_screen.dart';
import 'package:air_sky/features/notifications/screens/notifications_screen.dart';
import 'package:air_sky/features/onboarding/screens/onboarding_screen.dart';
import 'package:air_sky/features/profile/screens/profile_screen.dart';
import 'package:air_sky/features/splash/screens/splash_screen.dart';

/// Change notifier for router refresh triggers.
/// Listens to auth state, onboarding completion, and guest mode changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

/// Provider for router refresh notifier.
/// Triggers route re-evaluation when auth or user preference state changes.
final Provider<_RouterRefreshNotifier> _routerRefreshNotifierProvider =
    Provider<_RouterRefreshNotifier>((Ref ref) {
      final _RouterRefreshNotifier notifier = _RouterRefreshNotifier();

  // Refresh router when auth state changes (login/logout/email verification)
      ref.listen<AsyncValue<User?>>(authStateChangesProvider, (
        AsyncValue<User?>? previous,
        AsyncValue<User?> next,
      ) {
        notifier.refresh();
      });
      
      // Refresh router when onboarding is completed
      ref.listen<bool>(onboardingCompletedProvider, (
        bool? previous,
        bool next,
      ) {
        notifier.refresh();
      });
      
  // Refresh router when guest mode is toggled
      ref.listen<bool>(guestModeProvider, (bool? previous, bool next) {
        notifier.refresh();
      });

      ref.onDispose(notifier.dispose);
      return notifier;
    });

/// Main GoRouter provider with redirect logic for auth guards and guest restrictions.
///
/// ROUTING PRIORITY (in order of evaluation):
/// 1. Splash screen (always allowed while loading)
/// 2. Onboarding (required if not completed)
/// 3. Auth screens (login/signup - skip if authenticated or guest)
/// 4. Guest restrictions (guests cannot access booking/trip screens)
/// 5. Auth requirement (non-guests must have verified email)
///
/// STATES:
/// - Verified User: Full app access
/// - Email Unverified: Blocked until email verification
/// - Guest User: Can search flights but not book
/// - First Launch: Must complete onboarding first
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshNotifier refreshNotifier = ref.read(
    _routerRefreshNotifierProvider,
  );

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<User?> authState = ref.read(authStateChangesProvider);
      final bool onboardingCompleted = ref.read(onboardingCompletedProvider);
      final bool isGuest = ref.read(guestModeProvider);

      final String location = state.matchedLocation;

      // Helper flags to identify route types
      final bool isSplashRoute = location == RoutePaths.splash;
      final bool isOnboardingRoute = location == RoutePaths.onboarding;
      final bool isAuthRoute =
          location == RoutePaths.login || location == RoutePaths.signup;
      final bool isGuestRestrictedRoute =
          location == RoutePaths.flightDetails ||
          location == RoutePaths.booking;

      // Allow splash screen to display while loading auth state
      if (isSplashRoute) {
        return null;
      }

      // Require onboarding completion before accessing any other route
      if (!onboardingCompleted && !isOnboardingRoute && !isAuthRoute) {
        return RoutePaths.onboarding;
      }

      // Wait for auth state to load before making routing decisions
      if (authState.isLoading) {
        return null;
      }

      // Determine user's access level
      final User? user = authState.valueOrNull;
      final bool isVerifiedUser = user != null && user.emailVerified;
      final bool hasAccess = isVerifiedUser || isGuest;

      // Prevent guests from accessing booking-only routes
      if (isGuest && isGuestRestrictedRoute) {
        return RoutePaths.search;
      }

      // Skip onboarding if already completed
      if (onboardingCompleted && isOnboardingRoute) {
        return hasAccess ? RoutePaths.home : RoutePaths.login;
      }

      // Require authentication for protected routes
      if (!hasAccess && onboardingCompleted && !isAuthRoute) {
        return RoutePaths.login;
      }

      if (isVerifiedUser && isAuthRoute) {
        return RoutePaths.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.search,
        builder: (BuildContext context, GoRouterState state) =>
            const FlightSearchScreen(),
      ),
      GoRoute(
        path: RoutePaths.results,
        builder: (BuildContext context, GoRouterState state) =>
            const FlightResultsScreen(),
      ),
      GoRoute(
        path: RoutePaths.flightDetails,
        builder: (BuildContext context, GoRouterState state) {
          final extra = state.extra;
          if (extra is! Flight) {
            return const _RouteDataErrorScreen();
          }
          return FlightDetailsScreen(flight: extra);
        },
      ),
      GoRoute(
        path: RoutePaths.booking,
        builder: (BuildContext context, GoRouterState state) {
          final extra = state.extra;
          if (extra is! Flight) {
            return const _RouteDataErrorScreen();
          }
          return BookingScreen(flight: extra);
        },
      ),
      GoRoute(
        path: RoutePaths.myTrips,
        builder: (BuildContext context, GoRouterState state) =>
            const MyTripsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.liveMap,
        builder: (BuildContext context, GoRouterState state) =>
            const LiveFlightsMapScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
    ],
  );
});

class _RouteDataErrorScreen extends StatelessWidget {
  const _RouteDataErrorScreen();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Something went wrong')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'We could not open this page right now.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go(RoutePaths.home),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Go to home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



