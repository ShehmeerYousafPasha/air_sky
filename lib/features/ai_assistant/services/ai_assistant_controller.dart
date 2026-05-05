import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/utils/date_time_utils.dart';
import 'package:air_sky/utils/price_formatter.dart';
import 'package:air_sky/features/ai_assistant/services/ai_local_assistant_service.dart';
import 'package:air_sky/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:air_sky/features/booking/services/booking_repository.dart';
import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';
import 'package:air_sky/features/flights/services/flight_repository.dart';
import 'package:air_sky/features/flights/services/search_form_controller.dart';

class AiAssistantController extends StateNotifier<AiAssistantState> {
  AiAssistantController(
    this._flightRepository,
    this._assistant,
    this._bookingRepository,
  ) : super(AiAssistantState.initial()) {
    _resetConversation();
  }

  final FlightRepository _flightRepository;
  final AiLocalAssistantService _assistant;
  final BookingRepository _bookingRepository;

  int _messageSeed = 0;
  int _actionSeed = 0;
  static const int _surpriseHistoryLimit = 5;
  final List<String> _recentSurpriseDestinations = <String>[];

  void clearChat() {
    _resetConversation();
  }

  Future<void> handleUserPrompt({
    required String prompt,
    required SearchFormState currentSearchForm,
    required String? currentUserId,
  }) async {
    final String cleanedPrompt = prompt.trim();
    if (cleanedPrompt.isEmpty) {
      return;
    }

    _appendMessage(
      AiChatMessage(
        id: _nextMessageId(),
        role: AiChatRole.user,
        text: cleanedPrompt,
        createdAt: DateTime.now(),
      ),
    );

    state = state.copyWith(isWorking: true, clearPendingNavigation: true);

    final AiParsedIntent intent = _assistant.parseIntent(cleanedPrompt);
    final SearchFormState contextualSearchForm = _resolveSearchContextForm(
      intent: intent,
      currentSearchForm: currentSearchForm,
    );

    try {
      if (intent.wantsCheapestBookedFlight) {
        await _handleCheapestBookedFlightPrompt(currentUserId: currentUserId);
        return;
      }

      if ((intent.wantsFlightDetails || intent.wantsBooking) &&
          state.lastFlights.isNotEmpty) {
        _handleNavigationPrompt(intent: intent);
        return;
      }

      if ((intent.wantsFlightDetails || intent.wantsBooking) &&
          state.lastFlights.isEmpty) {
        _appendAssistantReply(
          'Search flights first, then I can open details or booking for the option you choose.',
        );
        state = state.copyWith(isWorking: false, clearPendingNavigation: true);
        return;
      }

      final _UtilityPromptResult utilityResult = _handleUtilityPrompt(
        intent: intent,
      );
      if (utilityResult == _UtilityPromptResult.stop) {
        return;
      }

      if (!_shouldRunSearch(intent)) {
        _appendAssistantReply(_buildClarifyingReply(cleanedPrompt));
        state = state.copyWith(isWorking: false, clearPendingNavigation: true);
        return;
      }

      final _ResolvedSearch resolved = await _resolveSearch(
        intent: intent,
        currentSearchForm: contextualSearchForm,
      );

      final List<Flight> rawFlights =
          resolved.preloadedFlights ??
          await _flightRepository.searchFlights(resolved.query);
      final List<Flight> budgetFilteredFlights = _assistant.applyBudgetFilter(
        rawFlights,
        intent.maxBudgetUsd,
      );
      final bool hasBudget = intent.maxBudgetUsd != null;
      final List<Flight> budgetEffectiveFlights = hasBudget
          ? budgetFilteredFlights
          : rawFlights;

      if (budgetEffectiveFlights.isEmpty) {
        final bool canShowCheapestAction =
            intent.maxBudgetUsd != null && rawFlights.isNotEmpty;
        final String cheapestActionLabel = _cheapestActionLabelForDate(
          resolved.query.date,
        );
        final FlightSearchQuery cheapestActionQuery =
            canShowCheapestAction && _isWeekendDate(resolved.query.date)
            ? await _resolveCheapestWeekendQuery(baseQuery: resolved.query)
            : resolved.query;
        final String noFlightReply = _buildNoFlightReply(
          query: resolved.query,
          budgetUsd: intent.maxBudgetUsd,
          budgetFromPkr: intent.budgetFromPkr,
          rawFlights: rawFlights,
          canShowCheapestAction: canShowCheapestAction,
          cheapestActionLabel: cheapestActionLabel,
        );
        _appendAssistantReply(noFlightReply);

        final AiNavigationAction? action = canShowCheapestAction
            ? AiNavigationAction(
                id: _nextActionId(),
                target: AiNavigationTarget.results,
                query: cheapestActionQuery,
                maxBudgetUsd: null,
                forceCheapestSort: true,
                requiresConfirmation: true,
                confirmationLabel: cheapestActionLabel,
              )
            : null;

        state = state.copyWith(
          isWorking: false,
          pendingNavigation: action,
          clearPendingNavigation: action == null,
          lastQuery: resolved.query,
          lastFlights: rawFlights,
          clearRecommendations: true,
        );
        return;
      }

      final bool hasPreferenceFilters = _assistant.hasPreferenceFilters(intent);
      final List<Flight> preferenceFilteredFlights = _assistant
          .applyPreferenceFilter(budgetEffectiveFlights, intent: intent);
      final bool matchedPreferenceFilters =
          !hasPreferenceFilters || preferenceFilteredFlights.isNotEmpty;
      final List<Flight> effectiveFlights = matchedPreferenceFilters
          ? preferenceFilteredFlights
          : budgetEffectiveFlights;

      final List<Flight> historicalFlights = await _loadBookingHistoryFlights(
        currentUserId: currentUserId,
      );

      final AiFlightRecommendations recommendations = _assistant
          .buildRecommendations(
            flights: effectiveFlights,
            intent: intent,
            travelDate: resolved.query.date,
            fromAirport: resolved.query.fromAirport,
            toAirport: resolved.query.toAirport,
            historicalFlights: historicalFlights,
          );

      final String assistantReply = _buildSearchReply(
        query: resolved.query,
        flights: effectiveFlights,
        recommendations: recommendations,
        intent: intent,
        budgetUsd: intent.maxBudgetUsd,
        budgetFromPkr: intent.budgetFromPkr,
        anywhereSummary: resolved.anywhereSummary,
        hasPreferenceFilters: hasPreferenceFilters,
        matchedPreferenceFilters: matchedPreferenceFilters,
      );

      _appendAssistantReply(assistantReply);

      final bool requiresConfirmation = intent.wantsSurpriseDestination;
      final AiNavigationAction action = AiNavigationAction(
        id: _nextActionId(),
        target: AiNavigationTarget.results,
        query: resolved.query,
        maxBudgetUsd: intent.maxBudgetUsd,
        requiresConfirmation: requiresConfirmation,
        confirmationLabel: requiresConfirmation
            ? 'Open surprise flights'
            : null,
      );

      state = state.copyWith(
        isWorking: false,
        pendingNavigation: action,
        lastQuery: resolved.query,
        lastFlights: effectiveFlights,
        recommendations: recommendations,
      );
    } catch (_) {
      _appendAssistantReply(
        'I hit a temporary issue while searching. Please try again in a moment.',
      );
      state = state.copyWith(isWorking: false, clearPendingNavigation: true);
    }
  }

