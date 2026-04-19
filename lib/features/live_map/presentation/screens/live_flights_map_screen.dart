import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:air_sky/features/live_map/domain/entities/live_flight.dart';
import 'package:air_sky/features/live_map/presentation/controllers/live_flights_controller.dart';

class LiveFlightsMapScreen extends ConsumerStatefulWidget {
  const LiveFlightsMapScreen({super.key});

  @override
  ConsumerState<LiveFlightsMapScreen> createState() =>
      _LiveFlightsMapScreenState();
}

class _LiveFlightsMapScreenState extends ConsumerState<LiveFlightsMapScreen> {
  static const LatLng _initialCenter = LatLng(30.3753, 69.3451);
  static const int _markerDisplayLimit = 180;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _isMapReady = false;
  String _searchQuery = '';
  LiveFlight? _selectedFlight;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    final LiveFlightsState state = ref.watch(liveFlightsControllerProvider);
    final ThemeData theme = Theme.of(context);
    final List<LiveFlight> filteredFlights = _filterFlights(
      state.flights,
      _searchQuery,
    );
    final List<LiveFlight> markerFlights = filteredFlights
        .take(_markerDisplayLimit)
        .toList(growable: false);
    final LiveFlight? selectedFlight = _resolveSelectedFlight(markerFlights);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 4.8,
              minZoom: 2,
              maxZoom: 12,
              onMapReady: () {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _isMapReady = true;
                });
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                retinaMode: RetinaMode.isHighDensity(context),
                subdomains: const <String>['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.airsky.bookandfly',
              ),
              MarkerLayer(
                markers: _buildMarkers(
                  context: context,
                  flights: markerFlights,
                  selectedIcao24: selectedFlight?.icao24,
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
              child: Column(
                children: <Widget>[
                  _TopLiveBar(
                    searchController: _searchController,
                    flightCount: markerFlights.length,
                    isRefreshing: state.isRefreshing,
                    lastUpdatedAt: state.lastUpdatedAt,
                    errorMessage: state.errorMessage,
                    onSearchChanged: (String value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const Spacer(),
                  if (selectedFlight != null)
                    _SelectedFlightCard(
                      flight: selectedFlight,
                      onClose: () {
                        setState(() {
                          _selectedFlight = null;
                        });
                      },
                    ),
                  SizedBox(height: 8.h),
                  _TrackedFlightsPanel(
                    flights: markerFlights.take(12).toList(growable: false),
                    selectedIcao24: selectedFlight?.icao24,
                    onFlightTap: _focusFlight,
                  ),
                ],
              ),
            ),
          ),
          if (state.isInitialLoading)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.75),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          if (!state.isInitialLoading && markerFlights.isEmpty)
            Positioned.fill(
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No flights match "$_searchQuery" right now.'
                        : (state.errorMessage ??
                              'No live flights available in this region right now.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Refresh radar',
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        onPressed: state.isRefreshing
            ? null
            : () => ref
                  .read(liveFlightsControllerProvider.notifier)
                  .resetRateLimitAndRefresh(),
        child: state.isRefreshing
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh_rounded),
      ),
    );
  }

  List<LiveFlight> _filterFlights(List<LiveFlight> flights, String query) {
    if (query.isEmpty) {
      return flights;
    }

    return flights
        .where((LiveFlight flight) {
          return flight.displayCallsign.toLowerCase().contains(query) ||
              flight.displayOriginCountry.toLowerCase().contains(query) ||
              flight.icao24.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  LiveFlight? _resolveSelectedFlight(List<LiveFlight> markerFlights) {
    final String? selectedIcao24 = _selectedFlight?.icao24;
    if (selectedIcao24 == null) {
      return null;
    }

    for (final LiveFlight flight in markerFlights) {
      if (flight.icao24 == selectedIcao24) {
        return flight;
      }
    }
    return null;
  }

  void _focusFlight(LiveFlight flight) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFlight = flight;
    });

    if (!_isMapReady) {
      return;
    }

    final double nextZoom = math.max(_mapController.camera.zoom, 6.4);
    _mapController.move(LatLng(flight.latitude, flight.longitude), nextZoom);
  }

  List<Marker> _buildMarkers({
    required BuildContext context,
    required List<LiveFlight> flights,
    required String? selectedIcao24,
  }) {
    return flights
        .map((LiveFlight flight) {
          final double headingDegrees = flight.headingDegrees ?? 0;
          final double headingRadians = headingDegrees * (math.pi / 180);
          final bool isSelected = flight.icao24 == selectedIcao24;

          return Marker(
            point: LatLng(flight.latitude, flight.longitude),
            width: 30.w,
            height: 30.w,
            child: GestureDetector(
              onTap: () => _focusFlight(flight),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFC857)
                      : const Color(0xFF0F172A).withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFFFFC857).withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: isSelected ? 12 : 8,
                      spreadRadius: isSelected ? 1.2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: headingRadians,
                    child: Icon(
                      Icons.airplanemode_active_rounded,
                      color: isSelected
                          ? Colors.black87
                          : Colors.lightBlueAccent,
                      size: 15.sp,
                    ),
                  ),
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }
}

