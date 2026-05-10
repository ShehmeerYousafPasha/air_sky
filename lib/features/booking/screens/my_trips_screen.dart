import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/route_paths.dart';
import 'package:air_sky/utils/account_required_prompt.dart';
import 'package:air_sky/utils/app_feedback.dart';
import 'package:air_sky/features/booking/models/booking.dart';
import 'package:air_sky/features/booking/models/passenger.dart';
import 'package:air_sky/shared/empty_state_view.dart';
import 'package:air_sky/shared/ticket_card.dart';
import 'package:air_sky/shared/ticket_shimmer_list.dart';

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  Widget _backLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          context.pop();
          return;
        }
        context.go(RoutePaths.home);
      },
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isGuest = ref.watch(guestModeProvider);
    final bookingsAsync = ref.watch(userBookingsProvider);

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(
          leading: _backLeading(context),
          title: const Text('My Trips'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const EmptyStateView(
                  title: 'Guest mode active',
                  subtitle:
                      'Sign in to access synced bookings and QR trip tickets.',
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await goToLoginFromGuestSession(context, ref);
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in to continue'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: _backLeading(context),
          title: const Text('My Trips'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push(RoutePaths.notifications),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          loading: () => const TicketShimmerList(),
          error: (Object _, StackTrace stackTrace) => const EmptyStateView(
            title: 'Could not load trips',
            subtitle:
                'We could not load your trips right now. Please try again.',
            icon: Icons.error_outline_rounded,
          ),
          data: (List<Booking> bookings) {
            final DateTime now = DateTime.now();
            final List<Booking> upcoming = bookings
                .where(
                  (Booking booking) =>
                      booking.flight.departureTime.isAfter(now),
                )
                .toList();
            final List<Booking> completed = bookings
                .where(
                  (Booking booking) =>
                      !booking.flight.departureTime.isAfter(now),
                )
                .toList();

            return TabBarView(
              children: <Widget>[
                _TripsList(
                  bookings: upcoming,
                  emptyLabel: 'No upcoming trips yet.',
                ),
                _TripsList(
                  bookings: completed,
                  emptyLabel: 'No completed trips yet.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TripsList extends ConsumerWidget {
  const _TripsList({required this.bookings, required this.emptyLabel});

  final List<Booking> bookings;
  final String emptyLabel;

  String _normalizeReference(String value) {
    return value.trim().toUpperCase();
  }

  Future<String?> _askTransactionReference(BuildContext context) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          const _TransactionReferenceDialog(),
    );

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return _normalizeReference(value);
  }

  Future<bool> _askCancelConfirmation(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel booking?'),
          content: const Text(
            'This will move the booking to cancelled status and keep it in your trip history.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<_BookingEditResult?> _askEditBooking(
    BuildContext context,
    Booking booking,
  ) async {
    return showDialog<_BookingEditResult>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _EditBookingDialog(booking: booking);
      },
    );
  }

  String _startPaymentErrorMessage(Object error) {
    final String raw = error.toString();
    if (raw.contains('Verification already in progress')) {
      return 'AirSky: Verification is already running.';
    }
    if (raw.contains('Verification timer ended')) {
      return 'AirSky: Enter transaction reference to verify payment.';
    }
    if (raw.contains('Payment already completed')) {
      return 'AirSky: This booking is already paid.';
    }
    if (raw.contains('Payment window expired')) {
      return 'AirSky: Payment window expired.';
    }
    if (raw.contains('Payment is unavailable')) {
      return 'AirSky: Payment is unavailable for this booking.';
    }
    return 'AirSky: Could not start payment.';
  }

  String _confirmPaymentErrorMessage(Object error) {
    final String raw = error.toString();
    if (raw.contains('Verification in progress')) {
      return 'AirSky: Wait until verification timer ends.';
    }
    if (raw.contains('valid transaction reference')) {
      return 'AirSky: Enter reference as TXN-AB12CD34.';
    }
    if (raw.contains('Start payment first')) {
      return 'AirSky: Start payment before confirmation.';
    }
    if (raw.contains('session is invalid')) {
      return 'AirSky: Payment session expired. Start again.';
    }
    if (raw.contains('Payment window expired')) {
      return 'AirSky: Payment window expired.';
    }
    return 'AirSky: Could not verify payment.';
  }

  String _cancelBookingErrorMessage(Object error) {
    final String raw = error.toString();
    if (raw.contains('Only upcoming bookings can be cancelled')) {
      return 'AirSky: Only upcoming bookings can be cancelled.';
    }
    if (raw.contains('Booking not found')) {
      return 'AirSky: Booking was not found.';
    }
    return 'AirSky: Could not cancel booking.';
  }

  String _editErrorMessage(Object error) {
    final String raw = error.toString();
    if (raw.contains('Only unpaid bookings can be edited')) {
      return 'AirSky: Only unpaid bookings can be edited.';
    }
    if (raw.contains('Only upcoming bookings can be edited')) {
      return 'AirSky: Only upcoming bookings can be edited.';
    }
    if (raw.contains('unique seat')) {
      return 'AirSky: Each passenger must have a unique seat.';
    }
    if (raw.contains('match passenger count')) {
      return 'AirSky: Seat count must match passengers.';
    }
    if (raw.contains('Passenger details are required')) {
      return 'AirSky: Fill all passenger details before saving.';
    }
    if (raw.contains('Passenger count cannot be changed')) {
      return 'AirSky: Passenger count cannot be changed.';
    }
    return 'AirSky: Could not edit booking.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) {
      return EmptyStateView(
        title: 'No trips',
        subtitle: emptyLabel,
        icon: Icons.airplane_ticket_outlined,
      );
    }

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (BuildContext context, int index) {
        final Booking booking = bookings[index];
        return TicketCard(
          booking: booking,
          onPayNow: booking.isCancelled || booking.paymentStatus != 'unpaid'
              ? null
              : () async {
                  try {
                    await ref
                        .read(bookingRepositoryProvider)
                        .startPayment(
                          userId: booking.userId,
                          bookingId: booking.bookingId,
                        );

                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        'AirSky: Payment started. Complete verification to continue.',
                        type: AppFeedbackType.success,
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        _startPaymentErrorMessage(error),
                        type: AppFeedbackType.error,
                      );
                    }
                  }
                },
            onConfirmPayment:
              booking.isCancelled || booking.paymentStatus != 'payment_processing'
              ? null
              : () async {
                  try {
                    final String? reference = await _askTransactionReference(
                      context,
                    );
                    if (reference == null) {
                      return;
                    }

                    await Future<void>.delayed(const Duration(milliseconds: 800));

                    await ref
                        .read(bookingRepositoryProvider)
                        .confirmPayment(
                          userId: booking.userId,
                          bookingId: booking.bookingId,
                          transactionReference: reference,
                        );

                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        'AirSky: Payment verified.',
                        type: AppFeedbackType.success,
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        _confirmPaymentErrorMessage(error),
                        type: AppFeedbackType.error,
                      );
                    }
                  }
                },
          onEditBooking:
              booking.isCancelled ||
                  !booking.isUpcoming ||
                  booking.paymentStatus != 'unpaid'
              ? null
              : () async {
                  final _BookingEditResult? editResult = await _askEditBooking(
                    context,
                    booking,
                  );
                  if (editResult == null) {
                    return;
                  }

                  try {
                    await ref
                        .read(bookingRepositoryProvider)
                        .editBooking(
                          userId: booking.userId,
                          bookingId: booking.bookingId,
                          passengers: editResult.passengers,
                          seatNumbers: editResult.seatNumbers,
                        );

                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        'AirSky: Booking updated.',
                        type: AppFeedbackType.success,
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        _editErrorMessage(error),
                        type: AppFeedbackType.error,
                      );
                    }
                  }
                },
          onCancelBooking: booking.isCancelled || !booking.isUpcoming
              ? null
              : () async {
                  final bool confirmed = await _askCancelConfirmation(context);
                  if (!confirmed) {
                    return;
                  }

                  try {
                    await ref
                        .read(bookingRepositoryProvider)
                        .cancelBooking(
                          userId: booking.userId,
                          bookingId: booking.bookingId,
                        );

                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        'AirSky: Booking cancelled.',
                        type: AppFeedbackType.success,
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppFeedback(
                        context,
                        _cancelBookingErrorMessage(error),
                        type: AppFeedbackType.error,
                      );
                    }
                  }
                },
        );
      },
    );
  }
}

