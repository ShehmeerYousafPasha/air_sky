import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/features/flights/presentation/widgets/flight_search_form_card.dart';

class FlightSearchScreen extends ConsumerWidget {
  const FlightSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isGuest = ref.watch(guestModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find Flights')),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        children: <Widget>[
          Text(
            isGuest
                ? 'Guest mode allows basic route and date search only.'
                : 'Search by route, date, passenger count, and cabin class.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 10.h),
          const FlightSearchFormCard(),
        ],
      ),
    );
  }
}
