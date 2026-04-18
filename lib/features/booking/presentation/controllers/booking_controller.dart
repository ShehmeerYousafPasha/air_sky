import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/booking/domain/booking_repository.dart';
import 'package:air_sky/features/booking/domain/entities/booking.dart';
import 'package:air_sky/features/booking/domain/entities/passenger.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';

class BookingState {
  const BookingState({
    required this.currentStep,
    this.passenger,
    this.selectedSeat,
    this.isSubmitting = false,
    this.bookingId,
    this.createdBooking,
    this.errorMessage,
  });

  final int currentStep;
  final Passenger? passenger;
  final String? selectedSeat;
  final bool isSubmitting;
  final String? bookingId;
  final Booking? createdBooking;
  final String? errorMessage;

  factory BookingState.initial() => const BookingState(currentStep: 0);

  BookingState copyWith({
    int? currentStep,
    Passenger? passenger,
    bool clearPassenger = false,
    String? selectedSeat,
    bool clearSeat = false,
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
      passenger: clearPassenger ? null : (passenger ?? this.passenger),
      selectedSeat: clearSeat ? null : (selectedSeat ?? this.selectedSeat),
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

  void setPassenger(Passenger value) {
    state = state.copyWith(passenger: value);
  }

  void selectSeat(String seat) {
    state = state.copyWith(selectedSeat: seat);
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
    final Passenger? passenger = state.passenger;
    final String? seat = state.selectedSeat;

    if (passenger == null || seat == null) {
      state = state.copyWith(
        errorMessage: 'Passenger details and seat are required.',
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
        passenger: passenger,
        seatNumber: seat,
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