class _TransactionReferenceDialog extends StatefulWidget {
  const _TransactionReferenceDialog();

  static final RegExp _referencePattern = RegExp(r'^TXN-[A-Z0-9]{8,20}$');

  @override
  State<_TransactionReferenceDialog> createState() =>
      _TransactionReferenceDialogState();
}

class _BookingEditResult {
  const _BookingEditResult({
    required this.passengers,
    required this.seatNumbers,
  });

  final List<Passenger> passengers;
  final List<String> seatNumbers;
}

class _EditablePassengerFields {
  _EditablePassengerFields(Passenger passenger)
    : firstName = TextEditingController(text: passenger.firstName),
      lastName = TextEditingController(text: passenger.lastName),
      email = TextEditingController(text: passenger.email),
      phone = TextEditingController(text: passenger.phone),
      nationality = TextEditingController(text: passenger.nationality),
      passportNumber = TextEditingController(text: passenger.passportNumber);

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController nationality;
  final TextEditingController passportNumber;

  Passenger toPassenger() {
    return Passenger(
      firstName: firstName.text.trim(),
      lastName: lastName.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      nationality: nationality.text.trim(),
      passportNumber: passportNumber.text.trim(),
    );
  }

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    nationality.dispose();
    passportNumber.dispose();
  }
}

