class Flight {
  const Flight({
    required this.id,
    required this.airline,
    required this.airlineLogo,
    required this.fromAirport,
    required this.toAirport,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.stops,
    required this.layovers,
    required this.cabinClass,
    required this.price,
  });

  final String id;
  final String airline;
  final String airlineLogo;
  final String fromAirport;
  final String toAirport;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int durationMinutes;
  final int stops;
  final List<String> layovers;
  final String cabinClass;
  final double price;

  String get durationLabel {
    final int hours = durationMinutes ~/ 60;
    final int minutes = durationMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String get stopsLabel {
    if (stops == 0) {
      return 'Non-stop';
    }
    if (stops == 1) {
      return '1 stop';
    }
    return '$stops stops';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'airline': airline,
      'airlineLogo': airlineLogo,
      'fromAirport': fromAirport,
      'toAirport': toAirport,
      'departureTime': departureTime.millisecondsSinceEpoch,
      'arrivalTime': arrivalTime.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'stops': stops,
      'layovers': layovers,
      'cabinClass': cabinClass,
      'price': price,
    };
  }

  factory Flight.fromMap(Map<dynamic, dynamic> map) {
    return Flight(
      id: map['id'] as String? ?? '',
      airline: map['airline'] as String? ?? '',
      airlineLogo: map['airlineLogo'] as String? ?? '',
      fromAirport: map['fromAirport'] as String? ?? '',
      toAirport: map['toAirport'] as String? ?? '',
      departureTime: DateTime.fromMillisecondsSinceEpoch(
        (map['departureTime'] as int?) ?? 0,
      ),
      arrivalTime: DateTime.fromMillisecondsSinceEpoch(
        (map['arrivalTime'] as int?) ?? 0,
      ),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      stops: map['stops'] as int? ?? 0,
      layovers: ((map['layovers'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      cabinClass: map['cabinClass'] as String? ?? 'Economy',
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }
}
