import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/booking/models/passenger.dart';
import 'package:air_sky/features/flights/models/flight.dart';

abstract class BookingRepository {
  Future<Booking> createBooking({
    required String userId,
    required Flight flight,
    required List<Passenger> passengers,
    required List<String> seatNumbers,
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

  Future<void> cancelBooking({
    required String userId,
    required String bookingId,
  });

  Future<void> editBooking({
    required String userId,
    required String bookingId,
    required List<Passenger> passengers,
    required List<String> seatNumbers,
  });

  Stream<List<Booking>> watchUserBookings(String userId);
}



