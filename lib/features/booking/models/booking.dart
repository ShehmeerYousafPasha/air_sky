import 'package:air_sky/features/booking/models/passenger.dart';
import 'package:air_sky/features/flights/models/flight.dart';

class Booking {
  Booking({
    required this.bookingId,
    required this.userId,
    required this.flight,
    required this.passengers,
    required this.seatNumbers,
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
    DateTime? updatedAt,
    this.cancelledAt,
  }) : updatedAt = updatedAt ?? createdAt,
       assert(passengers.isNotEmpty, 'At least one passenger is required.'),
       assert(
         seatNumbers.length == passengers.length,
         'Seat count must match passenger count.',
       );

  final String bookingId;
  final String userId;
  final Flight flight;
  final List<Passenger> passengers;
  final List<String> seatNumbers;
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
  final DateTime updatedAt;
  final DateTime? cancelledAt;

  Passenger get passenger =>
      passengers.isNotEmpty ? passengers.first : const Passenger.empty();

  String get seatNumber => seatNumbers.isNotEmpty ? seatNumbers.first : '';

  int get passengerCount => passengers.length;

  String get passengerNamesLabel => passengers
      .map((Passenger value) => value.fullName)
      .where((String value) => value.trim().isNotEmpty && value != '-')
      .join(', ');

  String get seatSummary =>
      seatNumbers.where((String value) => value.trim().isNotEmpty).join(', ');

  bool get isPaid => paymentStatus == 'paid';

  bool get isCancelled => status == 'cancelled';

  bool get isUpcoming => status == 'upcoming';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bookingId': bookingId,
      'userId': userId,
      'flight': flight.toMap(),
      'passengers': passengers.map((Passenger value) => value.toMap()).toList(),
      'seatNumbers': seatNumbers,
      // Keep legacy single-passenger fields for backward compatibility.
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
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
    };
  }

  factory Booking.fromMap(Map<dynamic, dynamic> map) {
    final List<Passenger> parsedPassengers =
        ((map['passengers'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic entry) {
              if (entry is Map<dynamic, dynamic>) {
                return Passenger.fromMap(entry);
              }
              return const Passenger.empty();
            })
            .where(
              (Passenger value) =>
                  value.fullName != '-' || value.email.trim().isNotEmpty,
            )
            .toList(growable: true);

    if (parsedPassengers.isEmpty) {
      parsedPassengers.add(
        Passenger.fromMap(
          map['passenger'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
        ),
      );
    }

    final List<String> parsedSeatNumbers =
        ((map['seatNumbers'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic entry) => entry.toString().trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: true);

    if (parsedSeatNumbers.isEmpty) {
      final String legacySeat = (map['seatNumber'] as String? ?? '').trim();
      if (legacySeat.isNotEmpty) {
        parsedSeatNumbers.add(legacySeat);
      }
    }

    while (parsedSeatNumbers.length < parsedPassengers.length) {
      parsedSeatNumbers.add('');
    }

    if (parsedSeatNumbers.length > parsedPassengers.length) {
      parsedSeatNumbers.removeRange(
        parsedPassengers.length,
        parsedSeatNumbers.length,
      );
    }

    return Booking(
      bookingId: map['bookingId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      flight: Flight.fromMap(
        map['flight'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
      ),
      passengers: parsedPassengers,
      seatNumbers: parsedSeatNumbers,
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
      updatedAt: (map['updatedAt'] as int?) == null
          ? DateTime.fromMillisecondsSinceEpoch((map['createdAt'] as int?) ?? 0)
          : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      cancelledAt: (map['cancelledAt'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['cancelledAt'] as int),
    );
  }
}


