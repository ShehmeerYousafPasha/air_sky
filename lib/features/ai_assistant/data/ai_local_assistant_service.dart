import 'dart:math' as math;

import 'package:air_sky/core/constants/app_constants.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/features/ai_assistant/domain/entities/ai_assistant_models.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';

class AiLocalAssistantService {
  const AiLocalAssistantService();

  static final RegExp _budgetPattern = RegExp(
    r'(?:under|below|within|max(?:imum)?(?:\s+budget)?|budget(?:\s+of)?)\s*\$?\s*([\d,]+(?:\.\d+)?)\s*(k|thousand)?',
    caseSensitive: false,
  );

  static final List<RegExp> _passengerPatterns = <RegExp>[
    RegExp(
      r'\bfor\s+(\d+)\s+(?:passenger|passengers|people|person|traveler|travelers|adult|adults|pax)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(\d+)\s*(?:passenger|passengers|people|person|traveler|travelers|adult|adults|pax)\b',
      caseSensitive: false,
    ),
    RegExp(r'\bfor\s+(\d+)\b', caseSensitive: false),
  ];

  static const Map<String, String> _cityToAirport = <String, String>{
    'islamabad': 'ISB',
    'isb': 'ISB',
    'singapore': 'SIN',
    'sin': 'SIN',
    'dubai': 'DXB',
    'dxb': 'DXB',
    'london': 'LHR',
    'heathrow': 'LHR',
    'lhr': 'LHR',
    'istanbul': 'IST',
    'ist': 'IST',
    'doha': 'DOH',
    'doh': 'DOH',
    'karachi': 'KHI',
    'khi': 'KHI',
    'lahore': 'LHE',
    'lhe': 'LHE',
  };

  static const Set<String> _knownAirportCodes = <String>{
    'ISB',
    'SIN',
    'DXB',
    'LHR',
    'IST',
    'DOH',
    'KHI',
    'LHE',
  };

