import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/config/currency_controller.dart';
import 'package:air_sky/config/theme_mode_controller.dart';
import 'package:air_sky/utils/price_formatter.dart';
import 'package:air_sky/features/ai_assistant/services/ai_local_assistant_service.dart';
import 'package:air_sky/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:air_sky/features/ai_assistant/services/ai_assistant_controller.dart';
import 'package:air_sky/features/auth/services/auth_repository_impl.dart';
import 'package:air_sky/features/auth/services/unavailable_auth_repository.dart';
import 'package:air_sky/features/auth/services/auth_repository.dart';
import 'package:air_sky/features/auth/services/auth_controller.dart';
import 'package:air_sky/features/auth/services/guest_mode_controller.dart';
import 'package:air_sky/features/booking/services/booking_repository_impl.dart';
import 'package:air_sky/features/booking/services/unavailable_booking_repository.dart';
import 'package:air_sky/features/booking/services/booking_repository.dart';
import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/booking/services/booking_controller.dart';
import 'package:air_sky/features/flights/services/flight_repository_impl.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';
import 'package:air_sky/features/flights/services/flight_repository.dart';
import 'package:air_sky/features/flights/services/flight_search_controller.dart';
import 'package:air_sky/features/flights/services/search_form_controller.dart';
import 'package:air_sky/features/onboarding/services/onboarding_controller.dart';
import 'package:air_sky/services/firebase_bootstrap.dart';
import 'package:air_sky/services/flight_service.dart';
import 'package:air_sky/services/local_storage_service.dart';

final Provider<FirebaseBootstrapResult> firebaseBootstrapProvider =
    Provider<FirebaseBootstrapResult>(
      (Ref ref) => const FirebaseBootstrapResult(isReady: false),
    );

final Provider<LocalStorageService> localStorageServiceProvider =
    Provider<LocalStorageService>((Ref ref) => const LocalStorageService());

final Provider<FlightService> flightServiceProvider = Provider<FlightService>(
  (Ref ref) => const FlightService(),
);

final StateNotifierProvider<OnboardingController, bool>
onboardingCompletedProvider = StateNotifierProvider<OnboardingController, bool>(
  (Ref ref) => OnboardingController(ref.watch(localStorageServiceProvider)),
);

final StateNotifierProvider<GuestModeController, bool> guestModeProvider =
    StateNotifierProvider<GuestModeController, bool>(
      (Ref ref) => GuestModeController(ref.watch(localStorageServiceProvider)),
    );

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      final FirebaseBootstrapResult bootstrap = ref.watch(
        firebaseBootstrapProvider,
      );
      if (!bootstrap.isReady) {
        return UnavailableAuthRepository();
      }
      return AuthRepositoryImpl(
        FirebaseAuth.instance,
        FirebaseFirestore.instance,
      );
    });

final StreamProvider<User?> authStateChangesProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final StreamProvider<Map<String, dynamic>?> userProfileDataProvider =
    StreamProvider<Map<String, dynamic>?>((Ref ref) {
      final FirebaseBootstrapResult bootstrap = ref.watch(
        firebaseBootstrapProvider,
      );
      final bool isGuest = ref.watch(guestModeProvider);
      final User? user = ref.watch(authStateChangesProvider).valueOrNull;

      if (!bootstrap.isReady || isGuest || user == null) {
        return Stream<Map<String, dynamic>?>.value(null);
      }

      return (() async* {
        try {
          await for (final DocumentSnapshot<Map<String, dynamic>> snap
              in FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots()) {
            yield snap.data();
          }
        } catch (_) {
          yield null;
        }
      })();
    });

