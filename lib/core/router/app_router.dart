import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/features/auth/presentation/screens/login_screen.dart';
import 'package:air_sky/features/auth/presentation/screens/signup_screen.dart';
import 'package:air_sky/features/booking/presentation/screens/booking_screen.dart';
import 'package:air_sky/features/booking/presentation/screens/my_trips_screen.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';
import 'package:air_sky/features/flights/presentation/screens/flight_details_screen.dart';
import 'package:air_sky/features/flights/presentation/screens/flight_results_screen.dart';
import 'package:air_sky/features/flights/presentation/screens/flight_search_screen.dart';
import 'package:air_sky/features/home/presentation/screens/home_screen.dart';
import 'package:air_sky/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:air_sky/features/profile/presentation/screens/profile_screen.dart';
import 'package:air_sky/features/splash/presentation/screens/splash_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

final Provider<_RouterRefreshNotifier> _routerRefreshNotifierProvider =
    Provider<_RouterRefreshNotifier>((Ref ref) {
      final _RouterRefreshNotifier notifier = _RouterRefreshNotifier();

      ref.listen<AsyncValue<User?>>(authStateChangesProvider, (
        AsyncValue<User?>? previous,
        AsyncValue<User?> next,
      ) {
        notifier.refresh();
      });
      ref.listen<bool>(onboardingCompletedProvider, (
        bool? previous,
        bool next,
      ) {
        notifier.refresh();
      });
      ref.listen<bool>(guestModeProvider, (bool? previous, bool next) {
        notifier.refresh();
      });

      ref.onDispose(notifier.dispose);
      return notifier;
    });

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

      final bool isSplashRoute = location == RoutePaths.splash;
      final bool isOnboardingRoute = location == RoutePaths.onboarding;
      final bool isAuthRoute =
          location == RoutePaths.login || location == RoutePaths.signup;
      final bool isGuestRestrictedRoute =
          location == RoutePaths.flightDetails ||
          location == RoutePaths.booking;

      if (isSplashRoute) {
        return null;
      }

      if (!onboardingCompleted && !isOnboardingRoute && !isAuthRoute) {
        return RoutePaths.onboarding;
      }

      if (authState.isLoading) {
        return null;
      }

      final User? user = authState.valueOrNull;
      final bool isVerifiedUser = user != null && user.emailVerified;
      final bool hasAccess = isVerifiedUser || isGuest;

      if (isGuest && isGuestRestrictedRoute) {
        return RoutePaths.search;
      }

      if (onboardingCompleted && isOnboardingRoute) {
        return hasAccess ? RoutePaths.home : RoutePaths.login;
      }

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
