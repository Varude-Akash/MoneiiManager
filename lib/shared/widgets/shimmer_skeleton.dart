import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moneii_manager/config/theme.dart';

class ShimmerSkeleton extends StatelessWidget {
  const ShimmerSkeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = 12,
    this.margin,
  });

  final double height;
  final double width;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceLight,
        highlightColor: AppColors.surfaceLight.withValues(alpha: 0.5),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

class ExpenseListShimmer extends StatelessWidget {
  const ExpenseListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerSkeleton(height: 24, width: 180, radius: 8),
        SizedBox(height: 8),
        ShimmerSkeleton(height: 120, radius: 20),
        SizedBox(height: 16),
        ShimmerSkeleton(height: 14, width: 80, radius: 8),
        SizedBox(height: 8),
        ShimmerSkeleton(height: 72, radius: 16),
        SizedBox(height: 8),
        ShimmerSkeleton(height: 72, radius: 16),
        SizedBox(height: 8),
        ShimmerSkeleton(height: 72, radius: 16),
      ],
    );
  }
}
