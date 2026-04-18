import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/utils/account_required_prompt.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';
import 'package:air_sky/features/flights/presentation/widgets/flight_filter_bottom_sheet.dart';
import 'package:air_sky/features/flights/presentation/controllers/flight_search_controller.dart';
import 'package:air_sky/shared/widgets/empty_state_view.dart';
import 'package:air_sky/shared/widgets/flight_result_card.dart';
import 'package:air_sky/shared/widgets/flight_shimmer_list.dart';

class FlightResultsScreen extends ConsumerStatefulWidget {
  const FlightResultsScreen({super.key});

  @override
  ConsumerState<FlightResultsScreen> createState() =>
      _FlightResultsScreenState();
}

class _FlightResultsScreenState extends ConsumerState<FlightResultsScreen> {
  static const int _pageSize = 8;
  static const int _guestMaxResults = 4;
  int _visibleCount = _pageSize;

  Future<void> _showAccountRequired() {
    return showAccountRequiredPrompt(
      context,
      ref,
      featureLabel: 'sort, filter, view flight details, and book tickets',
    );
  }

  Future<void> _openFilters(FlightSearchState state) async {
    final FlightSearchController controller = ref.read(
      flightSearchControllerProvider.notifier,
    );

    final FlightFilterSelection? result =
        await showModalBottomSheet<FlightFilterSelection>(
          context: context,
          showDragHandle: true,
          builder: (_) => FlightFilterBottomSheet(
            maxStops: state.maxStops,
            maxPrice: state.maxPrice,
          ),
        );

    if (result != null) {
      controller.applyFilters(
        maxStops: result.maxStops,
        maxPrice: result.maxPrice,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final state = ref.read(flightSearchControllerProvider);
      if (state.allFlights.isEmpty) {
        ref.read(flightSearchControllerProvider.notifier).loadCachedResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flightSearchControllerProvider);
    final controller = ref.read(flightSearchControllerProvider.notifier);
    final bool isGuest = ref.watch(guestModeProvider);
    final ThemeData theme = Theme.of(context);
    final int totalFlights = state.visibleFlights.length;
    final int displayedCount = isGuest
        ? (totalFlights < _guestMaxResults ? totalFlights : _guestMaxResults)
        : (totalFlights < _visibleCount ? totalFlights : _visibleCount);
    final List<Flight> displayedFlights = state.visibleFlights
        .take(displayedCount)
        .toList();
    final bool canShowMore = !isGuest && displayedCount < totalFlights;

    return Scaffold(
      appBar: AppBar(title: const Text('Flight Results')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<FlightSortOption>(
                    segments: const <ButtonSegment<FlightSortOption>>[
                      ButtonSegment<FlightSortOption>(
                        value: FlightSortOption.cheapest,
                        label: Text('Cheapest'),
                        icon: Icon(Icons.attach_money_rounded),
                      ),
                      ButtonSegment<FlightSortOption>(
                        value: FlightSortOption.fastest,
                        label: Text('Fastest'),
                        icon: Icon(Icons.bolt_rounded),
                      ),
                    ],
                    selected: <FlightSortOption>{state.sortOption},
                    onSelectionChanged:
                        (Set<FlightSortOption> selection) async {
                          if (isGuest) {
                            await _showAccountRequired();
                            return;
                          }
                          controller.sortBy(selection.first);
                        },
                  ),
                ),
              ],
            ),
          ),
          if (isGuest)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Guest mode: showing limited results. Sign in for details, filters, and booking.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
            child: Row(
              children: <Widget>[
                Text(
                  '$displayedCount of $totalFlights flights shown',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (state.maxStops != null || state.maxPrice != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      'Filters active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (state.fromCache)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Text('Showing cached last search results.'),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (state.isLoading) {
                  return const FlightShimmerList();
                }

                if (state.visibleFlights.isEmpty) {
                  return const EmptyStateView(
                    title: 'No flights found',
                    subtitle:
                        'Try changing filters, route, date, or passenger count.',
                    icon: Icons.flight_land_rounded,
                  );
                }

                return ListView.builder(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemCount: displayedFlights.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Flight flight = displayedFlights[index];
                    return FlightResultCard(
                      flight: flight,
                      onTap: () async {
                        if (isGuest) {
                          await _showAccountRequired();
                          return;
                        }
                        context.push(RoutePaths.flightDetails, extra: flight);
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (canShowMore)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visibleCount += _pageSize;
                            });
                          },
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            'Show more (${totalFlights - displayedCount} remaining)',
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (isGuest) {
                              await _showAccountRequired();
                              return;
                            }
                            _openFilters(state);
                          },
                          icon: const Icon(Icons.filter_alt_rounded),
                          label: const Text('Filter'),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              context.pop();
                              return;
                            }
                            context.go(RoutePaths.search);
                          },
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Modify Search'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
