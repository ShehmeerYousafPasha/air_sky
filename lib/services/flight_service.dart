import 'dart:math';

import 'package:air_sky/features/flights/domain/entities/flight.dart';
import 'package:air_sky/features/flights/domain/entities/flight_search_query.dart';

class FlightService {
  const FlightService();

  static const Map<String, String> _airlineLogos = <String, String>{
    'Emirates':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Emirates_logo.svg/320px-Emirates_logo.svg.png',
    'Qatar Airways':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Qatar_Airways_Logo.svg/320px-Qatar_Airways_Logo.svg.png',
    'Turkish Airlines':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Turkish_Airlines_logo_2019_compact.svg/320px-Turkish_Airlines_logo_2019_compact.svg.png',
    'Etihad Airways':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Etihad_Airways_Logo.svg/320px-Etihad_Airways_Logo.svg.png',
    'PIA':
        'https://upload.wikimedia.org/wikipedia/en/thumb/0/06/Pakistan_International_Airlines_logo.svg/320px-Pakistan_International_Airlines_logo.svg.png',
  };

  static const List<String> _airlines = <String>[
    'Emirates',
    'Qatar Airways',
    'Turkish Airlines',
    'Etihad Airways',
    'PIA',
  ];

  static const List<String> _airports = <String>[
    'ISB',
    'DXB',
    'LHR',
    'IST',
    'DOH',
    'KHI',
  ];

  static const Map<String, double> _routeDistanceKm = <String, double>{
    'ISB-DXB': 1920,
    'ISB-LHR': 6030,
    'ISB-IST': 3940,
    'ISB-DOH': 2270,
    'ISB-KHI': 1100,
    'DXB-LHR': 5500,
    'DXB-IST': 3000,
    'DXB-DOH': 390,
    'DXB-KHI': 1180,
    'LHR-IST': 2490,
    'LHR-DOH': 5230,
    'LHR-KHI': 6320,
    'IST-DOH': 2720,
    'IST-KHI': 3990,
    'DOH-KHI': 1560,
  };

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
          airlineLogo: _airlineLogos[airline] ?? '',
          fromAirport: query.fromAirport,
          toAirport: query.toAirport,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          durationMinutes: duration,
          stops: stops,
          layovers: layovers,
          cabinClass: query.cabinClass,
          price: price,
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
