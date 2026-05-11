import 'dart:math';

import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';

/// Mock flight generation service for prototyping and testing.
///
/// This service generates deterministic, realistic flight data for development.
/// In production, this would be replaced with actual Schiphol API or other
/// live flight search service integration.
///
/// Key design decisions:
/// - Uses seeded [Random] based on search parameters for consistent results
/// - Generates 18 flights per search to simulate real-world variety
/// - Includes realistic stops, layovers, pricing, and flight times
/// - Prices vary based on distance, cabin class, and days until travel
///
/// TODO: Replace with live Schiphol API integration for production
class FlightService {
  const FlightService();

  /// Supported airlines for mock generation
  static const List<String> _airlines = <String>[
    'Emirates',
    'Qatar Airways',
    'Turkish Airlines',
    'Etihad Airways',
    'PIA',
  ];

  /// Major airport codes used in mock route generation
  static const List<String> _airports = <String>[
    'ISB',
    'DXB',
    'SIN',
    'LHR',
    'IST',
    'DOH',
    'KHI',
  ];

  /// Approximate distances between major routes (in kilometers)
  /// Used for realistic flight duration and pricing calculations
  static const Map<String, double> _routeDistanceKm = <String, double>{
    'ISB-DXB': 1920,
    'ISB-SIN': 4780,
    'ISB-LHR': 6030,
    'ISB-IST': 3940,
    'ISB-DOH': 2270,
    'ISB-KHI': 1100,
    'DXB-SIN': 5840,
    'DXB-LHR': 5500,
    'DXB-IST': 3000,
    'DXB-DOH': 390,
    'DXB-KHI': 1180,
    'SIN-LHR': 10880,
    'SIN-IST': 8680,
    'SIN-DOH': 6210,
    'SIN-KHI': 4760,
    'LHR-IST': 2490,
    'LHR-DOH': 5230,
    'LHR-KHI': 6320,
    'IST-DOH': 2720,
    'IST-KHI': 3990,
    'DOH-KHI': 1560,
  };

  /// Generates mock flights for a given search query.
  ///
  /// Returns a list of 18 deterministic flights that match the search criteria.
  /// Results are seeded based on the search parameters to ensure consistent
  /// results across app restarts for the same query.
  ///
  /// Flight generation includes:
  /// - Random airline selection from supported carriers
  /// - Stop variation (0-2 stops with realistic frequencies)
  /// - Realistic flight times based on route distance
  /// - Dynamic pricing based on distance, dates, and demand
  /// - Layover information for connecting flights
  ///
  /// Parameters:
  ///   - query: Search criteria (route, date, passengers, cabin class)
  ///
  /// Returns: List of 18 [Flight] objects
  List<Flight> generateFlights(FlightSearchQuery query) {
    final int seed = Object.hash(
      query.fromAirport,
      query.toAirport,
      query.date.year,
      query.date.month,
      query.date.day,
      query.passengers,
      query.cabinClass,
    );

    final Random random = Random(seed);
    final List<Flight> flights = <Flight>[];

    final double distance = _distanceBetween(
      query.fromAirport,
      query.toAirport,
    );
    final int daysToTrip = query.date.difference(DateTime.now()).inDays;

    for (int i = 0; i < 18; i++) {
      final String airline = _airlines[random.nextInt(_airlines.length)];
      final int stops = random.nextDouble() < 0.55
          ? 0
          : (random.nextDouble() < 0.8 ? 1 : 2);

      final DateTime departureTime = DateTime(
        query.date.year,
        query.date.month,
        query.date.day,
        5 + random.nextInt(17),
        random.nextInt(12) * 5,
      );

      final int baseDuration = (distance / 13).round();
      final int duration = baseDuration + random.nextInt(55) + (stops * 80);
      final DateTime arrivalTime = departureTime.add(
        Duration(minutes: duration),
      );

      final List<String> layovers = _generateLayovers(
        random: random,
        stops: stops,
        from: query.fromAirport,
        to: query.toAirport,
      );

      final double price = _priceFor(
        distanceKm: distance,
        travelDate: query.date,
        daysToTrip: daysToTrip,
        passengers: query.passengers,
        cabinClass: query.cabinClass,
        stops: stops,
        random: random,
      );

      flights.add(
        Flight(
          id: 'FLT-${query.routeKey}-$i',
          airline: airline,
          airlineLogo: Flight.preferredLogoForAirline(airline),
          fromAirport: query.fromAirport,
          toAirport: query.toAirport,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          durationMinutes: duration,
          stops: stops,
          layovers: layovers,
          cabinClass: query.cabinClass,
          price: price,
          passengers: query.passengers,
        ),
      );
    }

    return flights;
  }

  List<double> generateFareTrend({
    required String from,
    required String to,
    required DateTime anchorDate,
  }) {
    final Random random = Random(
      Object.hash(from, to, anchorDate.millisecondsSinceEpoch),
    );
    final double distance = _distanceBetween(from, to);
    final List<double> trend = <double>[];

    for (int i = 0; i < 7; i++) {
      final DateTime date = anchorDate.add(Duration(days: i));
      final double price = _priceFor(
        distanceKm: distance,
        travelDate: date,
        daysToTrip: date.difference(DateTime.now()).inDays,
        passengers: 1,
        cabinClass: 'Economy',
        stops: i % 2,
        random: random,
      );
      trend.add(price);
    }

    return trend;
  }

  double _distanceBetween(String from, String to) {
    if (from == to) {
      return 250;
    }

    final List<String> route = <String>[from, to]..sort();
    final String key = '${route.first}-${route.last}';
    return _routeDistanceKm[key] ??
        (1400 + (key.hashCode.abs() % 3500)).toDouble();
  }

  List<String> _generateLayovers({
    required Random random,
    required int stops,
    required String from,
    required String to,
  }) {
    if (stops == 0) {
      return <String>[];
    }

    final List<String> candidates = _airports
        .where((String airport) => airport != from && airport != to)
        .toList();

    candidates.shuffle(random);
    return candidates.take(stops).toList();
  }

  double _priceFor({
    required double distanceKm,
    required DateTime travelDate,
    required int daysToTrip,
    required int passengers,
    required String cabinClass,
    required int stops,
    required Random random,
  }) {
    final bool weekend =
        travelDate.weekday == DateTime.friday ||
        travelDate.weekday == DateTime.saturday ||
        travelDate.weekday == DateTime.sunday;

    final double base = 40 + (distanceKm * 0.12);
    final double cabinFactor = switch (cabinClass) {
      'Premium Economy' => 1.35,
      'Business' => 2.1,
      'First' => 3.2,
      _ => 1.0,
    };

    final double urgencyFactor = daysToTrip <= 3
        ? 1.45
        : daysToTrip <= 7
        ? 1.22
        : daysToTrip >= 45
        ? 0.88
        : 1.0;

    final double weekendFactor = weekend ? 1.16 : 1.0;
    final double demandFactor = 0.85 + (random.nextDouble() * 0.55);
    final double stopFactor = stops == 0 ? 1.08 : (stops == 1 ? 0.95 : 0.86);

    final double computed =
        base *
        cabinFactor *
        urgencyFactor *
        weekendFactor *
        demandFactor *
        stopFactor;

    return (max(75, computed) * passengers).toDouble();
  }
}