class _EditBookingDialog extends StatefulWidget {
  const _EditBookingDialog({required this.booking});

  final Booking booking;

  @override
  State<_EditBookingDialog> createState() => _EditBookingDialogState();
}

class _EditBookingDialogState extends State<_EditBookingDialog> {
  static const Set<String> _reservedSeats = <String>{
    '1C',
    '2D',
    '4B',
    '5A',
    '7F',
    '9C',
    '10E',
  };

  late final List<_EditablePassengerFields> _passengerFields;
  late List<String> _selectedSeats;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _passengerFields = widget.booking.passengers
        .map((Passenger value) => _EditablePassengerFields(value))
        .toList(growable: false);
    _selectedSeats = widget.booking.seatNumbers
        .map((String value) => value.trim().toUpperCase())
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final _EditablePassengerFields fields in _passengerFields) {
      fields.dispose();
    }
    super.dispose();
  }

  List<Passenger> get _passengers => _passengerFields
      .map((_EditablePassengerFields value) => value.toPassenger())
      .toList(growable: false);

  List<String> get _normalizedSeats => _selectedSeats
      .map((String value) => value.trim().toUpperCase())
      .toList(growable: false);

  bool _isEmailValid(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String? _validate() {
    for (final Passenger passenger in _passengers) {
      final String first = passenger.firstName.trim();
      final String last = passenger.lastName.trim();
      final String email = passenger.email.trim();
      final String phone = passenger.phone.trim();
      final String nationality = passenger.nationality.trim();
      final String passport = passenger.passportNumber.trim();

      if (first.isEmpty ||
          last.isEmpty ||
          email.isEmpty ||
          phone.isEmpty ||
          nationality.isEmpty ||
          passport.isEmpty) {
        return 'All passenger fields are required.';
      }

      if (first.length < 2 || last.length < 2) {
        return 'Passenger names must be at least 2 characters.';
      }

      if (!_isEmailValid(email)) {
        return 'Enter valid passenger email addresses.';
      }

      final String digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7) {
        return 'Enter a valid passenger phone number.';
      }

      if (nationality.length < 2) {
        return 'Enter a valid nationality.';
      }

      if (passport.length < 6) {
        return 'Passport number must be at least 6 characters.';
      }
    }

    if (_normalizedSeats.length != _passengers.length) {
      return 'Seat count must match passenger count.';
    }
    if (_normalizedSeats.any((String value) => value.isEmpty)) {
      return 'Select seats for all passengers.';
    }
    if (_normalizedSeats.toSet().length != _normalizedSeats.length) {
      return 'Each passenger must have a unique seat.';
    }

    return null;
  }

  Future<void> _openSeatPicker() async {
    final List<String>? seats = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _SeatPickerDialog(
          passengers: _passengers,
          initialSeats: _normalizedSeats,
          reservedSeats: _reservedSeats,
        );
      },
    );

    if (seats == null) {
      return;
    }

    setState(() {
      _selectedSeats = seats;
      _validationMessage = null;
    });
  }

  void _save() {
    final String? message = _validate();
    if (message != null) {
      setState(() {
        _validationMessage = message;
      });
      return;
    }

    Navigator.of(context).pop(
      _BookingEditResult(
        passengers: _passengers,
        seatNumbers: _normalizedSeats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit booking'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (
                int index = 0;
                index < _passengerFields.length;
                index++
              ) ...<Widget>[
                if (index > 0) const Divider(height: 24),
                Text(
                  'Passenger ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passengerFields[index].firstName,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _validationMessage = null),
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passengerFields[index].lastName,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _validationMessage = null),
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passengerFields[index].email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() => _validationMessage = null),
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passengerFields[index].phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() => _validationMessage = null),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passengerFields[index].nationality,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _validationMessage = null),
                  decoration: const InputDecoration(labelText: 'Nationality'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passengerFields[index].passportNumber,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() => _validationMessage = null),
                  decoration: const InputDecoration(
                    labelText: 'Passport number',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Seats: ${_normalizedSeats.join(', ')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openSeatPicker,
                icon: const Icon(Icons.event_seat_outlined),
                label: const Text('Change seats'),
              ),
              if (_validationMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _validationMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save changes')),
      ],
    );
  }
}

