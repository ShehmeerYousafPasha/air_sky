import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:air_sky/utils/id_generator.dart';
import 'package:air_sky/features/booking/services/booking_repository.dart';
import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/booking/models/passenger.dart';
import 'package:air_sky/features/flights/models/flight.dart';

class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;
  static final Random _random = Random();
  static final RegExp _transactionReferencePattern = RegExp(
    r'^TXN-[A-Z0-9]{8,20}$',
  );
  static const int _dummyProcessingDelayMs = 8000;

  @override
  Future<Booking> createBooking({
    required String userId,
    required Flight flight,
    required List<Passenger> passengers,
    required List<String> seatNumbers,
  }) async {
    if (passengers.isEmpty) {
      throw Exception('At least one passenger is required.');
    }

    if (seatNumbers.length != passengers.length) {
      throw Exception('Seat selection must match passenger count.');
    }

    final List<String> normalizedSeats = seatNumbers
        .map((String value) => value.trim().toUpperCase())
        .toList(growable: false);

    if (normalizedSeats.any((String value) => value.isEmpty)) {
      throw Exception('Select a seat for every passenger.');
    }

    final Set<String> uniqueSeats = normalizedSeats.toSet();
    if (uniqueSeats.length != normalizedSeats.length) {
      throw Exception('Each passenger must have a unique seat.');
    }

    final String bookingId = IdGenerator.bookingId();
    final String psid = IdGenerator.psid();
    final DateTime now = DateTime.now();

    final Booking booking = Booking(
      bookingId: bookingId,
      userId: userId,
      flight: flight,
      passengers: passengers,
      seatNumbers: normalizedSeats,
      createdAt: now,
      status: flight.departureTime.isAfter(now) ? 'upcoming' : 'completed',
      paymentStatus: 'unpaid',
      paymentMethod: 'psid',
      psid: psid,
      amount: flight.price,
      currency: 'USD',
      paymentDueAt: now.add(const Duration(hours: 24)),
      paidAt: null,
      providerTransactionId: null,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .doc(bookingId)
        .set(booking.toMap());

    return booking;
  }

  @override
  Future<void> startPayment({
    required String userId,
    required String bookingId,
  }) async {
    final DocumentReference<Map<String, dynamic>> bookingRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .doc(bookingId);

    final DocumentSnapshot<Map<String, dynamic>> current = await bookingRef
        .get();
    final Map<String, dynamic>? data = current.data();
    if (data == null) {
      throw Exception('Booking not found.');
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int? dueAtMs = data['paymentDueAt'] as int?;
    if (dueAtMs != null && nowMs > dueAtMs) {
      throw Exception('Payment window expired.');
    }

    final String currentPaymentStatus = (data['paymentStatus'] as String? ?? '')
        .trim();

    if (currentPaymentStatus == 'paid') {
      throw Exception('Payment already completed.');
    }

    if (currentPaymentStatus == 'payment_processing') {
      final String marker = (data['providerTransactionId'] as String? ?? '')
          .trim();
      final int? startedAtMs = _extractDummyStartedAt(marker);
      if (startedAtMs != null &&
          nowMs < startedAtMs + _dummyProcessingDelayMs) {
        throw Exception('Verification already in progress.');
      }
      throw Exception(
        'Verification timer ended. Confirm payment with reference.',
      );
    }

    if (currentPaymentStatus != 'unpaid') {
      throw Exception('Payment is unavailable for this booking.');
    }

    await _startLocalDummyPayment(bookingRef: bookingRef, startedAtMs: nowMs);
  }

  @override
  Future<void> confirmPayment({
    required String userId,
    required String bookingId,
    required String transactionReference,
  }) async {
    final DocumentReference<Map<String, dynamic>> bookingRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .doc(bookingId);

    final DocumentSnapshot<Map<String, dynamic>> current = await bookingRef
        .get();
    final Map<String, dynamic>? data = current.data();
    if (data == null) {
      throw Exception('Booking not found.');
    }

    final String currentPaymentStatus = (data['paymentStatus'] as String? ?? '')
        .trim();
    if (currentPaymentStatus == 'paid') {
      return;
    }
    if (currentPaymentStatus == 'unpaid') {
      throw Exception('Start payment first.');
    }
    if (currentPaymentStatus != 'payment_processing') {
      throw Exception('Payment is not in verification state.');
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int? dueAtMs = data['paymentDueAt'] as int?;
    if (dueAtMs != null && nowMs > dueAtMs) {
      throw Exception('Payment window expired.');
    }

    final String cleanedReference = transactionReference.trim().toUpperCase();
    if (!_transactionReferencePattern.hasMatch(cleanedReference)) {
      throw Exception('Enter a valid transaction reference (TXN-XXXXXXXX).');
    }

    final String verificationMarker =
        (data['providerTransactionId'] as String? ?? '').trim();
    final int? startedAtMs = _extractDummyStartedAt(verificationMarker);
    if (startedAtMs == null) {
      throw Exception('Payment session is invalid. Start payment again.');
    }

    if (nowMs < startedAtMs + _dummyProcessingDelayMs) {
      throw Exception('Verification in progress. Wait for countdown.');
    }

    await bookingRef.set(<String, dynamic>{
      'paymentStatus': 'paid',
      'paymentMethod': 'dummy_local',
      'providerTransactionId': cleanedReference,
      'paidAt': nowMs,
    }, SetOptions(merge: true));
  }

  Future<void> _startLocalDummyPayment({
    required DocumentReference<Map<String, dynamic>> bookingRef,
    required int startedAtMs,
  }) async {
    final String transactionId = _createDummyTransactionId(startedAtMs);

    await bookingRef.set(<String, dynamic>{
      'paymentStatus': 'payment_processing',
      'paymentMethod': 'dummy_local',
      'providerTransactionId': transactionId,
      'paidAt': null,
    }, SetOptions(merge: true));
  }

  String _createDummyTransactionId(int startedAtMs) {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final String suffix = List<String>.generate(
      6,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
    return 'DUMMY-$startedAtMs-$suffix';
  }

  int? _extractDummyStartedAt(String providerTransactionId) {
    final List<String> parts = providerTransactionId.split('-');
    if (parts.length < 3 || parts.first != 'DUMMY') {
      return null;
    }
    return int.tryParse(parts[1]);
  }

  @override
  Stream<List<Booking>> watchUserBookings(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    Booking.fromMap(doc.data()),
              )
              .toList(),
        );
  }
}



