import 'package:air_sky/features/flights/domain/entities/flight.dart';
import 'package:air_sky/features/flights/domain/entities/flight_search_query.dart';
import 'package:air_sky/features/flights/domain/flight_repository.dart';
import 'package:air_sky/services/flight_service.dart';
import 'package:air_sky/services/local_storage_service.dart';

class FlightRepositoryImpl implements FlightRepository {
  FlightRepositoryImpl(this._flightService, this._localStorageService);

  final FlightService _flightService;
  final LocalStorageService _localStorageService;

  @override
  Future<List<Flight>> searchFlights(FlightSearchQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final List<Flight> flights = _flightService.generateFlights(query);
    await _localStorageService.saveRecentSearch(query);
    await _localStorageService.saveLastSearchResults(flights);
    return flights;
  }

  @override
  Future<List<Flight>> getLastSearchResults() async {
    return _localStorageService.getLastSearchResults();
  }
}