final StreamProvider<String?> userProfileNameProvider = StreamProvider<String?>(
  (Ref ref) {
    final FirebaseBootstrapResult bootstrap = ref.watch(
      firebaseBootstrapProvider,
    );
    final bool isGuest = ref.watch(guestModeProvider);
    final User? user = ref.watch(authStateChangesProvider).valueOrNull;

    if (!bootstrap.isReady || isGuest || user == null) {
      return Stream<String?>.value(null);
    }

    return (() async* {
      try {
        await for (final DocumentSnapshot<Map<String, dynamic>> snap
            in FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()) {
          final Map<String, dynamic>? data = snap.data();
          final dynamic rawName = data?['name'];
          if (rawName is String && rawName.trim().isNotEmpty) {
            yield rawName.trim();
          } else {
            yield null;
          }
        }
      } catch (_) {
        yield null;
      }
    })();
  },
);

final StateNotifierProvider<AuthController, AsyncValue<void>>
authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
      (Ref ref) => AuthController(ref.watch(authRepositoryProvider)),
    );

final Provider<FlightRepository> flightRepositoryProvider =
    Provider<FlightRepository>(
      (Ref ref) => FlightRepositoryImpl(
        ref.watch(flightServiceProvider),
        ref.watch(localStorageServiceProvider),
      ),
    );

final Provider<AiLocalAssistantService> aiLocalAssistantServiceProvider =
    Provider<AiLocalAssistantService>(
      (Ref ref) => const AiLocalAssistantService(),
    );

final StateNotifierProvider<AiAssistantController, AiAssistantState>
aiAssistantControllerProvider =
    StateNotifierProvider<AiAssistantController, AiAssistantState>(
      (Ref ref) => AiAssistantController(
        ref.watch(flightRepositoryProvider),
        ref.watch(aiLocalAssistantServiceProvider),
        ref.watch(bookingRepositoryProvider),
      ),
    );

final StateNotifierProvider<FlightSearchController, FlightSearchState>
flightSearchControllerProvider =
    StateNotifierProvider<FlightSearchController, FlightSearchState>(
      (Ref ref) => FlightSearchController(ref.watch(flightRepositoryProvider)),
    );

final StateNotifierProvider<SearchFormController, SearchFormState>
searchFormControllerProvider =
    StateNotifierProvider<SearchFormController, SearchFormState>(
      (Ref ref) => SearchFormController(),
    );

final StateNotifierProvider<RecentSearchesController, List<FlightSearchQuery>>
recentSearchesProvider =
    StateNotifierProvider<RecentSearchesController, List<FlightSearchQuery>>(
      (Ref ref) =>
          RecentSearchesController(ref.watch(localStorageServiceProvider)),
    );

final Provider<BookingRepository> bookingRepositoryProvider =
    Provider<BookingRepository>((Ref ref) {
      final FirebaseBootstrapResult bootstrap = ref.watch(
        firebaseBootstrapProvider,
      );
      if (!bootstrap.isReady) {
        return UnavailableBookingRepository();
      }
      return BookingRepositoryImpl(FirebaseFirestore.instance);
    });

final StateNotifierProvider<BookingController, BookingState>
bookingControllerProvider =
    StateNotifierProvider<BookingController, BookingState>(
      (Ref ref) => BookingController(ref.watch(bookingRepositoryProvider)),
    );

final StreamProvider<List<Booking>> userBookingsProvider =
    StreamProvider<List<Booking>>((Ref ref) {
      final User? user = ref.watch(authStateChangesProvider).valueOrNull;
      if (user == null) {
        return Stream<List<Booking>>.value(const <Booking>[]);
      }
      return ref.watch(bookingRepositoryProvider).watchUserBookings(user.uid);
    });

final StateNotifierProvider<ThemeModeController, ThemeMode>
themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
      (Ref ref) => ThemeModeController(ref.watch(localStorageServiceProvider)),
    );

final StateNotifierProvider<CurrencyController, AppCurrency>
currencyControllerProvider =
    StateNotifierProvider<CurrencyController, AppCurrency>(
      (Ref ref) => CurrencyController(ref.watch(localStorageServiceProvider)),
    );



