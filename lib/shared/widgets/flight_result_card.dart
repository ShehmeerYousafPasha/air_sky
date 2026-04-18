import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:air_sky/core/theme/app_theme.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';

class FlightResultCard extends StatefulWidget {
  const FlightResultCard({
    super.key,
    required this.flight,
    required this.onTap,
    this.badges = const <String>[],
  });

  final Flight flight;
  final VoidCallback onTap;
  final List<String> badges;

  @override
  State<FlightResultCard> createState() => _FlightResultCardState();
}

class _FlightResultCardState extends State<FlightResultCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: AppTheme.softShadows(context),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.48 : 0.92,
              ),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18.r),
            onTap: widget.onTap,
            onHighlightChanged: (bool value) {
              setState(() {
                _pressed = value;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: CachedNetworkImage(
                          imageUrl: widget.flight.airlineLogo,
                          width: 44.w,
                          height: 44.w,
                          fit: BoxFit.cover,
                          errorWidget:
                              (
                                BuildContext context,
                                String url,
                                Object error,
                              ) => Container(
                                width: 44.w,
                                height: 44.w,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.flight),
                              ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.flight.airline,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              widget.flight.cabinClass,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.badges.isNotEmpty) ...<Widget>[
                              SizedBox(height: 6.h),
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 6.h,
                                children: widget.badges
                                    .map(
                                      (String badge) =>
                                          _FlightBadge(label: badge),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          widget.flight.stopsLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _AirportTimeColumn(
                          airportCode: widget.flight.fromAirport,
                          timeLabel: widget.flight.departureTime.toTimeLabel(),
                          alignment: CrossAxisAlignment.start,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.flight.durationLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: theme.colorScheme.outlineVariant,
                                    height: 1,
                                  ),
                                ),
                                Icon(
                                  Icons.flight_rounded,
                                  size: 14.sp,
                                  color: theme.colorScheme.primary,
                                ),
                                Expanded(
                                  child: Divider(
                                    color: theme.colorScheme.outlineVariant,
                                    height: 1,
                                  ),
                                ),
                                Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _AirportTimeColumn(
                          airportCode: widget.flight.toAirport,
                          timeLabel: widget.flight.arrivalTime.toTimeLabel(),
                          alignment: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 9.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: isDark ? 0.35 : 0.45),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.local_offer_outlined,
                          size: 16.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'Best available fare',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          PriceFormatter.format(widget.flight.price),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlightBadge extends StatelessWidget {
  const _FlightBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AirportTimeColumn extends StatelessWidget {
  const _AirportTimeColumn({
    required this.airportCode,
    required this.timeLabel,
    required this.alignment,
  });

  final String airportCode;
  final String timeLabel;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final bool rightAligned = alignment == CrossAxisAlignment.end;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          airportCode,
          textAlign: rightAligned ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          timeLabel,
          textAlign: rightAligned ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