class _TopLiveBar extends StatelessWidget {
  const _TopLiveBar({
    required this.searchController,
    required this.flightCount,
    required this.isRefreshing,
    required this.lastUpdatedAt,
    required this.errorMessage,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final int flightCount;
  final bool isRefreshing;
  final DateTime? lastUpdatedAt;
  final String? errorMessage;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String updatedLabel = lastUpdatedAt == null
        ? 'Waiting for first update'
        : 'Updated ${DateFormat('HH:mm:ss').format(lastUpdatedAt!)}';

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.radar_rounded,
                color: Colors.lightBlueAccent,
                size: 19.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Live Flights Radar',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: isRefreshing
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                isRefreshing ? 'SYNC' : 'LIVE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search callsign or country',
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white70,
                size: 18.sp,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.09),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999.r),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999.r),
                borderSide: BorderSide(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: <Widget>[
              _StatPill(label: '$flightCount tracked'),
              SizedBox(width: 8.w),
              Expanded(child: _StatPill(label: updatedLabel, alignLeft: true)),
            ],
          ),
          if (errorMessage != null)
            Padding(
              padding: EdgeInsets.only(top: 7.h),
              child: Text(
                errorMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFFDA4AF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, this.alignLeft = false});

  final String label;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: SizedBox(
        width: alignLeft ? double.infinity : null,
        child: Text(
          label,
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SelectedFlightCard extends StatelessWidget {
  const _SelectedFlightCard({required this.flight, required this.onClose});

  final LiveFlight flight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.airplanemode_active_rounded,
              size: 18.sp,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Flight ${flight.displayCallsign}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  flight.displayOriginCountry,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  flight.speedKmh == null
                      ? 'Speed unavailable'
                      : 'Speed ${flight.speedKmh!.round()} km/h',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFFDE68A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: Colors.white70, size: 18.sp),
          ),
        ],
      ),
    );
  }
}

class _TrackedFlightsPanel extends StatelessWidget {
  const _TrackedFlightsPanel({
    required this.flights,
    required this.selectedIcao24,
    required this.onFlightTap,
  });

  final List<LiveFlight> flights;
  final String? selectedIcao24;
  final ValueChanged<LiveFlight> onFlightTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 184.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
            child: Row(
              children: <Widget>[
                Text(
                  'Tracked Flights',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${flights.length} shown',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: flights.isEmpty
                ? Center(
                    child: Text(
                      'No flights to display.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
                    itemCount: flights.length,
                    separatorBuilder:
                        (BuildContext context, int separatorIndex) =>
                            SizedBox(height: 6.h),
                    itemBuilder: (BuildContext context, int index) {
                      final LiveFlight flight = flights[index];
                      final bool isSelected = flight.icao24 == selectedIcao24;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10.r),
                          onTap: () => onFlightTap(flight),
                          child: Ink(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFF1E3A8A,
                                    ).withValues(alpha: 0.75)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF60A5FA)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.flight_rounded,
                                  size: 16.sp,
                                  color: isSelected
                                      ? const Color(0xFFFDE68A)
                                      : Colors.white70,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        flight.displayCallsign,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        flight.displayOriginCountry,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  flight.speedKmh == null
                                      ? '--'
                                      : '${flight.speedKmh!.round()} km/h',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
