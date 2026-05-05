import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class TicketShimmerList extends StatelessWidget {
  const TicketShimmerList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color highlight = Theme.of(context).colorScheme.surface;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      itemCount: count,
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: 12.h),
      itemBuilder: (BuildContext context, int index) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(height: 14.h, color: Colors.white),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      width: 74.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  height: 18.h,
                  color: Colors.white,
                ),
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  height: 14.h,
                  color: Colors.white,
                ),
                SizedBox(height: 14.h),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 110.w,
                    height: 110.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



