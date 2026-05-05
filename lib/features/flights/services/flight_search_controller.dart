import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';
import 'package:air_sky/features/flights/services/flight_repository.dart';
import 'package:air_sky/services/local_storage_service.dart';

enum FlightSortOption { cheapest, fastest }

class FlightSearchState {
  const FlightSearchState({
    required this.isLoading,
    required this.allFlights,
    required this.visibleFlights,
    required this.sortOption,
    this.maxStops,
    this.maxPrice,
    this.query,
    this.errorMessage,
    this.fromCache = false,
  });

  final bool isLoading;
  final List<Flight> allFlights;
  final List<Flight> visibleFlights;
  final FlightSortOption sortOption;
  final int? maxStops;
  final double? maxPrice;
  final FlightSearchQuery? query;
  final String? errorMessage;
  final bool fromCache;

  factory FlightSearchState.initial() {
    return const FlightSearchState(
      isLoading: false,
      allFlights: <Flight>[],
      visibleFlights: <Flight>[],
      sortOption: FlightSortOption.cheapest,
    );
  }

  FlightSearchState copyWith({
    bool? isLoading,
    List<Flight>? allFlights,
    List<Flight>? visibleFlights,
    FlightSortOption? sortOption,
    int? maxStops,
    bool clearMaxStops = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    FlightSearchQuery? query,
    bool clearQuery = false,
    String? errorMessage,
    bool clearError = false,
    bool? fromCache,
  }) {
    return FlightSearchState(
      isLoading: isLoading ?? this.isLoading,
      allFlights: allFlights ?? this.allFlights,
      visibleFlights: visibleFlights ?? this.visibleFlights,
      sortOption: sortOption ?? this.sortOption,
      maxStops: clearMaxStops ? null : (maxStops ?? this.maxStops),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      query: clearQuery ? null : (query ?? this.query),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class FlightSearchController extends StateNotifier<FlightSearchState> {
  FlightSearchController(this._repository) : super(FlightSearchState.initial());

  final FlightRepository _repository;

  String _searchFallbackMessage({required bool hasCachedResults}) {
    if (hasCachedResults) {
      return 'Live flight results are unavailable. Showing your last saved results.';
    }
    return 'We could not load flights right now. Please try again.';
  }

  Future<void> searchFlights(FlightSearchQuery query) async {
    state = state.copyWith(
      isLoading: true,
      query: query,
      clearError: true,
      fromCache: false,
      clearMaxStops: true,
      clearMaxPrice: true,
    );

    try {
      final List<Flight> flights = await _repository.searchFlights(query);
      final List<Flight> filtered = _applySortAndFilters(
        flights,
        state.sortOption,
        maxStops: null,
        maxPrice: null,
      );

      state = state.copyWith(
        isLoading: false,
        allFlights: flights,
        visibleFlights: filtered,
      );
    } catch (error) {
      final List<Flight> cached = await _repository.getLastSearchResults();
      final List<Flight> filtered = _applySortAndFilters(
        cached,
        state.sortOption,
        maxStops: null,
        maxPrice: null,
      );

      state = state.copyWith(
        isLoading: false,
        allFlights: cached,
        visibleFlights: filtered,
        errorMessage: _searchFallbackMessage(
          hasCachedResults: cached.isNotEmpty,
        ),
        fromCache: cached.isNotEmpty,
      );
    }
  }

  void sortBy(FlightSortOption option) {
    final List<Flight> sorted = _applySortAndFilters(
      state.allFlights,
      option,
      maxStops: state.maxStops,
      maxPrice: state.maxPrice,
    );

    state = state.copyWith(sortOption: option, visibleFlights: sorted);
  }

  void applyFilters({int? maxStops, double? maxPrice}) {
    final List<Flight> filtered = _applySortAndFilters(
      state.allFlights,
      state.sortOption,
      maxStops: maxStops,
      maxPrice: maxPrice,
    );

    state = state.copyWith(
      visibleFlights: filtered,
      maxStops: maxStops,
      maxPrice: maxPrice,
    );
  }

  Future<void> loadCachedResults() async {
    final List<Flight> cached = await _repository.getLastSearchResults();
    final List<Flight> filtered = _applySortAndFilters(
      cached,
      state.sortOption,
      maxStops: state.maxStops,
      maxPrice: state.maxPrice,
    );

    state = state.copyWith(
      allFlights: cached,
      visibleFlights: filtered,
      fromCache: cached.isNotEmpty,
      clearError: true,
    );
  }

  List<Flight> _applySortAndFilters(
    List<Flight> flights,
    FlightSortOption sort, {
    int? maxStops,
    double? maxPrice,
  }) {
    final List<Flight> items = List<Flight>.from(flights);

    final List<Flight> filtered = items.where((Flight flight) {
      final bool byStops = maxStops == null || flight.stops <= maxStops;
      final bool byPrice = maxPrice == null || flight.price <= maxPrice;
      return byStops && byPrice;
    }).toList();

    filtered.sort((Flight a, Flight b) {
      if (sort == FlightSortOption.fastest) {
        return a.durationMinutes.compareTo(b.durationMinutes);
      }
      return a.price.compareTo(b.price);
    });

    return filtered;
  }
}

class RecentSearchesController extends StateNotifier<List<FlightSearchQuery>> {
  RecentSearchesController(this._storage) : super(_storage.getRecentSearches());

  final LocalStorageService _storage;

  Future<void> refresh() async {
    state = _storage.getRecentSearches();
  }

  Future<void> clear() async {
    await _storage.clearRecentSearches();
    state = const <FlightSearchQuery>[];
  }
}



