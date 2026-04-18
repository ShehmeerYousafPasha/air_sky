import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class FlightShimmerList extends StatelessWidget {
  const FlightShimmerList({super.key});

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color highlight = Theme.of(context).colorScheme.surface;

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      itemBuilder: (BuildContext context, int index) => Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 120.w,
                          height: 12.h,
                          color: Colors.white,
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          width: 90.w,
                          height: 10.h,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 68.w,
                    height: 26.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(height: 32.h, color: Colors.white),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Container(height: 32.h, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                height: 34.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ],
          ),
        ),
      ),
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: 12.h),
      itemCount: 6,
    );
  }
}
