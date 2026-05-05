import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:air_sky/config/hive_constants.dart';
import 'package:air_sky/utils/price_formatter.dart';
import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';

class LocalStorageService {
  const LocalStorageService();

  static Future<void> initialize() async {
    await Hive.openBox<dynamic>(HiveConstants.settingsBox);
    await Hive.openBox<dynamic>(HiveConstants.recentSearchesBox);
    await Hive.openBox<dynamic>(HiveConstants.lastResultsBox);
  }

  Box<dynamic> get _settingsBox => Hive.box<dynamic>(HiveConstants.settingsBox);

  Box<dynamic> get _recentSearchesBox =>
      Hive.box<dynamic>(HiveConstants.recentSearchesBox);

  Box<dynamic> get _lastResultsBox =>
      Hive.box<dynamic>(HiveConstants.lastResultsBox);

  ThemeMode getThemeMode() {
    final String mode =
        _settingsBox.get(
              HiveConstants.themeModeKey,
              defaultValue: ThemeMode.system.name,
            )
            as String;

    return ThemeMode.values.firstWhere(
      (ThemeMode value) => value.name == mode,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _settingsBox.put(HiveConstants.themeModeKey, mode.name);
  }

  AppCurrency getCurrency() {
    final String rawCode =
        _settingsBox.get(
              HiveConstants.currencyCodeKey,
              defaultValue: PriceFormatter.currencyCode(AppCurrency.usd),
            )
            as String;

    return PriceFormatter.parseCurrency(rawCode);
  }

  Future<void> saveCurrency(AppCurrency currency) async {
    await _settingsBox.put(
      HiveConstants.currencyCodeKey,
      PriceFormatter.currencyCode(currency),
    );
  }

  bool getOnboardingCompleted() {
    return _settingsBox.get(
          HiveConstants.onboardingCompletedKey,
          defaultValue: false,
        )
        as bool;
  }

  Future<void> saveOnboardingCompleted(bool isCompleted) async {
    await _settingsBox.put(HiveConstants.onboardingCompletedKey, isCompleted);
  }

  bool getGuestModeEnabled() {
    return _settingsBox.get(HiveConstants.guestModeKey, defaultValue: false)
        as bool;
  }

  Future<void> saveGuestModeEnabled(bool isEnabled) async {
    await _settingsBox.put(HiveConstants.guestModeKey, isEnabled);
  }

  List<FlightSearchQuery> getRecentSearches() {
    final List<dynamic> raw =
        _recentSearchesBox.get(
              HiveConstants.recentSearchesKey,
              defaultValue: <dynamic>[],
            )
            as List<dynamic>? ??
        <dynamic>[];

    return raw
        .map(
          (dynamic item) =>
              FlightSearchQuery.fromMap(item as Map<dynamic, dynamic>),
        )
        .toList();
  }

  Future<void> saveRecentSearch(FlightSearchQuery query) async {
    final List<Map<String, dynamic>> current = getRecentSearches()
        .map((FlightSearchQuery search) => search.toMap())
        .toList();

    current.removeWhere(
      (Map<String, dynamic> item) =>
          item['fromAirport'] == query.fromAirport &&
          item['toAirport'] == query.toAirport &&
          item['date'] == query.date.millisecondsSinceEpoch,
    );

    current.insert(0, query.toMap());
    final List<Map<String, dynamic>> trimmed = current.take(8).toList();

    await _recentSearchesBox.put(HiveConstants.recentSearchesKey, trimmed);
  }

  Future<void> clearRecentSearches() async {
    await _recentSearchesBox.put(HiveConstants.recentSearchesKey, <dynamic>[]);
  }

  List<Flight> getLastSearchResults() {
    final List<dynamic> raw =
        _lastResultsBox.get(
              HiveConstants.lastSearchResultsKey,
              defaultValue: <dynamic>[],
            )
            as List<dynamic>? ??
        <dynamic>[];

    return raw
        .map((dynamic item) => Flight.fromMap(item as Map<dynamic, dynamic>))
        .toList();
  }

  Future<void> saveLastSearchResults(List<Flight> flights) async {
    final List<Map<String, dynamic>> payload = flights
        .map((Flight flight) => flight.toMap())
        .toList();

    await _lastResultsBox.put(HiveConstants.lastSearchResultsKey, payload);
  }
}



