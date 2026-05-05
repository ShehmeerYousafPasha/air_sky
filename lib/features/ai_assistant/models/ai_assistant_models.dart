import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/features/flights/models/flight_search_query.dart';

enum AiChatRole { user, assistant }

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final AiChatRole role;
  final String text;
  final DateTime createdAt;
}

enum AiNavigationTarget { none, results, flightDetails, booking }

class AiNavigationAction {
  const AiNavigationAction({
    required this.id,
    required this.target,
    this.query,
    this.flight,
    this.maxBudgetUsd,
    this.forceCheapestSort = false,
    this.requiresConfirmation = false,
    this.confirmationLabel,
  });

  final int id;
  final AiNavigationTarget target;
  final FlightSearchQuery? query;
  final Flight? flight;
  final double? maxBudgetUsd;
  final bool forceCheapestSort;
  final bool requiresConfirmation;
  final String? confirmationLabel;
}

class AiFlightRecommendations {
  const AiFlightRecommendations({
    required this.recommendedFlightId,
    required this.recommendedReason,
    required this.cheapestFlightId,
    required this.fastestFlightId,
    required this.bestValueFlightId,
    this.routeInsight,
    this.timingSuggestion,
  });

  final String recommendedFlightId;
  final String recommendedReason;
  final String cheapestFlightId;
  final String fastestFlightId;
  final String bestValueFlightId;
  final String? routeInsight;
  final String? timingSuggestion;
}

class AiAssistantState {
  const AiAssistantState({
    required this.messages,
    required this.isWorking,
    this.pendingNavigation,
    this.lastQuery,
    this.lastFlights = const <Flight>[],
    this.recommendations,
  });

  final List<AiChatMessage> messages;
  final bool isWorking;
  final AiNavigationAction? pendingNavigation;
  final FlightSearchQuery? lastQuery;
  final List<Flight> lastFlights;
  final AiFlightRecommendations? recommendations;

  factory AiAssistantState.initial() =>
      const AiAssistantState(messages: <AiChatMessage>[], isWorking: false);

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isWorking,
    AiNavigationAction? pendingNavigation,
    bool clearPendingNavigation = false,
    FlightSearchQuery? lastQuery,
    bool clearLastQuery = false,
    List<Flight>? lastFlights,
    AiFlightRecommendations? recommendations,
    bool clearRecommendations = false,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isWorking: isWorking ?? this.isWorking,
      pendingNavigation: clearPendingNavigation
          ? null
          : (pendingNavigation ?? this.pendingNavigation),
      lastQuery: clearLastQuery ? null : (lastQuery ?? this.lastQuery),
      lastFlights: lastFlights ?? this.lastFlights,
      recommendations: clearRecommendations
          ? null
          : (recommendations ?? this.recommendations),
    );
  }
}

class AiParsedIntent {
  const AiParsedIntent({
    required this.rawInput,
    this.originCode,
    this.destinationCode,
    this.travelDate,
    this.maxBudgetUsd,
    this.budgetFromPkr = false,
    this.passengerCount,
    this.wantsAnywhereSearch = false,
    this.wantsCheapest = false,
    this.wantsFastest = false,
    this.wantsBestOption = false,
    this.wantsResults = false,
    this.wantsFlightDetails = false,
    this.wantsBooking = false,
    this.wantsPriceRadar = false,
    this.wantsPackingTips = false,
    this.wantsVisaTips = false,
    this.wantsTripChecklist = false,
    this.wantsCompareOptions = false,
    this.wantsSurpriseDestination = false,
    this.wantsCheapestBookedFlight = false,
    this.maxStops,
    this.prefersMorningDeparture = false,
    this.prefersEveningDeparture = false,
    this.refersToPreviousResults = false,
    this.selectionIndex,
  });

  final String rawInput;
  final String? originCode;
  final String? destinationCode;
  final DateTime? travelDate;
  final double? maxBudgetUsd;
  final bool budgetFromPkr;
  final int? passengerCount;
  final bool wantsAnywhereSearch;
  final bool wantsCheapest;
  final bool wantsFastest;
  final bool wantsBestOption;
  final bool wantsResults;
  final bool wantsFlightDetails;
  final bool wantsBooking;
  final bool wantsPriceRadar;
  final bool wantsPackingTips;
  final bool wantsVisaTips;
  final bool wantsTripChecklist;
  final bool wantsCompareOptions;
  final bool wantsSurpriseDestination;
  final bool wantsCheapestBookedFlight;
  final int? maxStops;
  final bool prefersMorningDeparture;
  final bool prefersEveningDeparture;
  final bool refersToPreviousResults;
  final int? selectionIndex;
}

class AiRouteCandidate {
  const AiRouteCandidate({
    required this.query,
    required this.flights,
    required this.cheapestPrice,
  });

  final FlightSearchQuery query;
  final List<Flight> flights;
  final double cheapestPrice;
}



