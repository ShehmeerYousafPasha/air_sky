import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/live_map/data/open_sky_live_flights_service.dart';
import 'package:air_sky/features/live_map/domain/entities/live_flight.dart';

class LiveFlightsState {
  const LiveFlightsState({
    required this.flights,
    required this.isInitialLoading,
    required this.isRefreshing,
    required this.errorMessage,
    required this.lastUpdatedAt,
  });

  final List<LiveFlight> flights;
  final bool isInitialLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final DateTime? lastUpdatedAt;

  factory LiveFlightsState.initial() {
    return const LiveFlightsState(
      flights: <LiveFlight>[],
      isInitialLoading: true,
      isRefreshing: false,
      errorMessage: null,
      lastUpdatedAt: null,
    );
  }

  LiveFlightsState copyWith({
    List<LiveFlight>? flights,
    bool? isInitialLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? lastUpdatedAt,
  }) {
    return LiveFlightsState(
      flights: flights ?? this.flights,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

final Provider<OpenSkyLiveFlightsService> openSkyLiveFlightsServiceProvider =
    Provider<OpenSkyLiveFlightsService>(
      (Ref ref) => const OpenSkyLiveFlightsService(),
    );

final liveFlightsControllerProvider =
    StateNotifierProvider.autoDispose<LiveFlightsController, LiveFlightsState>(
      (Ref ref) =>
          LiveFlightsController(ref.watch(openSkyLiveFlightsServiceProvider)),
    );

class LiveFlightsController extends StateNotifier<LiveFlightsState> {
  LiveFlightsController(this._service) : super(LiveFlightsState.initial()) {
    _bootstrap();
  }

  static const Duration _pollInterval = Duration(seconds: 12);
  static const int _maxMarkers = 220;

  final OpenSkyLiveFlightsService _service;
  Timer? _pollTimer;
  bool _isFetching = false;

  Future<void> _bootstrap() async {
    await refresh(isInitial: true);
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(refresh(background: true));
    });
  }

  Future<void> refresh({
    bool isInitial = false,
    bool background = false,
  }) async {
    if (_isFetching) {
      return;
    }
    _isFetching = true;

    final bool hadFlights = state.flights.isNotEmpty;
    state = state.copyWith(
      isInitialLoading: isInitial && !hadFlights,
      isRefreshing: true,
      clearErrorMessage: background,
    );

    try {
      final List<LiveFlight> flights = await _service.fetchFlights(
        maxFlights: _maxMarkers,
      );

      state = state.copyWith(
        flights: flights,
        isInitialLoading: false,
        isRefreshing: false,
        clearErrorMessage: true,
        lastUpdatedAt: DateTime.now(),
      );
    } catch (error) {
      final String message = error is LiveFlightsException
          ? error.message
          : 'Unable to refresh live flights right now.';

      state = state.copyWith(
        isInitialLoading: false,
        isRefreshing: false,
        errorMessage: hadFlights
            ? 'Live update failed. Showing last known flights.'
            : message,
      );
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refreshManually() => refresh();

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
