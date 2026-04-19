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

class LiveFlightsRateLimitException extends LiveFlightsException {
  const LiveFlightsRateLimitException(super.message, {this.retryAfter});

  final Duration? retryAfter;
}

class OpenSkyLiveFlightsService {
  const OpenSkyLiveFlightsService();

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _tokenRefreshSkew = Duration(seconds: 30);

  static const String _openSkyClientId = String.fromEnvironment(
    'OPENSKY_CLIENT_ID',
  );
  static const String _openSkyClientSecret = String.fromEnvironment(
    'OPENSKY_CLIENT_SECRET',
  );

  static String? _accessToken;
  static DateTime? _accessTokenExpiresAtUtc;

  static final Uri _oauthTokenUri = Uri.https(
    'auth.opensky-network.org',
    '/auth/realms/opensky-network/protocol/openid-connect/token',
  );

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

      final String? authorizationHeader = await _buildAuthorizationHeader(
        client,
      );
      if (authorizationHeader != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          authorizationHeader,
        );
      }

      final HttpClientResponse response = await request.close().timeout(
        _requestTimeout,
      );

      if (response.statusCode == HttpStatus.tooManyRequests) {
        final Duration retryAfter =
            _parseRetryAfter(response.headers) ?? const Duration(minutes: 2);
        final String authHint = _hasOpenSkyAuthCredentials
            ? ''
            : ' Add OPENSKY_CLIENT_ID and OPENSKY_CLIENT_SECRET via --dart-define to use authenticated free quota.';
        throw LiveFlightsRateLimitException(
          'OpenSky rate limit reached. Try again in ${_formatRetryAfter(retryAfter)}.$authHint',
          retryAfter: retryAfter,
        );
      }

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

  Duration? _parseRetryAfter(HttpHeaders headers) {
    final String? xRetryAfterSeconds = headers.value(
      'x-rate-limit-retry-after-seconds',
    );
    final int? customRetryAfterSeconds = int.tryParse(
      xRetryAfterSeconds?.trim() ?? '',
    );
    if (customRetryAfterSeconds != null && customRetryAfterSeconds > 0) {
      return Duration(seconds: customRetryAfterSeconds);
    }

    final String? rawHeader = headers.value(HttpHeaders.retryAfterHeader);
    if (rawHeader == null || rawHeader.trim().isEmpty) {
      return null;
    }

    final String value = rawHeader.trim();
    final int? seconds = int.tryParse(value);
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }

    try {
      final DateTime retryAtUtc = HttpDate.parse(value);
      final Duration delta = retryAtUtc.difference(DateTime.now().toUtc());
      return delta.isNegative ? const Duration(seconds: 1) : delta;
    } catch (_) {
      return null;
    }
  }

  String _formatRetryAfter(Duration duration) {
    final int seconds = duration.inSeconds <= 0 ? 1 : duration.inSeconds;
    if (seconds >= 60) {
      final int minutes = (seconds / 60).ceil();
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    }
    return '$seconds second${seconds == 1 ? '' : 's'}';
  }

  bool get _hasOpenSkyAuthCredentials {
    return _openSkyClientId.trim().isNotEmpty &&
        _openSkyClientSecret.trim().isNotEmpty;
  }

  Future<String?> _buildAuthorizationHeader(HttpClient client) async {
    if (!_hasOpenSkyAuthCredentials) {
      return null;
    }

    final DateTime nowUtc = DateTime.now().toUtc();
    final String? token = _accessToken;
    final DateTime? expiresAtUtc = _accessTokenExpiresAtUtc;
    if (token != null &&
        expiresAtUtc != null &&
        nowUtc.isBefore(expiresAtUtc)) {
      return 'Bearer $token';
    }

    final String refreshedToken = await _refreshAccessToken(client);
    return 'Bearer $refreshedToken';
  }

  Future<String> _refreshAccessToken(HttpClient client) async {
    final HttpClientRequest tokenRequest = await client
        .postUrl(_oauthTokenUri)
        .timeout(_requestTimeout);

    tokenRequest.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    tokenRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final String payload =
        'grant_type=client_credentials&client_id=${Uri.encodeQueryComponent(_openSkyClientId)}&client_secret=${Uri.encodeQueryComponent(_openSkyClientSecret)}';
    tokenRequest.add(utf8.encode(payload));

    final HttpClientResponse tokenResponse = await tokenRequest.close().timeout(
      _requestTimeout,
    );

    if (tokenResponse.statusCode != HttpStatus.ok) {
      throw LiveFlightsException(
        'OpenSky auth failed with status ${tokenResponse.statusCode}.',
      );
    }

    final String body = await tokenResponse.transform(utf8.decoder).join();
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const LiveFlightsException('Invalid OpenSky auth response format.');
    }

    final String accessToken = (decoded['access_token'] as String? ?? '')
        .trim();
    if (accessToken.isEmpty) {
      throw const LiveFlightsException(
        'OpenSky auth did not return access token.',
      );
    }

    final int expiresInSeconds = _parseExpiresIn(decoded['expires_in']);
    final DateTime tentativeExpiryUtc = DateTime.now().toUtc().add(
      Duration(seconds: expiresInSeconds),
    );
    final DateTime expiryUtc = tentativeExpiryUtc.subtract(_tokenRefreshSkew);

    _accessToken = accessToken;
    _accessTokenExpiresAtUtc = expiryUtc.isAfter(DateTime.now().toUtc())
        ? expiryUtc
        : DateTime.now().toUtc().add(const Duration(seconds: 15));

    return accessToken;
  }

  int _parseExpiresIn(Object? rawValue) {
    if (rawValue is num && rawValue > 0) {
      return rawValue.toInt();
    }
    if (rawValue is String) {
      final int? parsed = int.tryParse(rawValue);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return 1800;
  }
}
