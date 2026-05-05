import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';

abstract class FlightRepository {
  Future<List<Flight>> searchFlights(FlightSearchQuery query);

  Future<List<Flight>> getLastSearchResults();
}



