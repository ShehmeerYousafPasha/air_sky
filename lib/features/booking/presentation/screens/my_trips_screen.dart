import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/utils/account_required_prompt.dart';
import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/features/booking/domain/entities/booking.dart';
import 'package:air_sky/shared/widgets/empty_state_view.dart';
import 'package:air_sky/shared/widgets/ticket_card.dart';
import 'package:air_sky/shared/widgets/ticket_shimmer_list.dart';

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
          onPayNow: booking.paymentStatus != 'unpaid'
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
          onConfirmPayment: booking.paymentStatus != 'payment_processing'
              ? null
              : () async {
                  try {
                    final String? reference = await _askTransactionReference(
                      context,
                    );
                    if (reference == null) {
                      return;
                    }

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
