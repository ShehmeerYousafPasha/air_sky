import 'package:air_sky/features/booking/domain/entities/booking.dart';
import 'package:air_sky/features/booking/domain/entities/passenger.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';

abstract class BookingRepository {
  Future<Booking> createBooking({
    required String userId,
    required Flight flight,
    required Passenger passenger,
    required String seatNumber,
  });

  Future<void> startPayment({
    required String userId,
    required String bookingId,
  });

  Future<void> confirmPayment({
    required String userId,
    required String bookingId,
    required String transactionReference,
  });

  Stream<List<Booking>> watchUserBookings(String userId);
}
