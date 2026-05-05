import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/route_paths.dart';
import 'package:air_sky/config/app_theme.dart';
import 'package:air_sky/utils/account_required_prompt.dart';
import 'package:air_sky/utils/date_time_utils.dart';
import 'package:air_sky/utils/price_formatter.dart';
import 'package:air_sky/features/ai_assistant/ai_assistant_entry_point.dart';
import 'package:air_sky/features/flights/models/flight.dart';
import 'package:air_sky/shared/app_primary_button.dart';

class FlightDetailsScreen extends ConsumerWidget {
  const FlightDetailsScreen({super.key, required this.flight});

  final Flight flight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isGuest = ref.watch(guestModeProvider);
    final ThemeData theme = Theme.of(context);
    final double baseFare = flight.price * 0.78;
    final double taxes = flight.price * 0.17;
    final double serviceFee = flight.price * 0.05;

    return Scaffold(
      appBar: AppBar(title: const Text('Flight details')),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: AppTheme.softShadows(context),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: CachedNetworkImage(
                          imageUrl: Flight.sanitizeAirlineLogo(
                            airline: flight.airline,
                            airlineLogo: flight.airlineLogo,
                          ),
                          width: 50.w,
                          height: 50.w,
                          fit: BoxFit.cover,
                          errorWidget:
                              (
                                BuildContext context,
                                String url,
                                Object error,
                              ) => Container(
                                width: 50.w,
                                height: 50.w,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.flight),
                              ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              flight.airline,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Flight ${flight.id}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        PriceFormatter.format(flight.price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              _SectionCard(
                title: 'Itinerary timeline',
                child: Column(
                  children: <Widget>[
                    _TimelineEntry(
                      airport: flight.fromAirport,
                      timeLabel:
                          '${flight.departureTime.toTicketDate()} ${flight.departureTime.toTimeLabel()}',
                      subtitle: 'Departure',
                      isFirst: true,
                    ),
                    ...flight.layovers.map(
                      (String stop) => _TimelineEntry(
                        airport: stop,
                        timeLabel: 'Layover stop',
                        subtitle: 'Transfer',
                      ),
                    ),
                    _TimelineEntry(
                      airport: flight.toAirport,
                      timeLabel:
                          '${flight.arrivalTime.toTicketDate()} ${flight.arrivalTime.toTimeLabel()}',
                      subtitle: 'Arrival',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              _SectionCard(
                title: 'Flight info',
                child: Column(
                  children: <Widget>[
                    _DetailRow(label: 'Duration', value: flight.durationLabel),
                    _DetailRow(label: 'Cabin', value: flight.cabinClass),
                    _DetailRow(label: 'Stops', value: flight.stopsLabel),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              _SectionCard(
                title: 'Price breakdown',
                child: Column(
                  children: <Widget>[
                    _DetailRow(
                      label: 'Base fare',
                      value: PriceFormatter.format(baseFare),
                    ),
                    _DetailRow(
                      label: 'Taxes',
                      value: PriceFormatter.format(taxes),
                    ),
                    _DetailRow(
                      label: 'Service fee',
                      value: PriceFormatter.format(serviceFee),
                    ),
                    Divider(height: 18.h),
                    _DetailRow(
                      label: 'Total',
                      value: PriceFormatter.format(flight.price),
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 80.h),
            ],
          ),
          const AiAssistantEntryPoint(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
          child: AppPrimaryButton(
            label: 'Book Flight',
            icon: Icons.airplane_ticket_rounded,
            onPressed: () async {
              if (isGuest) {
                await showAccountRequiredPrompt(
                  context,
                  ref,
                  featureLabel: 'book flights and access e-tickets',
                );
                return;
              }
              context.push(RoutePaths.booking, extra: flight);
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10.h),
            child,
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.airport,
    required this.timeLabel,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  final String airport;
  final String timeLabel;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: 70.h,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24.w,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  airport,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = isHighlighted
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}



