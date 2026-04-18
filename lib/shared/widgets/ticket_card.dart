import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/core/theme/app_theme.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/features/booking/domain/entities/booking.dart';

class TicketCard extends StatefulWidget {
  const TicketCard({
    super.key,
    required this.booking,
    this.onPayNow,
    this.onConfirmPayment,
  });

  final Booking booking;
  final Future<void> Function()? onPayNow;
  final Future<void> Function()? onConfirmPayment;

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  bool _expanded = false;
  Timer? _processingTicker;

  static const Duration _processingWindow = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _syncProcessingTicker();
  }

  @override
  void didUpdateWidget(covariant TicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.paymentStatus != widget.booking.paymentStatus ||
        oldWidget.booking.providerTransactionId !=
            widget.booking.providerTransactionId) {
      _syncProcessingTicker();
    }
  }

  @override
  void dispose() {
    _processingTicker?.cancel();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  void _syncProcessingTicker() {
    _processingTicker?.cancel();

    if (widget.booking.paymentStatus != 'payment_processing') {
      return;
    }

    _processingTicker = Timer.periodic(const Duration(seconds: 1), (
      Timer timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {});
      if (_isCountdownComplete(widget.booking)) {
        timer.cancel();
      }
    });
  }

  int? _extractStartedAtMillis(String providerTransactionId) {
    final List<String> parts = providerTransactionId.split('-');
    if (parts.length < 3 || parts.first != 'DUMMY') {
      return null;
    }
    return int.tryParse(parts[1]);
  }

  Duration _remainingProcessingTime(Booking booking) {
    final int? startedAtMs = _extractStartedAtMillis(
      booking.providerTransactionId ?? '',
    );

    if (startedAtMs == null) {
      return Duration.zero;
    }

    final int readyAtMs = startedAtMs + _processingWindow.inMilliseconds;
    final int remainingMs = readyAtMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      return Duration.zero;
    }

    return Duration(milliseconds: remainingMs);
  }

  bool _isCountdownComplete(Booking booking) {
    return _remainingProcessingTime(booking) <= Duration.zero;
  }

  String _formatCountdown(Duration duration) {
    final int totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Booking booking = widget.booking;
    final bool upcoming = booking.status == 'upcoming';
    final bool isPaid = booking.isPaid;
    final bool isProcessing = booking.paymentStatus == 'payment_processing';
    final Duration processingRemaining = isProcessing
        ? _remainingProcessingTime(booking)
        : Duration.zero;
    final bool canConfirmProcessing =
        isProcessing && _isCountdownComplete(booking);
    final String processingLabel = canConfirmProcessing
        ? 'Ready to confirm'
        : 'Confirm in ${_formatCountdown(processingRemaining)}';
    final double qrSize = (MediaQuery.sizeOf(context).width * 0.46).clamp(
      150.0,
      210.0,
    );

    final Color badgeColor = upcoming
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final Color badgeBackground = upcoming
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest;

    final Color paymentBadgeColor = isPaid
        ? AppTheme.success
        : isProcessing
        ? theme.colorScheme.primary
        : const Color(0xFFB45309);
    final Color paymentBadgeBackground = isPaid
        ? AppTheme.success.withValues(alpha: 0.15)
        : isProcessing
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : const Color(0xFFB45309).withValues(alpha: 0.14);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: AppTheme.softShadows(context),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.85),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      booking.bookingId,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBackground,
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          upcoming ? 'UPCOMING' : 'COMPLETED',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: badgeColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: paymentBadgeBackground,
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          isPaid
                              ? 'PAID'
                              : (isProcessing ? 'PROCESSING' : 'UNPAID'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: paymentBadgeColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      booking.flight.fromAirport,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.flight_takeoff_rounded,
                    size: 18.sp,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      booking.flight.toAirport,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                '${booking.flight.departureTime.toTicketDate()}  ${booking.flight.departureTime.toTimeLabel()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isPaid
                    ? 'Tap expand to view ticket and QR.'
                    : (isProcessing
                          ? 'Verification in progress. Confirm after timer ends.'
                          : 'Payment pending. Expand to view PSID details.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isProcessing) ...<Widget>[
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.timer_outlined,
                        size: 14.sp,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        processingLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 2.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _toggleExpanded,
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(
                    _expanded
                        ? (isPaid ? 'Collapse ticket' : 'Hide payment')
                        : (isPaid
                              ? 'Expand ticket'
                              : (isProcessing
                                    ? 'Payment status'
                                    : 'View payment')),
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: isPaid
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Divider(height: 1.h),
                          SizedBox(height: 10.h),
                          Wrap(
                            spacing: 14.w,
                            runSpacing: 8.h,
                            children: <Widget>[
                              _InfoChip(
                                icon: Icons.person_outline_rounded,
                                label: booking.passenger.fullName,
                              ),
                              _InfoChip(
                                icon: Icons.event_seat_outlined,
                                label: 'Seat ${booking.seatNumber}',
                              ),
                              _InfoChip(
                                icon: Icons.payments_outlined,
                                label: PriceFormatter.format(booking.amount),
                                isEmphasis: true,
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),
                          Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(10.w),
                                child: QrImageView(
                                  data:
                                      '${booking.bookingId}|${booking.flight.id}|${booking.passenger.fullName}',
                                  size: qrSize,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Divider(height: 1.h),
                          SizedBox(height: 10.h),
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 8.h,
                            children: <Widget>[
                              _InfoChip(
                                icon: Icons.receipt_long_outlined,
                                label: booking.psid,
                              ),
                              _InfoChip(
                                icon: Icons.payments_outlined,
                                label: PriceFormatter.format(booking.amount),
                                isEmphasis: true,
                              ),
                              _InfoChip(
                                icon: Icons.schedule_rounded,
                                label: booking.paymentDueAt == null
                                    ? 'Due: -'
                                    : 'Due ${booking.paymentDueAt!.toTicketDate()}',
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            isProcessing
                                ? 'After paying PSID, confirm with reference \ne.g: (TXN-AB12CD34).'
                                : 'Use Pay now to start payment verification.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isProcessing) ...<Widget>[
                            SizedBox(height: 8.h),
                            Text(
                              canConfirmProcessing
                                  ? 'Timer complete. Confirm payment now.'
                                  : 'Timer: ${_formatCountdown(processingRemaining)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          SizedBox(height: 10.h),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: booking.psid.trim().isEmpty
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: booking.psid),
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          showAppFeedback(
                                            context,
                                            'AirSky: PSID copied.',
                                            type: AppFeedbackType.success,
                                          );
                                        },
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy PSID'),
                                ),
                              ),
                              if (isProcessing &&
                                  widget.onConfirmPayment != null) ...<Widget>[
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: canConfirmProcessing
                                        ? () async {
                                            await widget.onConfirmPayment!
                                                .call();
                                          }
                                        : null,
                                    icon: Icon(
                                      canConfirmProcessing
                                          ? Icons.verified_rounded
                                          : Icons.timer_rounded,
                                    ),
                                    label: Text(
                                      canConfirmProcessing
                                          ? 'Verify payment'
                                          : _formatCountdown(
                                              processingRemaining,
                                            ),
                                    ),
                                  ),
                                ),
                              ] else if (widget.onPayNow != null) ...<Widget>[
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      await widget.onPayNow!.call();
                                    },
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('Pay now'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.isEmphasis = false,
  });

  final IconData icon;
  final String label;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: isEmphasis
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14.sp,
            color: isEmphasis
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isEmphasis
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: isEmphasis ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