  Future<void> _handleCheapestBookedFlightPrompt({
    required String? currentUserId,
  }) async {
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _appendAssistantReply(
        'Sign in first and I can check your bookings for the cheapest fare.',
      );
      state = state.copyWith(isWorking: false, clearPendingNavigation: true);
      return;
    }

    try {
      final List<Booking> bookings = await _bookingRepository
          .watchUserBookings(currentUserId)
          .first;
      if (bookings.isEmpty) {
        _appendAssistantReply(
          'You do not have any bookings yet. Book a trip first and I can compare fares for you.',
        );
        state = state.copyWith(isWorking: false, clearPendingNavigation: true);
        return;
      }

      final Booking cheapest = bookings.reduce(
        (Booking a, Booking b) => a.amount <= b.amount ? a : b,
      );

      _appendAssistantReply(
        'Your cheapest booking is ${cheapest.flight.airline} from ${cheapest.flight.fromAirport} to ${cheapest.flight.toAirport} on ${cheapest.flight.departureTime.toShortDate()} at ${PriceFormatter.format(cheapest.amount)}. Tap Open cheapest booking to view details.',
      );

      state = state.copyWith(
        isWorking: false,
        pendingNavigation: AiNavigationAction(
          id: _nextActionId(),
          target: AiNavigationTarget.flightDetails,
          flight: cheapest.flight,
          requiresConfirmation: true,
          confirmationLabel: 'Open cheapest booking',
        ),
        clearRecommendations: true,
      );
    } catch (_) {
      _appendAssistantReply(
        'I could not read your bookings right now. Please try again in a moment.',
      );
      state = state.copyWith(isWorking: false, clearPendingNavigation: true);
    }
  }

  _UtilityPromptResult _handleUtilityPrompt({required AiParsedIntent intent}) {
    final FlightSearchQuery? query = state.lastQuery;
    final List<Flight> flights = state.lastFlights;
    final bool wantsNavigationAfterUtility =
        intent.wantsResults || intent.wantsFlightDetails || intent.wantsBooking;
    bool handledUtility = false;

    if (intent.wantsPriceRadar) {
      handledUtility = true;
      if (query == null || flights.isEmpty) {
        _appendAssistantReply(
          'Run a flight search first and I will generate a live Fare Radar for you.',
        );
      } else {
        _appendAssistantReply(
          _assistant.buildFareRadar(flights: flights, travelDate: query.date),
        );
      }
    }

    if (intent.wantsCompareOptions) {
      handledUtility = true;
      final AiFlightRecommendations? recommendations = state.recommendations;
      if (recommendations == null || flights.isEmpty) {
        _appendAssistantReply(
          'Search flights first, then I can compare cheapest, fastest, and best value in one view.',
        );
      } else {
        _appendAssistantReply(
          _assistant.buildRouteComparison(
            flights: flights,
            recommendations: recommendations,
          ),
        );
      }
    }

    if (intent.wantsPackingTips) {
      handledUtility = true;
      if (query == null) {
        _appendAssistantReply(
          'Tell me a destination or run a search first and I will build a packing plan.',
        );
      } else {
        _appendAssistantReply(
          _assistant.buildPackingTips(
            toAirport: query.toAirport,
            cabinClass: query.cabinClass,
          ),
        );
      }
    }

    if (intent.wantsVisaTips) {
      handledUtility = true;
      if (query == null) {
        _appendAssistantReply(
          'Share your destination first and I will provide visa prep guidance.',
        );
      } else {
        _appendAssistantReply(
          _assistant.buildVisaTips(toAirport: query.toAirport),
        );
      }
    }

    if (intent.wantsTripChecklist) {
      handledUtility = true;
      if (query == null) {
        _appendAssistantReply(
          'Run a route search first and I will generate your personalized trip checklist.',
        );
      } else {
        _appendAssistantReply(
          _assistant.buildTripChecklist(
            fromAirport: query.fromAirport,
            toAirport: query.toAirport,
            travelDate: query.date,
          ),
        );
      }
    }

    if (!handledUtility) {
      return _UtilityPromptResult.none;
    }

    if (wantsNavigationAfterUtility) {
      return _UtilityPromptResult.continueToSearch;
    }

    state = state.copyWith(isWorking: false, clearPendingNavigation: true);
    return _UtilityPromptResult.stop;
  }

  bool _shouldRunSearch(AiParsedIntent intent) {
    return intent.wantsResults ||
        intent.refersToPreviousResults ||
        intent.wantsAnywhereSearch ||
        intent.wantsSurpriseDestination ||
        intent.originCode != null ||
        intent.destinationCode != null ||
        intent.travelDate != null ||
        intent.maxBudgetUsd != null ||
        intent.maxStops != null ||
        intent.prefersMorningDeparture ||
        intent.prefersEveningDeparture ||
        intent.passengerCount != null ||
        intent.wantsCheapest ||
        intent.wantsFastest ||
        intent.wantsBestOption;
  }

  String _buildClarifyingReply(String userPrompt) {
    final String lower = userPrompt.trim().toLowerCase();
    const String genericFallback =
        'I can help with custom requests. Try: "Find cheapest flight from Karachi to Istanbul this Friday under 60k for 2 passengers."';

    if (lower.isEmpty ||
        RegExp(r'^[\p{P}\p{S}\s]+$', unicode: true).hasMatch(lower)) {
      return 'I am here. Tell me a route, date, or budget, for example: "Lahore to Dubai next Friday under 40k".';
    }

    if (lower.length <= 2) {
      return 'Share a bit more and I will help right away. Example: "Karachi to Istanbul next week for 2 passengers".';
    }

    if (_containsAny(lower, const <String>['hi', 'hello', 'hey'])) {
      return 'Hi! Share your route and preferences like "Lahore to Dubai next week under 40k" and I will find the best options. $genericFallback';
    }

    if (_containsAny(lower, const <String>['thanks', 'thank you', 'thx'])) {
      return 'You are welcome. Share route, date, and budget anytime and I will search flights for you.';
    }

    return genericFallback;
  }

  bool _containsAny(String input, List<String> tokens) {
    for (final String token in tokens) {
      final RegExp pattern = RegExp(
        '\\b${RegExp.escape(token)}\\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  void consumePendingNavigation(int actionId) {
    final AiNavigationAction? pending = state.pendingNavigation;
    if (pending == null || pending.id != actionId) {
      return;
    }

    state = state.copyWith(clearPendingNavigation: true);
  }

  void _handleNavigationPrompt({required AiParsedIntent intent}) {
    final Flight selected = _selectFlight(
      intent: intent,
      flights: state.lastFlights,
    );

    if (intent.wantsBooking) {
      _appendAssistantReply(
        'Great choice. I will open booking for ${selected.airline}. Please complete the final Confirm Booking step manually.',
      );

      state = state.copyWith(
        isWorking: false,
        pendingNavigation: AiNavigationAction(
          id: _nextActionId(),
          target: AiNavigationTarget.booking,
          flight: selected,
        ),
      );
      return;
    }

    _appendAssistantReply('Opening flight details for ${selected.airline}.');

    state = state.copyWith(
      isWorking: false,
      pendingNavigation: AiNavigationAction(
        id: _nextActionId(),
        target: AiNavigationTarget.flightDetails,
        flight: selected,
      ),
    );
  }

  Flight _selectFlight({
    required AiParsedIntent intent,
    required List<Flight> flights,
  }) {
    if (flights.isEmpty) {
      throw StateError('No flights available for selection.');
    }

    if (intent.selectionIndex != null) {
      final int bounded = math.max(
        0,
        math.min(intent.selectionIndex!, flights.length - 1),
      );
      return flights[bounded];
    }

    final List<Flight> preferenceMatches = _assistant.applyPreferenceFilter(
      flights,
      intent: intent,
    );
    final List<Flight> selectionPool = preferenceMatches.isNotEmpty
        ? preferenceMatches
        : flights;

    final AiFlightRecommendations? recommendations = state.recommendations;
    if (recommendations != null) {
      String targetId = recommendations.recommendedFlightId;
      if (intent.wantsCheapest) {
        targetId = recommendations.cheapestFlightId;
      } else if (intent.wantsFastest) {
        targetId = recommendations.fastestFlightId;
      } else if (intent.wantsBestOption) {
        targetId = recommendations.bestValueFlightId;
      }

      for (final Flight flight in selectionPool) {
        if (flight.id == targetId) {
          return flight;
        }
      }

      for (final Flight flight in flights) {
        if (flight.id == targetId) {
          return flight;
        }
      }
    }

    return _pickFlightByIntent(selectionPool, intent);
  }

  Flight _pickFlightByIntent(List<Flight> flights, AiParsedIntent intent) {
    if (flights.isEmpty) {
      throw StateError('No flights available for selection.');
    }

    if (intent.wantsFastest) {
      return flights.reduce(
        (Flight a, Flight b) => a.durationMinutes <= b.durationMinutes ? a : b,
      );
    }

    if (intent.wantsCheapest) {
      return flights.reduce((Flight a, Flight b) => a.price <= b.price ? a : b);
    }

    if (intent.wantsBestOption) {
      return flights.reduce((Flight a, Flight b) {
        final double scoreA =
            (a.price * 0.6) + (a.durationMinutes * 0.35) + (a.stops * 120);
        final double scoreB =
            (b.price * 0.6) + (b.durationMinutes * 0.35) + (b.stops * 120);
        return scoreA <= scoreB ? a : b;
      });
    }

    return flights.first;
  }

  SearchFormState _resolveSearchContextForm({
    required AiParsedIntent intent,
    required SearchFormState currentSearchForm,
  }) {
    final FlightSearchQuery? lastQuery = state.lastQuery;
    if (lastQuery == null) {
      return currentSearchForm;
    }

    final bool hasExplicitRoute =
        intent.originCode != null || intent.destinationCode != null;
    final bool hasExplicitTripData =
        intent.travelDate != null || intent.passengerCount != null;
    final bool hasRefinementOnly =
        intent.maxBudgetUsd != null ||
        intent.maxStops != null ||
        intent.prefersMorningDeparture ||
        intent.prefersEveningDeparture ||
        intent.wantsCheapest ||
        intent.wantsFastest ||
        intent.wantsBestOption;

    final bool shouldUseLastQuery =
        intent.refersToPreviousResults ||
        (!hasExplicitRoute && !hasExplicitTripData && hasRefinementOnly);

    if (!shouldUseLastQuery) {
      return currentSearchForm;
    }

    return currentSearchForm.copyWith(
      fromAirport: lastQuery.fromAirport,
      toAirport: lastQuery.toAirport,
      date: lastQuery.date,
      passengers: lastQuery.passengers,
      cabinClass: lastQuery.cabinClass,
    );
  }

  Future<List<Flight>> _loadBookingHistoryFlights({
    required String? currentUserId,
  }) async {
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      return const <Flight>[];
    }

    try {
      final List<Booking> bookings = await _bookingRepository
          .watchUserBookings(currentUserId)
          .first;
      return bookings
          .map((Booking value) => value.flight)
          .toList(growable: false);
    } catch (_) {
      return const <Flight>[];
    }
  }

  double _routePreferenceScore(
    AiRouteCandidate candidate,
    AiParsedIntent intent,
  ) {
    final List<Flight> flights = candidate.flights;
    final Flight cheapest = flights.reduce(
      (Flight a, Flight b) => a.price <= b.price ? a : b,
    );

    if (intent.wantsFastest) {
      final Flight fastest = flights.reduce(
        (Flight a, Flight b) => a.durationMinutes <= b.durationMinutes ? a : b,
      );
      return fastest.durationMinutes.toDouble();
    }

    if (intent.wantsBestOption) {
      final Flight best = _pickFlightByIntent(
        flights,
        const AiParsedIntent(rawInput: '', wantsBestOption: true),
      );
      return (best.price * 0.6) +
          (best.durationMinutes * 0.35) +
          (best.stops * 120);
    }

    final int minStops = flights
        .map((Flight value) => value.stops)
        .reduce(math.min);
    return (cheapest.price * 1.0) + (minStops * 120);
  }

  Future<_ResolvedSearch> _resolveSearch({
    required AiParsedIntent intent,
    required SearchFormState currentSearchForm,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final String origin = (intent.originCode ?? currentSearchForm.fromAirport)
        .trim()
        .toUpperCase();
    final DateTime date =
        (intent.travelDate ?? currentSearchForm.date).isBefore(today)
        ? today
        : (intent.travelDate ?? currentSearchForm.date);
    final int passengers =
        intent.passengerCount ?? currentSearchForm.passengers;
    final String cabinClass = intent.wantsCheapest
        ? 'Economy'
        : currentSearchForm.cabinClass;

    final String? explicitDestination = intent.destinationCode
        ?.trim()
        .toUpperCase();

    final bool shouldSearchAnywhere =
        intent.wantsAnywhereSearch || intent.wantsSurpriseDestination;

    if (!shouldSearchAnywhere && explicitDestination != null) {
      return _ResolvedSearch(
        query: FlightSearchQuery(
          fromAirport: origin,
          toAirport: explicitDestination,
          date: date,
          passengers: passengers,
          cabinClass: cabinClass,
        ),
      );
    }

    if (!shouldSearchAnywhere && explicitDestination == null) {
      return _ResolvedSearch(
        query: FlightSearchQuery(
          fromAirport: origin,
          toAirport: currentSearchForm.toAirport,
          date: date,
          passengers: passengers,
          cabinClass: cabinClass,
        ),
      );
    }

    final List<String> candidates = _assistant.destinationCandidates(
      origin: origin,
    );
    final List<FlightSearchQuery> queries = candidates
        .map(
          (String destination) => FlightSearchQuery(
            fromAirport: origin,
            toAirport: destination,
            date: date,
            passengers: passengers,
            cabinClass: cabinClass,
          ),
        )
        .toList();

    final List<List<Flight>> allResults = await Future.wait(
      queries.map(_flightRepository.searchFlights),
    );

    final List<AiRouteCandidate> ranked = <AiRouteCandidate>[];
    final bool hasPreferenceFilters = _assistant.hasPreferenceFilters(intent);
    for (int i = 0; i < queries.length; i++) {
      final List<Flight> budgetFilteredFlights = _assistant.applyBudgetFilter(
        allResults[i],
        intent.maxBudgetUsd,
      );

      List<Flight> effective;
      if (intent.maxBudgetUsd != null) {
        if (budgetFilteredFlights.isEmpty) {
          continue;
        }
        effective = budgetFilteredFlights;
      } else {
        effective = allResults[i];
      }
      if (effective.isEmpty) {
        continue;
      }

      if (hasPreferenceFilters) {
        final List<Flight> preferenceMatches = _assistant.applyPreferenceFilter(
          effective,
          intent: intent,
        );
        if (preferenceMatches.isEmpty) {
          continue;
        }
        effective = preferenceMatches;
      }

      final double cheapest = effective
          .map((Flight f) => f.price)
          .reduce(math.min);
      ranked.add(
        AiRouteCandidate(
          query: queries[i],
          flights: effective,
          cheapestPrice: cheapest,
        ),
      );
    }

    if (ranked.isEmpty) {
      final FlightSearchQuery fallback = FlightSearchQuery(
        fromAirport: origin,
        toAirport: currentSearchForm.toAirport,
        date: date,
        passengers: passengers,
        cabinClass: cabinClass,
      );
      return _ResolvedSearch(query: fallback);
    }

    ranked.sort((AiRouteCandidate a, AiRouteCandidate b) {
      final double scoreA = _routePreferenceScore(a, intent);
      final double scoreB = _routePreferenceScore(b, intent);
      final int byScore = scoreA.compareTo(scoreB);
      if (byScore != 0) {
        return byScore;
      }
      return a.cheapestPrice.compareTo(b.cheapestPrice);
    });

    final List<String> summary = ranked
        .take(3)
        .map(
          (AiRouteCandidate c) =>
              '${c.query.toAirport} from ${PriceFormatter.format(c.cheapestPrice)}',
        )
        .toList();

    AiRouteCandidate selected = ranked.first;
    if (intent.wantsSurpriseDestination) {
      final List<AiRouteCandidate> nonRecentCandidates = ranked
          .where(
            (AiRouteCandidate candidate) => !_recentSurpriseDestinations
                .contains(candidate.query.toAirport.trim().toUpperCase()),
          )
          .toList(growable: false);

      final List<AiRouteCandidate> eligible = nonRecentCandidates.isNotEmpty
          ? nonRecentCandidates
          : ranked;

      final int pool = math.min(3, eligible.length);
      final int pickIndex = DateTime.now().millisecondsSinceEpoch % pool;
      selected = eligible[pickIndex];
      _rememberSurpriseDestination(selected.query.toAirport);
    }

    return _ResolvedSearch(
      query: selected.query,
      preloadedFlights: selected.flights,
      anywhereSummary: summary,
    );
  }

  Future<FlightSearchQuery> _resolveCheapestWeekendQuery({
    required FlightSearchQuery baseQuery,
  }) async {
    if (!_isWeekendDate(baseQuery.date)) {
      return baseQuery;
    }

    try {
      final DateTime friday = _weekendFridayFor(baseQuery.date);
      final List<FlightSearchQuery> weekendQueries = <FlightSearchQuery>[
        for (int i = 0; i < 3; i++)
          FlightSearchQuery(
            fromAirport: baseQuery.fromAirport,
            toAirport: baseQuery.toAirport,
            date: friday.add(Duration(days: i)),
            passengers: baseQuery.passengers,
            cabinClass: baseQuery.cabinClass,
          ),
      ];

      final List<List<Flight>> weekendFlights = await Future.wait(
        weekendQueries.map(_flightRepository.searchFlights),
      );

      FlightSearchQuery cheapestQuery = baseQuery;
      double? cheapestPrice;

      for (int i = 0; i < weekendQueries.length; i++) {
        final List<Flight> flights = weekendFlights[i];
        if (flights.isEmpty) {
          continue;
        }

        final double candidateCheapest = flights
            .map((Flight f) => f.price)
            .reduce(math.min);

        if (cheapestPrice == null || candidateCheapest < cheapestPrice) {
          cheapestPrice = candidateCheapest;
          cheapestQuery = weekendQueries[i];
        }
      }

      return cheapestQuery;
    } catch (_) {
      return baseQuery;
    }
  }

  String _buildSearchReply({
    required FlightSearchQuery query,
    required List<Flight> flights,
    required AiFlightRecommendations recommendations,
    required AiParsedIntent intent,
    required double? budgetUsd,
    required bool budgetFromPkr,
    required List<String> anywhereSummary,
    required bool hasPreferenceFilters,
    required bool matchedPreferenceFilters,
  }) {
    final Flight recommended = flights.firstWhere(
      (Flight f) => f.id == recommendations.recommendedFlightId,
      orElse: () => flights.first,
    );

    final List<String> lines = <String>[
      'I found ${flights.length} flights from ${query.fromAirport} to ${query.toAirport} on ${query.date.toShortDate()}.',
      'AI Recommended: ${recommended.airline} at ${PriceFormatter.format(recommended.price)} (${recommendations.recommendedReason}).',
    ];

    if (budgetUsd != null) {
      final String source = budgetFromPkr ? ' (converted from PKR)' : '';
      lines.add(
        'Applied budget filter: up to ${PriceFormatter.format(budgetUsd)}$source.',
      );
    }

    if (hasPreferenceFilters) {
      final String summary = _assistant.preferenceSummary(intent);
      if (matchedPreferenceFilters) {
        lines.add('Applied travel preference: $summary.');
      } else {
        lines.add(
          'I could not find exact matches for $summary, so I kept the closest available options on this route.',
        );
      }
    }

    if (anywhereSummary.isNotEmpty) {
      lines.add('Anywhere search picks: ${anywhereSummary.join(', ')}.');
    }

    if (recommendations.routeInsight != null) {
      lines.add(recommendations.routeInsight!);
    }
    if (recommendations.timingSuggestion != null) {
      lines.add(recommendations.timingSuggestion!);
    }

    lines.add(
      _assistant.buildFareRadar(flights: flights, travelDate: query.date),
    );
    lines.add(_assistant.buildDestinationSpotlight(query.toAirport));

    if (intent.wantsSurpriseDestination) {
      lines.add(
        'Surprise mode is on: I picked one of the best-value route options for you.',
      );
      lines.add(
        'Tap Open surprise flights when you are ready to view options.',
      );
    } else {
      lines.add('I will open results now.');
    }

    lines.add(
      'If you proceed to booking later, final confirmation remains manual.',
    );

    return lines.join(' ');
  }

  String _buildNoFlightReply({
    required FlightSearchQuery query,
    required double? budgetUsd,
    required bool budgetFromPkr,
    required List<Flight> rawFlights,
    required bool canShowCheapestAction,
    required String cheapestActionLabel,
  }) {
    if (budgetUsd == null) {
      return 'I could not find flights right now. Try another date or route and I will search again.';
    }

    final String source = budgetFromPkr ? ' (converted from PKR)' : '';
    if (rawFlights.isEmpty) {
      return 'I could not find flights from ${query.fromAirport} to ${query.toAirport} under ${PriceFormatter.format(budgetUsd)}$source. Try another date or route.';
    }

    final double cheapestAvailable = rawFlights
        .map((Flight f) => f.price)
        .reduce(math.min);
    if (canShowCheapestAction) {
      return 'No flights found under ${PriceFormatter.format(budgetUsd)}$source for ${query.fromAirport} to ${query.toAirport}. Cheapest available is ${PriceFormatter.format(cheapestAvailable)}. Tap $cheapestActionLabel if you want me to open the nearest options.';
    }

    return 'No flights found under ${PriceFormatter.format(budgetUsd)}$source for ${query.fromAirport} to ${query.toAirport}. Cheapest available is ${PriceFormatter.format(cheapestAvailable)}. Try a higher budget or a different date.';
  }

  String _cheapestActionLabelForDate(DateTime date) {
    if (_isWeekendDate(date)) {
      return 'Show cheapest weekend flight';
    }

    return 'Show cheapest flights';
  }

  DateTime _weekendFridayFor(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    final int daysSinceFriday = normalized.weekday - DateTime.friday;
    return normalized.subtract(Duration(days: daysSinceFriday));
  }

  bool _isWeekendDate(DateTime date) {
    return date.weekday == DateTime.friday ||
        date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;
  }

  void _appendAssistantReply(String text) {
    _appendMessage(
      AiChatMessage(
        id: _nextMessageId(),
        role: AiChatRole.assistant,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _appendMessage(AiChatMessage message) {
    state = state.copyWith(
      messages: <AiChatMessage>[...state.messages, message],
    );
  }

  String _nextMessageId() {
    _messageSeed += 1;
    return 'ai-msg-$_messageSeed';
  }

  int _nextActionId() {
    _actionSeed += 1;
    return _actionSeed;
  }

  void _rememberSurpriseDestination(String toAirport) {
    final String normalized = toAirport.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }

    _recentSurpriseDestinations.remove(normalized);
    _recentSurpriseDestinations.add(normalized);

    while (_recentSurpriseDestinations.length > _surpriseHistoryLimit) {
      _recentSurpriseDestinations.removeAt(0);
    }
  }

  void _resetConversation() {
    state = AiAssistantState.initial().copyWith(
      messages: <AiChatMessage>[_buildWelcomeMessage()],
      clearPendingNavigation: true,
      clearLastQuery: true,
      clearRecommendations: true,
      lastFlights: const <Flight>[],
    );
  }

  AiChatMessage _buildWelcomeMessage() {
    return AiChatMessage(
      id: _nextMessageId(),
      role: AiChatRole.assistant,
      text:
          'Hi! I can search flights, compare options, and guide you to booking. Final booking confirmation is always manual.',
      createdAt: DateTime.now(),
    );
  }
}

class _ResolvedSearch {
  const _ResolvedSearch({
    required this.query,
    this.preloadedFlights,
    this.anywhereSummary = const <String>[],
  });

  final FlightSearchQuery query;
  final List<Flight>? preloadedFlights;
  final List<String> anywhereSummary;
}

enum _UtilityPromptResult { none, stop, continueToSearch }



