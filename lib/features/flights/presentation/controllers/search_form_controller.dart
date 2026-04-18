import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/flights/domain/entities/flight_search_query.dart';

class SearchFormState {
  const SearchFormState({
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

  bool get isValid =>
      fromAirport.isNotEmpty &&
      toAirport.isNotEmpty &&
      fromAirport != toAirport;

  FlightSearchQuery toQuery() {
    return FlightSearchQuery(
      fromAirport: fromAirport,
      toAirport: toAirport,
      date: date,
      passengers: passengers,
      cabinClass: cabinClass,
    );
  }

  SearchFormState copyWith({
    String? fromAirport,
    String? toAirport,
    DateTime? date,
    int? passengers,
    String? cabinClass,
  }) {
    return SearchFormState(
      fromAirport: fromAirport ?? this.fromAirport,
      toAirport: toAirport ?? this.toAirport,
      date: date ?? this.date,
      passengers: passengers ?? this.passengers,
      cabinClass: cabinClass ?? this.cabinClass,
    );
  }
}

class SearchFormController extends StateNotifier<SearchFormState> {
  SearchFormController()
    : super(
        SearchFormState(
          fromAirport: 'ISB',
          toAirport: 'DXB',
          date: DateTime.now().add(const Duration(days: 10)),
          passengers: 1,
          cabinClass: 'Economy',
        ),
      );

  void setFromAirport(String value) =>
      state = state.copyWith(fromAirport: value.toUpperCase());

  void setToAirport(String value) =>
      state = state.copyWith(toAirport: value.toUpperCase());

  void swapAirports() {
    state = state.copyWith(
      fromAirport: state.toAirport,
      toAirport: state.fromAirport,
    );
  }

  void setDate(DateTime value) => state = state.copyWith(date: value);

  void setPassengers(int value) =>
      state = state.copyWith(passengers: value.clamp(1, 9));

  void increasePassengers() =>
      state = state.copyWith(passengers: (state.passengers + 1).clamp(1, 9));

  void decreasePassengers() =>
      state = state.copyWith(passengers: (state.passengers - 1).clamp(1, 9));

  void setCabinClass(String value) => state = state.copyWith(cabinClass: value);
}
