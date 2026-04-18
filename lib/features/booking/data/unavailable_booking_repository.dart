import 'package:air_sky/features/booking/domain/booking_repository.dart';
import 'package:air_sky/features/booking/domain/entities/booking.dart';
import 'package:air_sky/features/booking/domain/entities/passenger.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';

class UnavailableBookingRepository implements BookingRepository {
  @override
  Future<Booking> createBooking({
    required String userId,
    required Flight flight,
    required Passenger passenger,
    required String seatNumber,
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
  Stream<List<Booking>> watchUserBookings(String userId) {
    return const Stream<List<Booking>>.empty();
  }
}
