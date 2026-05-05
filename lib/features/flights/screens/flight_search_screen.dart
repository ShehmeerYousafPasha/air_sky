import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/features/ai_assistant/ai_assistant_entry_point.dart';
import 'package:air_sky/features/flights/components/flight_search_form_card.dart';

class FlightSearchScreen extends ConsumerWidget {
  const FlightSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isGuest = ref.watch(guestModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find Flights')),
      body: Stack(
        children: <Widget>[
          ListView(
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
          const AiAssistantEntryPoint(),
        ],
      ),
    );
  }
}



