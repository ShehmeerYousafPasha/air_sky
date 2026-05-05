import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/booking/services/booking_repository.dart';
import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/booking/models/passenger.dart';
import 'package:air_sky/features/flights/models/flight.dart';

class BookingState {
  const BookingState({
    required this.currentStep,
    this.passengers = const <Passenger>[],
    this.selectedSeats = const <String>[],
    this.isSubmitting = false,
    this.bookingId,
    this.createdBooking,
    this.errorMessage,
  });

  final int currentStep;
  final List<Passenger> passengers;
  final List<String> selectedSeats;
  final bool isSubmitting;
  final String? bookingId;
  final Booking? createdBooking;
  final String? errorMessage;

  factory BookingState.initial() => const BookingState(currentStep: 0);

  BookingState copyWith({
    int? currentStep,
    List<Passenger>? passengers,
    bool clearPassengers = false,
    List<String>? selectedSeats,
    bool clearSelectedSeats = false,
    bool? isSubmitting,
    String? bookingId,
    bool clearBookingId = false,
    Booking? createdBooking,
    bool clearCreatedBooking = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookingState(
      currentStep: currentStep ?? this.currentStep,
      passengers: clearPassengers
          ? const <Passenger>[]
          : (passengers ?? this.passengers),
      selectedSeats: clearSelectedSeats
          ? const <String>[]
          : (selectedSeats ?? this.selectedSeats),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      bookingId: clearBookingId ? null : (bookingId ?? this.bookingId),
      createdBooking: clearCreatedBooking
          ? null
          : (createdBooking ?? this.createdBooking),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BookingController extends StateNotifier<BookingState> {
  BookingController(this._repository) : super(BookingState.initial());

  final BookingRepository _repository;

  String _toUserErrorMessage(Object error, {required String fallbackMessage}) {
    final String raw = error.toString().trim();
    const String exceptionPrefix = 'Exception: ';
    final String message = raw.startsWith(exceptionPrefix)
        ? raw.substring(exceptionPrefix.length).trim()
        : raw;

    if (message.isEmpty) {
      return fallbackMessage;
    }

    final String normalized = message.toLowerCase();
    if (normalized.contains('stack trace') ||
        normalized.contains('firebase') ||
        normalized.contains('flutterfire') ||
        normalized.contains('exception') ||
        normalized.contains('package:') ||
        normalized.contains('dart:')) {
      return fallbackMessage;
    }

    return message;
  }

  void setPassengers(List<Passenger> values) {
    state = state.copyWith(passengers: List<Passenger>.from(values));
  }

  void selectSeatForPassenger({
    required int passengerIndex,
    required int totalPassengers,
    required String seat,
  }) {
    if (passengerIndex < 0 || passengerIndex >= totalPassengers) {
      return;
    }

    final List<String> seats = List<String>.generate(
      totalPassengers,
      (int index) =>
          index < state.selectedSeats.length ? state.selectedSeats[index] : '',
      growable: false,
    );

    for (int i = 0; i < seats.length; i++) {
      if (i != passengerIndex && seats[i] == seat) {
        return;
      }
    }

    seats[passengerIndex] = seat;
    state = state.copyWith(selectedSeats: seats);
  }

  void setSelectedSeats(List<String> values) {
    state = state.copyWith(selectedSeats: List<String>.from(values));
  }

  void nextStep() {
    if (state.currentStep < 3) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<void> submitBooking({
    required String userId,
    required Flight flight,
  }) async {
    final List<Passenger> passengers = state.passengers;
    final List<String> seatNumbers = state.selectedSeats
        .map((String value) => value.trim().toUpperCase())
        .toList(growable: false);

    if (passengers.isEmpty ||
        seatNumbers.length != passengers.length ||
        seatNumbers.any((String value) => value.isEmpty)) {
      state = state.copyWith(
        errorMessage: 'Passenger details and seats are required.',
      );
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearBookingId: true,
      clearCreatedBooking: true,
    );

    try {
      final Booking booking = await _repository.createBooking(
        userId: userId,
        flight: flight,
        passengers: passengers,
        seatNumbers: seatNumbers,
      );

      state = state.copyWith(
        isSubmitting: false,
        bookingId: booking.bookingId,
        createdBooking: booking,
        currentStep: 3,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _toUserErrorMessage(
          error,
          fallbackMessage:
              'Unable to complete booking right now. Please try again later.',
        ),
      );
    }
  }

  void resetFlow() {
    state = BookingState.initial();
  }
}



