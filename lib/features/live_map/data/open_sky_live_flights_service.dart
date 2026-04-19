import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:air_sky/features/live_map/domain/entities/live_flight.dart';

class LiveFlightsException implements Exception {
  const LiveFlightsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenSkyLiveFlightsService {
  const OpenSkyLiveFlightsService();

  static const Duration _requestTimeout = Duration(seconds: 8);

  static final Uri _regionalUri = Uri.https(
    'opensky-network.org',
    '/api/states/all',
    <String, String>{
      // Limit to a broad South/Central Asia region to keep marker count light.
      'lamin': '5',
      'lamax': '42',
      'lomin': '55',
      'lomax': '100',
    },
  );

  Future<List<LiveFlight>> fetchFlights({int maxFlights = 220}) async {
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request = await client
          .getUrl(_regionalUri)
          .timeout(_requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'AirSky-BookAndFly/1.0');

      final HttpClientResponse response = await request.close().timeout(
        _requestTimeout,
      );

      if (response.statusCode != HttpStatus.ok) {
        throw LiveFlightsException(
          'OpenSky returned status ${response.statusCode}.',
        );
      }

      final String body = await response.transform(utf8.decoder).join();
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const LiveFlightsException('Invalid OpenSky response format.');
      }

      final List<dynamic> states =
          decoded['states'] as List<dynamic>? ?? const <dynamic>[];
      final List<LiveFlight> flights = <LiveFlight>[];

      for (final dynamic rawState in states) {
        final LiveFlight? parsed = _parseFlight(rawState);
        if (parsed != null) {
          flights.add(parsed);
        }
      }

      flights.sort(
        (LiveFlight a, LiveFlight b) =>
            b.lastContactEpoch.compareTo(a.lastContactEpoch),
      );

      if (flights.length > maxFlights) {
        return flights.sublist(0, maxFlights);
      }
      return flights;
    } on LiveFlightsException {
      rethrow;
    } on TimeoutException {
      throw const LiveFlightsException('Live map request timed out.');
    } on SocketException {
      throw const LiveFlightsException(
        'No internet connection available for live map.',
      );
    } catch (_) {
      throw const LiveFlightsException('Unable to load live flight data.');
    } finally {
      client.close(force: true);
    }
  }

  LiveFlight? _parseFlight(dynamic rawState) {
    if (rawState is! List<dynamic> || rawState.length < 11) {
      return null;
    }

    final double? longitude = _toDouble(rawState[5]);
    final double? latitude = _toDouble(rawState[6]);
    if (longitude == null || latitude == null) {
      return null;
    }

    final String icao24 = (rawState[0] as String? ?? '').trim();
    if (icao24.isEmpty) {
      return null;
    }

    return LiveFlight(
      icao24: icao24,
      latitude: latitude,
      longitude: longitude,
      callsign: (rawState[1] as String? ?? '').trim(),
      originCountry: (rawState[2] as String? ?? '').trim(),
      velocityMetersPerSecond: _toDouble(rawState[9]),
      headingDegrees: _toDouble(rawState[10]),
      lastContactEpoch: (rawState[4] as num?)?.toInt() ?? 0,
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
