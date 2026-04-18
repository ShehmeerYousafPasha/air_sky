import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/constants/app_constants.dart';
import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/theme/app_theme.dart';
import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/features/flights/domain/entities/flight_search_query.dart';
import 'package:air_sky/features/flights/presentation/controllers/search_form_controller.dart';
import 'package:air_sky/shared/widgets/airport_autocomplete_field.dart';
import 'package:air_sky/shared/widgets/app_primary_button.dart';

class FlightSearchFormCard extends ConsumerWidget {
  const FlightSearchFormCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchFormState form = ref.watch(searchFormControllerProvider);
    final SearchFormController controller = ref.read(
      searchFormControllerProvider.notifier,
    );
    final bool isGuest = ref.watch(guestModeProvider);
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: AppTheme.softShadows(context),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(17.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.travel_explore_rounded,
                    color: theme.colorScheme.primary,
                    size: 19.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Search flights',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            AirportAutocompleteField(
              label: 'From airport',
              initialValue: form.fromAirport,
              options: AppConstants.airports,
              onSelected: controller.setFromAirport,
              prefixIcon: Icons.flight_takeoff_rounded,
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.center,
              child: Tooltip(
                message: 'Swap airports',
                child: InkWell(
                  borderRadius: BorderRadius.circular(999.r),
                  onTap: controller.swapAirports,
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.24,
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      size: 22.sp,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            AirportAutocompleteField(
              label: 'To airport',
              initialValue: form.toAirport,
              options: AppConstants.airports,
              onSelected: controller.setToAirport,
              prefixIcon: Icons.flight_land_rounded,
            ),
            SizedBox(height: 12.h),
            InkWell(
              borderRadius: BorderRadius.circular(16.r),
              onTap: () async {
                final DateTime today = DateTime.now();
                final DateTime firstDate = DateTime(
                  today.year,
                  today.month,
                  today.day,
                );
                final DateTime? picked = await showDatePicker(
                  context: context,
                  firstDate: firstDate,
                  lastDate: firstDate.add(const Duration(days: 365)),
                  initialDate: form.date.isBefore(firstDate)
                      ? firstDate
                      : form.date,
                );
                if (picked != null) {
                  controller.setDate(picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Departure date',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                  suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                ),
                child: Text(
                  form.date.toShortDate(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            if (isGuest)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18.sp,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Guest mode: Economy, 1 passenger. Sign in for full search options.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget passengersField = InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Passengers',
                      prefixIcon: Icon(Icons.people_alt_outlined),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        IconButton(
                          constraints: BoxConstraints.tightFor(
                            width: 30.w,
                            height: 30.w,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 18.sp,
                          onPressed: controller.decreasePassengers,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${form.passengers}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          constraints: BoxConstraints.tightFor(
                            width: 30.w,
                            height: 30.w,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 18.sp,
                          onPressed: controller.increasePassengers,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  );

                  final Widget cabinClassField =
                      DropdownButtonFormField<String>(
                        initialValue: form.cabinClass,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          prefixIcon: Icon(Icons.airline_seat_recline_normal),
                        ),
                        items: AppConstants.cabinClasses
                            .map(
                              (String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            controller.setCabinClass(value);
                          }
                        },
                      );

                  final double halfWidth =
                      (constraints.maxWidth - 10.w).clamp(0, double.infinity) /
                      2;
                  final bool shouldStack = halfWidth < 180;

                  if (shouldStack) {
                    return Column(
                      children: <Widget>[
                        passengersField,
                        SizedBox(height: 10.h),
                        cabinClassField,
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(child: passengersField),
                      SizedBox(width: 10.w),
                      Expanded(child: cabinClassField),
                    ],
                  );
                },
              ),
            SizedBox(height: 16.h),
            AppPrimaryButton(
              label: 'Search Flights',
              icon: Icons.search_rounded,
              onPressed: () async {
                if (!form.isValid) {
                  showAppFeedback(
                    context,
                    'AirSky: Check route fields.',
                    type: AppFeedbackType.error,
                  );
                  return;
                }

                final FlightSearchQuery query = isGuest
                    ? FlightSearchQuery(
                        fromAirport: form.fromAirport,
                        toAirport: form.toAirport,
                        date: form.date,
                        passengers: 1,
                        cabinClass: 'Economy',
                      )
                    : form.toQuery();
                await ref
                    .read(flightSearchControllerProvider.notifier)
                    .searchFlights(query);
                await ref.read(recentSearchesProvider.notifier).refresh();
                if (isGuest && context.mounted) {
                  showAppFeedback(
                    context,
                    'AirSky: Guest search is limited. Sign in for full options.',
                    type: AppFeedbackType.general,
                  );
                }
                if (context.mounted) {
                  context.push(RoutePaths.results);
                }
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
  }
}
