class LiveFlight {
  const LiveFlight({
    required this.icao24,
    required this.latitude,
    required this.longitude,
    required this.callsign,
    required this.originCountry,
    required this.velocityMetersPerSecond,
    required this.headingDegrees,
    required this.lastContactEpoch,
  });

  final String icao24;
  final double latitude;
  final double longitude;
  final String callsign;
  final String originCountry;
  final double? velocityMetersPerSecond;
  final double? headingDegrees;
  final int lastContactEpoch;

  String get displayCallsign {
    final String value = callsign.trim();
    return value.isEmpty ? 'N/A' : value;
  }

  String get displayOriginCountry {
    final String value = originCountry.trim();
    return value.isEmpty ? 'Unknown' : value;
  }

  double? get speedKmh {
    final double? velocity = velocityMetersPerSecond;
    if (velocity == null || velocity <= 0) {
      return null;
    }
    return velocity * 3.6;
  }
}



