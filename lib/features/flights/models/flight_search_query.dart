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

  String get routeKey => '$fromAirport-$toAirport';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fromAirport': fromAirport,
      'toAirport': toAirport,
      'date': date.millisecondsSinceEpoch,
      'passengers': passengers,
      'cabinClass': cabinClass,
    };
  }

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



