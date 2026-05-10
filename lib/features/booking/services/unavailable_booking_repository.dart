import 'package:air_sky/features/booking/services/booking_repository.dart';
import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/booking/models/passenger.dart';
import 'package:air_sky/features/flights/models/flight.dart';

class UnavailableBookingRepository implements BookingRepository {
  @override
  Future<Booking> createBooking({
    required String userId,
    required Flight flight,
    required List<Passenger> passengers,
    required List<String> seatNumbers,
  }) {
    throw Exception(
      'Booking service is temporarily unavailable. Please try again later.',
    );
  }

  @override
  Future<void> startPayment({
    required String userId,
    required String bookingId,
  }) {
    throw Exception(
      'Payment service is temporarily unavailable. Please try again later.',
    );
  }

  @override
  Future<void> confirmPayment({
    required String userId,
    required String bookingId,
    required String transactionReference,
  }) {
    throw Exception(
      'Payment confirmation is temporarily unavailable. Please try again later.',
    );
  }

  @override
  Future<void> cancelBooking({
    required String userId,
    required String bookingId,
  }) {
    throw Exception(
      'Booking cancellation is temporarily unavailable. Please try again later.',
    );
  }

  @override
  Stream<List<Booking>> watchUserBookings(String userId) {
    return const Stream<List<Booking>>.empty();
  }
}