  static const Map<String, int> _weekdayNames = <String, int>{
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static const Map<String, int> _monthNames = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  static const Map<String, String> _airportDisplayNames = <String, String>{
    'ISB': 'Islamabad',
    'SIN': 'Singapore',
    'DXB': 'Dubai',
    'LHR': 'London',
    'IST': 'Istanbul',
    'DOH': 'Doha',
    'KHI': 'Karachi',
    'LHE': 'Lahore',
  };

  AiParsedIntent parseIntent(String input) {
    final String trimmed = input.trim();
    final String lower = trimmed.toLowerCase();

    final DateTime? date = _extractDate(lower);
    final _BudgetResult budget = _extractBudget(lower);
    final int? passengerCount = _extractPassengerCount(lower);
    final int? selectionIndex = _extractSelectionIndex(lower);

    final _RouteExtraction? routeExtraction = _extractRouteFromText(lower);
    final String? originCode =
        _extractAirportAfterKeyword(lower, keyword: 'from') ??
        routeExtraction?.originCode;
    final String? destinationCode =
        _extractAirportAfterKeyword(lower, keyword: 'to') ??
        routeExtraction?.destinationCode;

    final bool wantsAnywhere =
        lower.contains('anywhere') ||
        lower.contains('any destination') ||
        lower.contains('where can i go') ||
        (destinationCode == null &&
            (lower.contains('weekend trip') ||
                lower.contains('where should') ||
                lower.contains('suggest destination') ||
                lower.contains('trip under')));

    final bool wantsCheapest =
        lower.contains('cheapest') ||
        lower.contains('cheepest') ||
        lower.contains('cheap') ||
        lower.contains('lowest fare') ||
        lower.contains('lowest price');
    final bool wantsFastest =
        lower.contains('fastest') ||
        lower.contains('faster') ||
        lower.contains('fast route') ||
        lower.contains('quickest') ||
        lower.contains('shortest');
    final bool wantsBest =
        lower.contains('best') ||
        lower.contains('recommended') ||
        lower.contains('best value');
    final bool wantsDirectOnly =
        _hasAnyPhrase(lower, const <String>[
          'non stop',
          'non-stop',
          'direct flight',
          'direct only',
          'without stop',
          'zero stop',
        ]) ||
        lower.contains('nonstop');
    final int? maxStops = _extractMaxStops(
      lower,
      directPreference: wantsDirectOnly,
    );

    final bool prefersMorningDeparture = _hasAnyPhrase(lower, const <String>[
      'morning flight',
      'morning flights',
      'early morning',
      'in the morning',
      'morning departure',
    ]);
    final bool prefersEveningDeparture = _hasAnyPhrase(lower, const <String>[
      'evening flight',
      'evening flights',
      'night flight',
      'night flights',
      'late night',
      'in the evening',
      'tonight',
    ]);

    final bool wantsDetails =
        lower.contains('details') ||
        lower.contains('open details') ||
        lower.contains('show details');
    final bool wantsBooking =
        lower.contains('booking') ||
        lower.contains('book this') ||
        lower.contains('proceed to booking') ||
        lower.contains('go to booking');

    final bool wantsPriceRadar =
        lower.contains('price radar') ||
        lower.contains('fare radar') ||
        lower.contains('price trend') ||
        lower.contains('price forecast');
    final bool wantsPackingTips =
        lower.contains('packing') || lower.contains('what should i pack');
    final bool wantsVisaTips =
        lower.contains('visa') || lower.contains('entry requirement');
    final bool wantsTripChecklist =
        lower.contains('checklist') || lower.contains('trip prep');
    final bool wantsCompareOptions =
        lower.contains('compare') ||
        lower.contains('difference between') ||
        lower.contains('cheapest vs fastest');
    final bool wantsSurpriseDestination =
        lower.contains('surprise me') || lower.contains('random destination');
    final bool wantsCheapestBookedFlight =
        (lower.contains('cheapest') || lower.contains('lowest')) &&
        (lower.contains('booking') ||
            lower.contains('bookings') ||
            lower.contains('booked') ||
            lower.contains('my trips') ||
            lower.contains('my trip') ||
            lower.contains('all bookings'));

    final bool refersToPreviousResults =
        _hasAnyPhrase(lower, const <String>[
          'this one',
          'that one',
          'these options',
          'those options',
          'these flights',
          'those flights',
          'these results',
          'those results',
          'same route',
          'same trip',
          'same date',
          'same search',
        ]) ||
        (selectionIndex != null &&
            originCode == null &&
            destinationCode == null &&
            date == null);

    final bool hasSearchContext =
        originCode != null ||
        destinationCode != null ||
        date != null ||
        budget.maxBudgetUsd != null ||
        passengerCount != null;

    final bool wantsResults =
        lower.contains('results') ||
        lower.contains('show flights') ||
        lower.contains('show me') ||
        lower.contains('open flights') ||
        lower.contains('open results') ||
        lower.contains('take me to') ||
        lower.contains('find flight') ||
        lower.contains('find me') ||
        lower.contains('search') ||
        lower.contains('i need a flight') ||
        lower.contains('i want a flight') ||
        lower.contains('i want to fly') ||
        lower.contains('fly me to') ||
        lower.contains('travel to') ||
        (hasSearchContext &&
            _containsAny(lower, <String>[
              'flight',
              'flights',
              'fare',
              'ticket',
            ]));

    return AiParsedIntent(
      rawInput: trimmed,
      originCode: originCode,
      destinationCode: destinationCode,
      travelDate: date,
      maxBudgetUsd: budget.maxBudgetUsd,
      budgetFromPkr: budget.budgetFromPkr,
      passengerCount: passengerCount,
      wantsAnywhereSearch: wantsAnywhere,
      wantsCheapest: wantsCheapest,
      wantsFastest: wantsFastest,
      wantsBestOption: wantsBest,
      wantsResults: wantsResults,
      wantsFlightDetails: wantsDetails,
      wantsBooking: wantsBooking,
      wantsPriceRadar: wantsPriceRadar,
      wantsPackingTips: wantsPackingTips,
      wantsVisaTips: wantsVisaTips,
      wantsTripChecklist: wantsTripChecklist,
      wantsCompareOptions: wantsCompareOptions,
      wantsSurpriseDestination: wantsSurpriseDestination,
      wantsCheapestBookedFlight: wantsCheapestBookedFlight,
      maxStops: maxStops,
      prefersMorningDeparture: prefersMorningDeparture,
      prefersEveningDeparture: prefersEveningDeparture,
      refersToPreviousResults: refersToPreviousResults,
      selectionIndex: selectionIndex,
    );
  }

  String buildFareRadar({
    required List<Flight> flights,
    required DateTime travelDate,
  }) {
    if (flights.isEmpty) {
      return 'Fare Radar: I need a fresh flight search before I can estimate the trend.';
    }

    final double minPrice = flights.map((Flight f) => f.price).reduce(math.min);
    final double maxPrice = flights.map((Flight f) => f.price).reduce(math.max);
    final double avgPrice =
        flights
            .map((Flight f) => f.price)
            .reduce((double a, double b) => a + b) /
        flights.length;

    final String pressure = _pricePressure(travelDate);
    return 'Fare Radar: current market is around ${PriceFormatter.format(avgPrice)} (range ${PriceFormatter.format(minPrice)}-${PriceFormatter.format(maxPrice)}). $pressure';
  }

  String buildPackingTips({
    required String toAirport,
    required String cabinClass,
  }) {
    final String destination =
        _airportDisplayNames[toAirport.toUpperCase()] ??
        toAirport.toUpperCase();

    final String climateAdvice;
    switch (toAirport.toUpperCase()) {
      case 'DXB':
      case 'DOH':
        climateAdvice =
            'Pack breathable clothes, sunscreen, and a refillable water bottle.';
        break;
      case 'LHR':
        climateAdvice =
            'Bring a light rain jacket, comfortable layers, and an adapter.';
        break;
      case 'IST':
        climateAdvice =
            'Pack mixed layers and comfortable walking shoes for long city days.';
        break;
      default:
        climateAdvice =
            'Pack flexible layers so you can adjust quickly during transit.';
    }

    final String cabinAdvice = cabinClass.toLowerCase() == 'economy'
        ? 'For Economy, keep neck pillow, hydration, and a light hoodie in cabin baggage.'
        : 'For premium cabins, keep documents and essentials in a small personal bag for quick boarding.';

    return 'Pack Smart for $destination: $climateAdvice $cabinAdvice';
  }

  String buildVisaTips({required String toAirport}) {
    final String destination =
        _airportDisplayNames[toAirport.toUpperCase()] ??
        toAirport.toUpperCase();

    return 'Visa Assistant for $destination: check passport validity (at least 6 months), destination visa policy, return ticket, and accommodation proof before travel. Always verify with the official embassy source before booking.';
  }

  String buildTripChecklist({
    required String fromAirport,
    required String toAirport,
    required DateTime travelDate,
  }) {
    final String origin =
        _airportDisplayNames[fromAirport.toUpperCase()] ??
        fromAirport.toUpperCase();
    final String destination =
        _airportDisplayNames[toAirport.toUpperCase()] ??
        toAirport.toUpperCase();

    return 'Trip Checklist for $origin to $destination (${travelDate.toShortDate()}): 1) Passport and visa docs ready. 2) Check-in reminder set for 24h before departure. 3) Transfer and hotel confirmations saved offline. 4) Emergency contact and insurance details available. 5) Final booking confirmation remains manual in AirSky.';
  }

  String buildRouteComparison({
    required List<Flight> flights,
    required AiFlightRecommendations recommendations,
  }) {
    if (flights.isEmpty) {
      return 'I need flight options first, then I can compare cheapest, fastest, and best value for you.';
    }

    Flight? cheapest;
    Flight? fastest;
    Flight? bestValue;
    for (final Flight flight in flights) {
      if (flight.id == recommendations.cheapestFlightId) {
        cheapest = flight;
      }
      if (flight.id == recommendations.fastestFlightId) {
        fastest = flight;
      }
      if (flight.id == recommendations.bestValueFlightId) {
        bestValue = flight;
      }
    }

    cheapest ??= flights.first;
    fastest ??= flights.first;
    bestValue ??= flights.first;

    return 'Route Compare: Cheapest is ${cheapest.airline} at ${PriceFormatter.format(cheapest.price)}. Fastest is ${fastest.airline} at ${fastest.durationLabel}. Best Value is ${bestValue.airline} at ${PriceFormatter.format(bestValue.price)} with ${bestValue.stopsLabel}.';
  }

  String buildDestinationSpotlight(String toAirport) {
    switch (toAirport.toUpperCase()) {
      case 'DXB':
        return 'Destination Spotlight: Dubai is great for short city breaks, desert evenings, and indoor attractions.';
      case 'IST':
        return 'Destination Spotlight: Istanbul blends history and food culture, ideal for 3-5 day exploration.';
      case 'DOH':
        return 'Destination Spotlight: Doha is compact and modern, with excellent museums and waterfront walks.';
      case 'LHR':
        return 'Destination Spotlight: London works best when you pre-book key attractions and transport cards.';
      default:
        return 'Destination Spotlight: this route is a good fit for a flexible trip with light planning.';
    }
  }

  List<String> destinationCandidates({required String origin}) {
    final Set<String> base = <String>{...AppConstants.airports, 'LHE'};
    base.remove(origin.toUpperCase());
    return base.toList()..sort();
  }

  List<Flight> applyBudgetFilter(List<Flight> flights, double? maxBudgetUsd) {
    if (maxBudgetUsd == null) {
      return flights;
    }

    return flights.where((Flight f) => f.price <= maxBudgetUsd).toList();
  }

  bool hasPreferenceFilters(AiParsedIntent intent) {
    return intent.maxStops != null ||
        intent.prefersMorningDeparture ||
        intent.prefersEveningDeparture;
  }

  String preferenceSummary(AiParsedIntent intent) {
    final List<String> parts = <String>[];
    if (intent.maxStops != null) {
      if (intent.maxStops == 0) {
        parts.add('non-stop');
      } else {
        parts.add(
          'up to ${intent.maxStops} stop${intent.maxStops == 1 ? '' : 's'}',
        );
      }
    }

    if (intent.prefersMorningDeparture && intent.prefersEveningDeparture) {
      parts.add('morning or evening departure');
    } else if (intent.prefersMorningDeparture) {
      parts.add('morning departure');
    } else if (intent.prefersEveningDeparture) {
      parts.add('evening departure');
    }

    return parts.join(', ');
  }

  List<Flight> applyPreferenceFilter(
    List<Flight> flights, {
    required AiParsedIntent intent,
  }) {
    if (!hasPreferenceFilters(intent)) {
      return flights;
    }

    return flights.where((Flight flight) {
      if (intent.maxStops != null && flight.stops > intent.maxStops!) {
        return false;
      }

      if (!_matchesDeparturePreference(flight, intent)) {
        return false;
      }

      return true;
    }).toList();
  }

  AiFlightRecommendations buildRecommendations({
    required List<Flight> flights,
    required AiParsedIntent intent,
    required DateTime travelDate,
    required String fromAirport,
    required String toAirport,
    List<Flight> historicalFlights = const <Flight>[],
  }) {
    final Flight cheapest = flights.reduce(
      (Flight a, Flight b) => a.price <= b.price ? a : b,
    );
    final Flight fastest = flights.reduce(
      (Flight a, Flight b) => a.durationMinutes <= b.durationMinutes ? a : b,
    );
    final Flight bestValue = _bestValueFlight(flights);

    late Flight recommended;
    late String recommendedReason;

    if (intent.wantsFastest) {
      recommended = fastest;
      recommendedReason = 'Fastest overall route';
    } else if (intent.wantsCheapest) {
      recommended = cheapest;
      recommendedReason = 'Lowest available fare';
    } else {
      recommended = bestValue;
      recommendedReason = 'Best value across price, time, and stops';

      final _UserTravelProfile profile = _buildUserTravelProfile(
        historicalFlights,
      );
      if (!profile.isEmpty) {
        final List<_ScoredFlight> rankedByProfile =
            flights
                .map(
                  (Flight flight) => _ScoredFlight(
                    flight: flight,
                    score: _profileMatchScore(flight, profile),
                  ),
                )
                .toList(growable: false)
              ..sort((_ScoredFlight a, _ScoredFlight b) {
                final int scoreOrder = b.score.compareTo(a.score);
                if (scoreOrder != 0) {
                  return scoreOrder;
                }
                return a.flight.price.compareTo(b.flight.price);
              });

        if (rankedByProfile.isNotEmpty && rankedByProfile.first.score > 0) {
          final double topScore = rankedByProfile.first.score;
          final List<Flight> topMatches = rankedByProfile
              .where(
                (_ScoredFlight value) =>
                    (topScore - value.score).abs() < 0.0001,
              )
              .map((_ScoredFlight value) => value.flight)
              .toList(growable: false);
          recommended = _bestValueFlight(topMatches);
          recommendedReason = _buildPersonalizedReason(recommended, profile);
        }
      }
    }

    return AiFlightRecommendations(
      recommendedFlightId: recommended.id,
      recommendedReason: recommendedReason,
      cheapestFlightId: cheapest.id,
      fastestFlightId: fastest.id,
      bestValueFlightId: bestValue.id,
      routeInsight: _routeInsight(fromAirport, toAirport),
      timingSuggestion: _timingSuggestion(travelDate),
    );
  }

  String? codeForCityOrAirportToken(String token) {
    final String cleaned = token.trim().toLowerCase();
    if (cleaned.isEmpty) {
      return null;
    }

    if (_cityToAirport.containsKey(cleaned)) {
      return _cityToAirport[cleaned];
    }

    final String maybeCode = token.trim().toUpperCase();
    if (RegExp(r'^[A-Z]{3}$').hasMatch(maybeCode) &&
        _knownAirportCodes.contains(maybeCode)) {
      return maybeCode;
    }

    return null;
  }

  String _routeInsight(String fromAirport, String toAirport) {
    final Set<String> popularRoutes = <String>{
      'ISB-DXB',
      'ISB-DOH',
      'ISB-IST',
      'LHE-IST',
      'KHI-DXB',
    };

    final List<String> sorted = <String>[fromAirport, toAirport]..sort();
    final String route = '${sorted.first}-${sorted.last}';
    if (popularRoutes.contains(route)) {
      return 'This route is popular this week.';
    }

    return 'Fares on this route can change quickly through the week.';
  }

  String _timingSuggestion(DateTime travelDate) {
    const Set<int> weekendDays = <int>{
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    };

    if (weekendDays.contains(travelDate.weekday)) {
      return 'Try flying Tuesday for potentially lower prices.';
    }

    if (travelDate.weekday == DateTime.tuesday) {
      return 'Tuesday departures are often among lower-fare options.';
    }

    return 'Booking a few days earlier can improve your fare options.';
  }

  String _pricePressure(DateTime travelDate) {
    if (travelDate.weekday == DateTime.friday ||
        travelDate.weekday == DateTime.saturday ||
        travelDate.weekday == DateTime.sunday) {
      return 'Weekend demand is usually higher, so prices may rise faster.';
    }
    if (travelDate.weekday == DateTime.tuesday) {
      return 'Tuesday departures are often more stable in pricing.';
    }
    return 'This date has moderate demand pressure; monitoring daily is recommended.';
  }

  bool _matchesDeparturePreference(Flight flight, AiParsedIntent intent) {
    if (!intent.prefersMorningDeparture && !intent.prefersEveningDeparture) {
      return true;
    }

    if (intent.prefersMorningDeparture && intent.prefersEveningDeparture) {
      return true;
    }

    final int hour = flight.departureTime.hour;
    if (intent.prefersMorningDeparture) {
      return hour >= 5 && hour < 12;
    }
    if (intent.prefersEveningDeparture) {
      return hour >= 17 || hour < 1;
    }

    return true;
  }

  _UserTravelProfile _buildUserTravelProfile(List<Flight> historicalFlights) {
    if (historicalFlights.isEmpty) {
      return const _UserTravelProfile();
    }

    final Map<String, int> airlineCounts = <String, int>{};
    final Map<String, int> cabinCounts = <String, int>{};
    final Map<String, int> destinationCounts = <String, int>{};
    final Map<_DepartureBucket, int> departureBucketCounts =
        <_DepartureBucket, int>{};

    for (final Flight flight in historicalFlights) {
      airlineCounts.update(
        flight.airline,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
      cabinCounts.update(
        flight.cabinClass,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
      destinationCounts.update(
        flight.toAirport,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );

      final _DepartureBucket bucket = _departureBucketFor(
        flight.departureTime.hour,
      );
      departureBucketCounts.update(
        bucket,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return _UserTravelProfile(
      preferredAirline: _mostFrequentString(airlineCounts),
      preferredCabinClass: _mostFrequentString(cabinCounts),
      preferredDestination: _mostFrequentString(destinationCounts),
      preferredDepartureBucket: _mostFrequentBucket(departureBucketCounts),
    );
  }

  double _profileMatchScore(Flight flight, _UserTravelProfile profile) {
    double score = 0;

    if (profile.preferredAirline != null &&
        flight.airline == profile.preferredAirline) {
      score += 1.6;
    }

    if (profile.preferredCabinClass != null &&
        flight.cabinClass == profile.preferredCabinClass) {
      score += 1.0;
    }

    if (profile.preferredDestination != null &&
        flight.toAirport == profile.preferredDestination) {
      score += 1.2;
    }

    if (profile.preferredDepartureBucket != null &&
        _departureBucketFor(flight.departureTime.hour) ==
            profile.preferredDepartureBucket) {
      score += 0.8;
    }

    return score;
  }

  String _buildPersonalizedReason(
    Flight recommended,
    _UserTravelProfile profile,
  ) {
    final List<String> reasons = <String>[];

    if (profile.preferredAirline != null &&
        recommended.airline == profile.preferredAirline) {
      reasons.add('matches your frequent airline preference');
    }
    if (profile.preferredDestination != null &&
        recommended.toAirport == profile.preferredDestination) {
      reasons.add('aligns with your usual destinations');
    }
    if (profile.preferredDepartureBucket != null &&
        _departureBucketFor(recommended.departureTime.hour) ==
            profile.preferredDepartureBucket) {
      reasons.add('fits your common departure timing');
    }

    if (reasons.isEmpty) {
      return 'Best value across price, time, and stops';
    }

    return 'Personalized best value that ${reasons.first}';
  }

  _DepartureBucket _departureBucketFor(int hour) {
    if (hour >= 5 && hour < 12) {
      return _DepartureBucket.morning;
    }
    if (hour >= 17 || hour < 1) {
      return _DepartureBucket.evening;
    }
    return _DepartureBucket.daytime;
  }

  String? _mostFrequentString(Map<String, int> counts) {
    if (counts.isEmpty) {
      return null;
    }

    String? bestKey;
    int bestValue = -1;
    counts.forEach((String key, int value) {
      if (value > bestValue) {
        bestKey = key;
        bestValue = value;
      }
    });
    return bestKey;
  }

  _DepartureBucket? _mostFrequentBucket(Map<_DepartureBucket, int> counts) {
    if (counts.isEmpty) {
      return null;
    }

    _DepartureBucket? bestKey;
    int bestValue = -1;
    counts.forEach((_DepartureBucket key, int value) {
      if (value > bestValue) {
        bestKey = key;
        bestValue = value;
      }
    });
    return bestKey;
  }

  Flight _bestValueFlight(List<Flight> flights) {
    final double minPrice = flights.map((Flight f) => f.price).reduce(math.min);
    final double maxPrice = flights.map((Flight f) => f.price).reduce(math.max);
    final int minDuration = flights
        .map((Flight f) => f.durationMinutes)
        .reduce(math.min);
    final int maxDuration = flights
        .map((Flight f) => f.durationMinutes)
        .reduce(math.max);

    double score(Flight flight) {
      final double priceRange = maxPrice - minPrice;
      final double durationRange = (maxDuration - minDuration).toDouble();

      final double priceNorm = priceRange == 0
          ? 0
          : (flight.price - minPrice) / priceRange;
      final double durationNorm = durationRange == 0
          ? 0
          : (flight.durationMinutes - minDuration) / durationRange;
      final double stopPenalty = flight.stops / 2;

      return (priceNorm * 0.6) + (durationNorm * 0.3) + (stopPenalty * 0.1);
    }

    return flights.reduce((Flight a, Flight b) => score(a) <= score(b) ? a : b);
  }

  int? _extractPassengerCount(String lowerInput) {
    for (final RegExp pattern in _passengerPatterns) {
      final Match? match = pattern.firstMatch(lowerInput);
      if (match == null) {
        continue;
      }

      final int? value = int.tryParse(match.group(1) ?? '');
      if (value == null) {
        continue;
      }

      return value.clamp(1, 9);
    }

    return null;
  }

  int? _extractMaxStops(String lowerInput, {required bool directPreference}) {
    if (directPreference) {
      return 0;
    }

    final Match? stopMatch = RegExp(
      r'\b(\d+)\s*stop(?:s)?\b',
    ).firstMatch(lowerInput);
    final int? parsedStops = int.tryParse(stopMatch?.group(1) ?? '');
    if (parsedStops != null) {
      return parsedStops.clamp(0, 3);
    }

    if (_hasAnyPhrase(lowerInput, const <String>['non stop', 'non-stop']) ||
        lowerInput.contains('nonstop')) {
      return 0;
    }

    return null;
  }

  int? _extractSelectionIndex(String lowerInput) {
    if (lowerInput.contains('first') || lowerInput.contains('1st')) {
      return 0;
    }
    if (lowerInput.contains('second') || lowerInput.contains('2nd')) {
      return 1;
    }
    if (lowerInput.contains('third') || lowerInput.contains('3rd')) {
      return 2;
    }

    final RegExp flightIndexPattern = RegExp(r'\bflight\s*(\d+)\b');
    final Match? match = flightIndexPattern.firstMatch(lowerInput);
    final int? parsed = int.tryParse(match?.group(1) ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed - 1;
  }

  DateTime? _extractDate(String lowerInput) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    if (lowerInput.contains('today')) {
      return today;
    }

    if (lowerInput.contains('tomorrow')) {
      return today.add(const Duration(days: 1));
    }

    if (lowerInput.contains('weekend')) {
      return _nextWeekday(today, DateTime.saturday);
    }

    if (lowerInput.contains('next week')) {
      final DateTime nextMonday = _nextWeekday(today, DateTime.monday);
      return nextMonday;
    }

    final Match? relativeWeekdayMatch = RegExp(
      r'\b(next|this)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
      caseSensitive: false,
    ).firstMatch(lowerInput);
    if (relativeWeekdayMatch != null) {
      final String modifier = (relativeWeekdayMatch.group(1) ?? '')
          .trim()
          .toLowerCase();
      final String weekdayName = (relativeWeekdayMatch.group(2) ?? '')
          .trim()
          .toLowerCase();
      final int? weekday = _weekdayNames[weekdayName];
      if (weekday != null) {
        return _resolveWeekdayDate(
          today,
          weekday,
          forceNext: modifier == 'next',
        );
      }
    }

    final Match? numericDateMatch = RegExp(
      r'\b(\d{1,2})[\/-](\d{1,2})(?:[\/-](\d{2,4}))?\b',
    ).firstMatch(lowerInput);
    if (numericDateMatch != null) {
      final int? day = int.tryParse(numericDateMatch.group(1) ?? '');
      final int? month = int.tryParse(numericDateMatch.group(2) ?? '');
      if (day != null && month != null) {
        int year = int.tryParse(numericDateMatch.group(3) ?? '') ?? today.year;
        if (year < 100) {
          year += 2000;
        }

        final DateTime? candidate = _safeDate(year, month, day);
        if (candidate != null) {
          if (numericDateMatch.group(3) == null && candidate.isBefore(today)) {
            return _safeDate(year + 1, month, day);
          }
          return candidate;
        }
      }
    }

    final Match? dayMonthWordMatch = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3,9})(?:\s+(\d{2,4}))?\b',
      caseSensitive: false,
    ).firstMatch(lowerInput);
    if (dayMonthWordMatch != null) {
      final int? day = int.tryParse(dayMonthWordMatch.group(1) ?? '');
      final String monthToken = (dayMonthWordMatch.group(2) ?? '')
          .trim()
          .toLowerCase();
      final int? month = _monthNames[monthToken];
      if (day != null && month != null) {
        int year = int.tryParse(dayMonthWordMatch.group(3) ?? '') ?? today.year;
        if (year < 100) {
          year += 2000;
        }

        final DateTime? candidate = _safeDate(year, month, day);
        if (candidate != null) {
          if (dayMonthWordMatch.group(3) == null && candidate.isBefore(today)) {
            return _safeDate(year + 1, month, day);
          }
          return candidate;
        }
      }
    }

    final Match? monthWordDayMatch = RegExp(
      r'\b([a-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s+(\d{2,4}))?\b',
      caseSensitive: false,
    ).firstMatch(lowerInput);
    if (monthWordDayMatch != null) {
      final String monthToken = (monthWordDayMatch.group(1) ?? '')
          .trim()
          .toLowerCase();
      final int? month = _monthNames[monthToken];
      final int? day = int.tryParse(monthWordDayMatch.group(2) ?? '');
      if (month != null && day != null) {
        int year = int.tryParse(monthWordDayMatch.group(3) ?? '') ?? today.year;
        if (year < 100) {
          year += 2000;
        }

        final DateTime? candidate = _safeDate(year, month, day);
        if (candidate != null) {
          if (monthWordDayMatch.group(3) == null && candidate.isBefore(today)) {
            return _safeDate(year + 1, month, day);
          }
          return candidate;
        }
      }
    }

    return null;
  }

  DateTime _resolveWeekdayDate(
    DateTime from,
    int targetWeekday, {
    required bool forceNext,
  }) {
    int daysAhead = targetWeekday - from.weekday;
    if (forceNext) {
      if (daysAhead <= 0) {
        daysAhead += 7;
      }
    } else if (daysAhead < 0) {
      daysAhead += 7;
    }
    return from.add(Duration(days: daysAhead));
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final DateTime candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }

    return candidate;
  }

  DateTime _nextWeekday(DateTime from, int targetWeekday) {
    int daysAhead = targetWeekday - from.weekday;
    if (daysAhead <= 0) {
      daysAhead += 7;
    }
    return from.add(Duration(days: daysAhead));
  }

  String? _extractAirportAfterKeyword(
    String lowerInput, {
    required String keyword,
  }) {
    final RegExp pattern = RegExp(
      '\\b$keyword\\s+([a-z]{3,}(?:\\s+[a-z]{2,})?)',
      caseSensitive: false,
    );
    final Match? match = pattern.firstMatch(lowerInput);
    if (match == null) {
      return null;
    }

    final String raw = (match.group(1) ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    final List<String> tokens = raw
        .split(RegExp(r'\s+'))
        .where((String token) => token.trim().isNotEmpty)
        .toList();

    final String? mappedRaw = _cityToAirport[raw];
    if (mappedRaw != null) {
      return mappedRaw;
    }

    if (tokens.isNotEmpty) {
      final String? mappedFirst = _cityToAirport[tokens.first];
      if (mappedFirst != null) {
        return mappedFirst;
      }

      for (final String token in tokens) {
        final String? mappedToken = _cityToAirport[token];
        if (mappedToken != null) {
          return mappedToken;
        }
      }
    }

    final String upperRaw = raw.toUpperCase();
    if (RegExp(r'^[A-Z]{3}$').hasMatch(upperRaw) &&
        _knownAirportCodes.contains(upperRaw)) {
      return upperRaw;
    }

    return null;
  }

  _RouteExtraction? _extractRouteFromText(String lowerInput) {
    final List<_LocatedAirportCode> locatedCodes = <_LocatedAirportCode>[];

    for (final MapEntry<String, String> entry in _cityToAirport.entries) {
      final RegExp aliasPattern = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      );
      for (final Match match in aliasPattern.allMatches(lowerInput)) {
        locatedCodes.add(
          _LocatedAirportCode(index: match.start, code: entry.value),
        );
      }
    }

    final RegExp codePattern = RegExp(r'\b([a-z]{3})\b', caseSensitive: false);
    for (final Match match in codePattern.allMatches(lowerInput)) {
      final String token = (match.group(1) ?? '').trim().toUpperCase();
      if (_knownAirportCodes.contains(token)) {
        locatedCodes.add(_LocatedAirportCode(index: match.start, code: token));
      }
    }

    if (locatedCodes.isEmpty) {
      return null;
    }

    locatedCodes.sort(
      (_LocatedAirportCode a, _LocatedAirportCode b) =>
          a.index.compareTo(b.index),
    );

    String? originCode;
    String? destinationCode;
    for (final _LocatedAirportCode item in locatedCodes) {
      if (originCode == null) {
        originCode = item.code;
        continue;
      }
      if (item.code != originCode) {
        destinationCode = item.code;
        break;
      }
    }

    if (originCode == null || destinationCode == null) {
      return null;
    }

    return _RouteExtraction(
      originCode: originCode,
      destinationCode: destinationCode,
    );
  }

  bool _containsAny(String input, List<String> needles) {
    for (final String needle in needles) {
      if (input.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  bool _hasAnyPhrase(String input, List<String> phrases) {
    for (final String phrase in phrases) {
      if (_hasPhrase(input, phrase)) {
        return true;
      }
    }
    return false;
  }

  bool _hasPhrase(String input, String phrase) {
    final String pattern = RegExp.escape(phrase).replaceAll(r'\ ', r'\s+');
    return RegExp('\\b$pattern\\b', caseSensitive: false).hasMatch(input);
  }

  _BudgetResult _extractBudget(String lowerInput) {
    final Match? budgetMatch = _budgetPattern.firstMatch(lowerInput);
    if (budgetMatch == null) {
      return const _BudgetResult();
    }

    final String amountText = (budgetMatch.group(1) ?? '').replaceAll(',', '');
    final double? rawAmount = double.tryParse(amountText);
    if (rawAmount == null) {
      return const _BudgetResult();
    }

    final String suffix = (budgetMatch.group(2) ?? '').toLowerCase();
    double amount = rawAmount;
    if (suffix == 'k' || suffix == 'thousand') {
      amount *= 1000;
    }

    final AppCurrency? explicitCurrency = _extractExplicitBudgetCurrency(
      lowerInput,
    );
    if (explicitCurrency != null) {
      return _BudgetResult(
        maxBudgetUsd: PriceFormatter.convertToUsd(
          amount,
          fromCurrency: explicitCurrency,
        ),
        budgetFromPkr: explicitCurrency == AppCurrency.pkr,
      );
    }

    final AppCurrency preferredCurrency = PriceFormatter.selectedCurrency;
    if (preferredCurrency != AppCurrency.usd) {
      return _BudgetResult(
        maxBudgetUsd: PriceFormatter.convertToUsd(
          amount,
          fromCurrency: preferredCurrency,
        ),
        budgetFromPkr: preferredCurrency == AppCurrency.pkr,
      );
    }

    final bool likelyPkr = amount > 1500;

    if (likelyPkr) {
      return _BudgetResult(maxBudgetUsd: amount / 280, budgetFromPkr: true);
    }

    return _BudgetResult(maxBudgetUsd: amount, budgetFromPkr: false);
  }

  AppCurrency? _extractExplicitBudgetCurrency(String lowerInput) {
    if (lowerInput.contains(r'$') ||
        lowerInput.contains('usd') ||
        lowerInput.contains('dollar')) {
      return AppCurrency.usd;
    }

    if (RegExp(r'\bpkr\b').hasMatch(lowerInput) ||
        RegExp(r'\brs\b').hasMatch(lowerInput) ||
        lowerInput.contains('rupee')) {
      return AppCurrency.pkr;
    }

    if (RegExp(r'\beur\b').hasMatch(lowerInput) ||
        lowerInput.contains('euro')) {
      return AppCurrency.eur;
    }

    if (RegExp(r'\bgbp\b').hasMatch(lowerInput) ||
        lowerInput.contains('pound')) {
      return AppCurrency.gbp;
    }

    if (RegExp(r'\baed\b').hasMatch(lowerInput) ||
        lowerInput.contains('dirham')) {
      return AppCurrency.aed;
    }

    return null;
  }
}

class _BudgetResult {
  const _BudgetResult({this.maxBudgetUsd, this.budgetFromPkr = false});

  final double? maxBudgetUsd;
  final bool budgetFromPkr;
}

class _UserTravelProfile {
  const _UserTravelProfile({
    this.preferredAirline,
    this.preferredCabinClass,
    this.preferredDestination,
    this.preferredDepartureBucket,
  });

  final String? preferredAirline;
  final String? preferredCabinClass;
  final String? preferredDestination;
  final _DepartureBucket? preferredDepartureBucket;

  bool get isEmpty =>
      preferredAirline == null &&
      preferredCabinClass == null &&
      preferredDestination == null &&
      preferredDepartureBucket == null;
}

class _ScoredFlight {
  const _ScoredFlight({required this.flight, required this.score});

  final Flight flight;
  final double score;
}

enum _DepartureBucket { morning, daytime, evening }

class _RouteExtraction {
  const _RouteExtraction({
    required this.originCode,
    required this.destinationCode,
  });

  final String originCode;
  final String destinationCode;
}

class _LocatedAirportCode {
  const _LocatedAirportCode({required this.index, required this.code});

  final int index;
  final String code;
}
