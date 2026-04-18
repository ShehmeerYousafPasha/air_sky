import 'package:air_sky/features/booking/domain/entities/passenger.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';

class Booking {
  const Booking({
    required this.bookingId,
    required this.userId,
    required this.flight,
    required this.passenger,
    required this.seatNumber,
    required this.createdAt,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.psid,
    required this.amount,
    required this.currency,
    this.paymentDueAt,
    this.paidAt,
    this.providerTransactionId,
  });

  final String bookingId;
  final String userId;
  final Flight flight;
  final Passenger passenger;
  final String seatNumber;
  final DateTime createdAt;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String psid;
  final double amount;
  final String currency;
  final DateTime? paymentDueAt;
  final DateTime? paidAt;
  final String? providerTransactionId;

  bool get isPaid => paymentStatus == 'paid';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bookingId': bookingId,
      'userId': userId,
      'flight': flight.toMap(),
      'passenger': passenger.toMap(),
      'seatNumber': seatNumber,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'psid': psid,
      'amount': amount,
      'currency': currency,
      'paymentDueAt': paymentDueAt?.millisecondsSinceEpoch,
      'paidAt': paidAt?.millisecondsSinceEpoch,
      'providerTransactionId': providerTransactionId,
    };
  }

  factory Booking.fromMap(Map<dynamic, dynamic> map) {
    return Booking(
      bookingId: map['bookingId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      flight: Flight.fromMap(
        map['flight'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
      ),
      passenger: Passenger.fromMap(
        map['passenger'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
      ),
      seatNumber: map['seatNumber'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? 0,
      ),
      status: map['status'] as String? ?? 'upcoming',
      paymentStatus: map['paymentStatus'] as String? ?? 'paid',
      paymentMethod: map['paymentMethod'] as String? ?? 'psid',
      psid: map['psid'] as String? ?? '',
      amount:
          (map['amount'] as num?)?.toDouble() ??
          ((map['flight'] as Map<dynamic, dynamic>?)?['price'] as num?)
              ?.toDouble() ??
          0,
      currency: map['currency'] as String? ?? 'USD',
      paymentDueAt: (map['paymentDueAt'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['paymentDueAt'] as int),
      paidAt: (map['paidAt'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['paidAt'] as int),
      providerTransactionId: map['providerTransactionId'] as String?,
    );
  }
}