class _SeatPickerDialog extends StatefulWidget {
  const _SeatPickerDialog({
    required this.passengers,
    required this.initialSeats,
    required this.reservedSeats,
  });

  final List<Passenger> passengers;
  final List<String> initialSeats;
  final Set<String> reservedSeats;

  @override
  State<_SeatPickerDialog> createState() => _SeatPickerDialogState();
}

class _SeatPickerDialogState extends State<_SeatPickerDialog> {
  static const List<String> _leftColumns = <String>['A', 'B', 'C'];
  static const List<String> _rightColumns = <String>['D', 'E', 'F'];

  late List<String> _selectedSeats;
  int _focusedPassengerIndex = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSeats = List<String>.from(widget.initialSeats, growable: false);
    _focusedPassengerIndex = _nextSeatFocusIndex(_selectedSeats);
  }

  int _nextSeatFocusIndex(List<String> seats) {
    for (int i = 0; i < widget.passengers.length; i++) {
      final String seat = i < seats.length ? seats[i].trim() : '';
      if (seat.isEmpty) {
        return i;
      }
    }
    if (_focusedPassengerIndex < widget.passengers.length) {
      return _focusedPassengerIndex;
    }
    return widget.passengers.length - 1;
  }

  void _selectSeat(String seatCode) {
    if (_focusedPassengerIndex >= _selectedSeats.length) {
      return;
    }

    final List<String> seats = List<String>.from(_selectedSeats);
    seats[_focusedPassengerIndex] = seatCode;

    setState(() {
      _selectedSeats = seats;
      _focusedPassengerIndex = _nextSeatFocusIndex(seats);
      _errorMessage = null;
    });
  }

  void _save() {
    if (_selectedSeats.any((String value) => value.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Select seats for all passengers.';
      });
      return;
    }

    if (_selectedSeats.toSet().length != _selectedSeats.length) {
      setState(() {
        _errorMessage = 'Each passenger must have a unique seat.';
      });
      return;
    }

    Navigator.of(context).pop(
      _selectedSeats
          .map((String value) => value.trim().toUpperCase())
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int travelerCount = widget.passengers.length;

    final int effectiveFocusIndex = _focusedPassengerIndex < travelerCount
        ? _focusedPassengerIndex
        : travelerCount - 1;
    final String focusedSeat = effectiveFocusIndex < _selectedSeats.length
        ? _selectedSeats[effectiveFocusIndex]
        : '';

    Widget buildSeat(String column, int row, double size) {
      final String seatCode = '$row$column';
      final bool isReserved = widget.reservedSeats.contains(seatCode);
      final int assignedIndex = _selectedSeats.indexOf(seatCode);
      final bool isSelected = assignedIndex == effectiveFocusIndex;
      final bool isAssignedToOther =
          assignedIndex != -1 && assignedIndex != effectiveFocusIndex;

      return _EditSeatCell(
        label: seatCode,
        size: size,
        isReserved: isReserved,
        isSelected: isSelected,
        isAssignedToOtherPassenger: isAssignedToOther,
        onTap: isReserved || isAssignedToOther
            ? null
            : () => _selectSeat(seatCode),
      );
    }

    return AlertDialog(
      title: const Text('Select seats'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Assign seats',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (focusedSeat.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Passenger ${effectiveFocusIndex + 1}: $focusedSeat',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(travelerCount, (int index) {
                  final String seat = index < _selectedSeats.length
                      ? _selectedSeats[index].trim()
                      : '';
                  final bool isFocused = index == effectiveFocusIndex;
                  final String name = widget.passengers[index].fullName;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _focusedPassengerIndex = index;
                      });
                    },
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? theme.colorScheme.primary.withValues(alpha: 0.14)
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Passenger ${index + 1}: ${seat.isEmpty ? 'Select seat' : seat}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isFocused
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 180,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: <Widget>[
                  _EditSeatLegend(
                    label: 'Available',
                    color: theme.colorScheme.surface,
                  ),
                  _EditSeatLegend(
                    label: 'Selected passenger',
                    color: theme.colorScheme.primary,
                  ),
                  _EditSeatLegend(
                    label: 'Assigned to others',
                    color: theme.colorScheme.secondaryContainer,
                  ),
                  _EditSeatLegend(
                    label: 'Reserved',
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.52,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          const double seatGap = 6;
                          const double aisleGap = 26;
                          final double seatSize =
                              ((constraints.maxWidth -
                                          (seatGap * 4) -
                                          aisleGap) /
                                      6)
                                  .clamp(24, 34);

                          Widget seatLetter(String value) {
                            return SizedBox(
                              width: seatSize,
                              child: Text(
                                value,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: <Widget>[
                              Text(
                                'Front',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  seatLetter('A'),
                                  const SizedBox(width: seatGap),
                                  seatLetter('B'),
                                  const SizedBox(width: seatGap),
                                  seatLetter('C'),
                                  const SizedBox(width: aisleGap),
                                  seatLetter('D'),
                                  const SizedBox(width: seatGap),
                                  seatLetter('E'),
                                  const SizedBox(width: seatGap),
                                  seatLetter('F'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              for (int row = 1; row <= 10; row++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      for (
                                        int i = 0;
                                        i < _leftColumns.length;
                                        i++
                                      ) ...<Widget>[
                                        buildSeat(
                                          _leftColumns[i],
                                          row,
                                          seatSize,
                                        ),
                                        if (i != _leftColumns.length - 1)
                                          const SizedBox(width: seatGap),
                                      ],
                                      const SizedBox(width: aisleGap),
                                      for (
                                        int i = 0;
                                        i < _rightColumns.length;
                                        i++
                                      ) ...<Widget>[
                                        buildSeat(
                                          _rightColumns[i],
                                          row,
                                          seatSize,
                                        ),
                                        if (i != _rightColumns.length - 1)
                                          const SizedBox(width: seatGap),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedSeats
                            .where((String value) => value.trim().isNotEmpty)
                            .length ==
                        travelerCount
                    ? 'All seats assigned. You can save.'
                    : 'Tap an available seat for Passenger ${effectiveFocusIndex + 1}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Use seats')),
      ],
    );
  }
}

class _EditSeatCell extends StatelessWidget {
  const _EditSeatCell({
    required this.label,
    required this.size,
    required this.isReserved,
    required this.isSelected,
    required this.isAssignedToOtherPassenger,
    this.onTap,
  });

  final String label;
  final double size;
  final bool isReserved;
  final bool isSelected;
  final bool isAssignedToOtherPassenger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color fill = isReserved
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.48)
        : isAssignedToOtherPassenger
        ? theme.colorScheme.secondaryContainer
        : isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;

    final Color border = isReserved
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.48)
        : isAssignedToOtherPassenger
        ? theme.colorScheme.secondary
        : isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    final Color text = isReserved || isSelected || isAssignedToOtherPassenger
        ? Colors.white
        : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSeatLegend extends StatelessWidget {
  const _EditSeatLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _TransactionReferenceDialogState
    extends State<_TransactionReferenceDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool get _canSubmit =>
      _TransactionReferenceDialog._referencePattern.hasMatch(_normalizedValue);

  String get _normalizedValue => _controller.text.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'TXN-');
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm payment'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLength: 24,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
        ],
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Transaction reference',
          hintText: 'TXN-AB12CD34',
          helperText: 'Format: TXN- + 8 to 20 letters/digits',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(_normalizedValue)
              : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}



