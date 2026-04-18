import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FlightFilterSelection {
  const FlightFilterSelection({this.maxStops, this.maxPrice});

  final int? maxStops;
  final double? maxPrice;
}

class FlightFilterBottomSheet extends StatefulWidget {
  const FlightFilterBottomSheet({super.key, this.maxStops, this.maxPrice});

  final int? maxStops;
  final double? maxPrice;

  @override
  State<FlightFilterBottomSheet> createState() =>
      _FlightFilterBottomSheetState();
}

class _FlightFilterBottomSheetState extends State<FlightFilterBottomSheet> {
  late int? _stops = widget.maxStops;
  late double _price = widget.maxPrice ?? 2500;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Filters',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, const FlightFilterSelection());
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Maximum stops',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: <int>[0, 1, 2].map<Widget>((int stop) {
              final bool selected = _stops == stop;
              return ChoiceChip(
                selected: selected,
                label: Text(stop == 0 ? 'Non-stop' : 'Up to $stop stop'),
                onSelected: (_) => setState(() => _stops = stop),
              );
            }).toList(),
          ),
          SizedBox(height: 12.h),
          Text(
            'Maximum price: \$${_price.round()}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: _price,
            min: 100,
            max: 3000,
            divisions: 29,
            label: _price.round().toString(),
            onChanged: (double value) => setState(() => _price = value),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  FlightFilterSelection(maxStops: _stops, maxPrice: _price),
                );
              },
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    );
  }
}
