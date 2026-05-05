import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/app_theme.dart';
import 'package:air_sky/utils/price_formatter.dart';
import 'package:air_sky/features/flights/services/search_form_controller.dart';

class FareTrendChart extends ConsumerWidget {
  const FareTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchFormState form = ref.watch(searchFormControllerProvider);
    final AppCurrency selectedCurrency = ref.watch(currencyControllerProvider);
    final ThemeData theme = Theme.of(context);
    final List<double> prices = ref
        .watch(flightServiceProvider)
        .generateFareTrend(
          from: form.fromAirport,
          to: form.toAirport,
          anchorDate: form.date,
        );

    final int cheapestIndex = prices.indexOf(
      prices.reduce((double a, double b) => a < b ? a : b),
    );
    final int highestIndex = prices.indexOf(
      prices.reduce((double a, double b) => a > b ? a : b),
    );

    final double minPrice = prices[cheapestIndex];
    final double maxPrice = prices[highestIndex];
    final double range = (maxPrice - minPrice).abs();
    final double yPadding = (range < 20 ? 20 : range * 0.18);

    final double minY = (minPrice - yPadding).clamp(0, double.infinity);
    final double maxY = maxPrice + yPadding;

    String weekdayLabel(int index) {
      final DateTime day = form.date.add(Duration(days: index));
      return DateFormat('E').format(day);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadows(context),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '7-day price trend',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${form.fromAirport} -> ${form.toAirport}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    'Cheapest ${weekdayLabel(cheapestIndex)} ${PriceFormatter.format(minPrice, currency: selectedCurrency)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 170.h,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  minX: 0,
                  maxX: 6,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yPadding,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.45,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24.h,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= prices.length) {
                            return const SizedBox.shrink();
                          }
                          final bool isCheapest = index == cheapestIndex;
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              weekdayLabel(index),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isCheapest
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: isCheapest
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> spots) {
                        return spots.map((LineBarSpot spot) {
                          final int idx = spot.x.toInt();
                          return LineTooltipItem(
                            '${weekdayLabel(idx)}\n${PriceFormatter.format(spot.y)}',
                            theme.textTheme.labelMedium!.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: prices
                          .asMap()
                          .entries
                          .map(
                            (MapEntry<int, double> item) =>
                                FlSpot(item.key.toDouble(), item.value),
                          )
                          .toList(),
                      isCurved: true,
                      curveSmoothness: 0.28,
                      barWidth: 2.6,
                      color: theme.colorScheme.primary,
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter:
                            (
                              FlSpot spot,
                              double percent,
                              LineChartBarData bar,
                              int index,
                            ) {
                              final bool isCheapest = index == cheapestIndex;
                              return FlDotCirclePainter(
                                radius: isCheapest ? 4.4 : 3,
                                color: isCheapest
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                strokeWidth: 2,
                                strokeColor: theme.colorScheme.primary,
                              );
                            },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



