/// Represents a flight search request.
///
/// Used to:
/// - Capture user input from search form
/// - Query flight service for matching flights
/// - Cache recent searches to Hive
/// - Seed deterministic flight generation
///
/// Search parameters:
/// - fromAirport: Departure airport (IATA code, e.g., 'ISB')
/// - toAirport: Arrival airport (IATA code, e.g., 'DXB')
/// - date: Departure date
/// - passengers: Number of travelers (1-9)
/// - cabinClass: Booking class (Economy, Business, etc.)
///
/// Immutable and serializable to/from maps for Hive storage.
class FlightSearchQuery {
  const FlightSearchQuery({
    required this.fromAirport,
    required this.toAirport,
    required this.date,
    required this.passengers,
    required this.cabinClass,
  });

  final String fromAirport;
  final String toAirport;
  final DateTime date;
  final int passengers;
  final String cabinClass;

  /// Convenience getter for route identifier (e.g., 'ISB-DXB')
  String get routeKey => '$fromAirport-$toAirport';

  /// Converts to Firestore/Hive-compatible map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fromAirport': fromAirport,
      'toAirport': toAirport,
      'date': date.millisecondsSinceEpoch,
      'passengers': passengers,
      'cabinClass': cabinClass,
    };
  }

  /// Reconstructs from stored map (handles missing fields with defaults)
  factory FlightSearchQuery.fromMap(Map<dynamic, dynamic> map) {
    return FlightSearchQuery(
      fromAirport: map['fromAirport'] as String? ?? '',
      toAirport: map['toAirport'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] as int?) ?? 0),
      passengers: map['passengers'] as int? ?? 1,
      cabinClass: map['cabinClass'] as String? ?? 'Economy',
    );
  }
}



