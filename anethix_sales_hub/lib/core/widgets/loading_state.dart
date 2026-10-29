import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_constants.dart';

/// Shimmering placeholder blocks that stand in for a list while it loads.
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 132,
    this.padding = const EdgeInsets.all(AppConstants.pagePadding),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerLow,
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          ),
        ),
      ),
    );
  }
}

/// Shimmer sized for a stats grid rather than a list.
class LoadingGridState extends StatelessWidget {
  const LoadingGridState({
    super.key,
    this.tileCount = 6,
    this.crossAxisCount = 2,
  });

  final int tileCount;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerLow,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.65,
        children: [
          for (var i = 0; i < tileCount; i++)
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small inline spinner for buttons and tight spaces.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
    );
  }
}
