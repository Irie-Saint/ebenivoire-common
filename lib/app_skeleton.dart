import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'brand_colors.dart';

/// The single canonical shimmer wrapper for the apps' loading skeletons.
///
/// First-load states use neutral shimmer skeletons that MIMIC the real layout
/// (the app's rule: functional transitions + shimmer only, no decorative
/// loaders). Wrap a skeleton tree in exactly ONE [AppShimmer]; keep card chrome
/// (border, surface bg) OUTSIDE it so only the inner shapes shimmer. Build the
/// shapes with [SkeletonBox], [SkeletonText], [SkeletonListTile] (or a whole
/// [SkeletonList]).
///
/// Colours come from the single source of truth — the `BrandColors.skeleton*`
/// tokens — resolved by theme brightness, always sweeping base -> highlight.
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? BrandColors.skeletonBaseDark
          : BrandColors.skeletonBaseLight,
      highlightColor: isDark
          ? BrandColors.skeletonHighlightDark
          : BrandColors.skeletonHighlightLight,
      child: child,
    );
  }
}

/// Theme-aware base fill for skeleton shapes (the colour an [AppShimmer]
/// overpaints). Exposed so non-AppShimmer placeholders can match.
Color skeletonBaseColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? BrandColors.skeletonBaseDark
    : BrandColors.skeletonBaseLight;

/// A neutral rounded placeholder block, painted over by an ancestor [AppShimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Theme-aware fill so the box reads correctly the frame before the
        // shimmer paints and in dark mode (the parent AppShimmer overpaints it).
        color: skeletonBaseColor(context),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius.r),
      ),
    );
  }
}

/// A stack of skeleton text lines; the last line is shortened to read as text.
///
/// Must be placed in a width-bounded context (e.g. inside an [Expanded] or a
/// sized box), since lines fill the available width.
class SkeletonText extends StatelessWidget {
  final int lines;
  final double lastLineFraction;
  final double height;
  final double spacing;

  const SkeletonText({
    super.key,
    this.lines = 1,
    this.lastLineFraction = 0.6,
    this.height = 11,
    this.spacing = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: spacing.h),
          if (i == lines - 1 && lines > 1)
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: lastLineFraction,
              child: SkeletonBox(height: height.h, width: double.infinity),
            )
          else
            SkeletonBox(height: height.h, width: double.infinity),
        ],
      ],
    );
  }
}

/// A single list-row skeleton atom: optional leading avatar + [SkeletonText] +
/// optional trailing shape. No card chrome and no [AppShimmer] of its own —
/// those are provided by the parent (e.g. [SkeletonList] or a feature skeleton).
class SkeletonListTile extends StatelessWidget {
  final bool hasAvatar;
  final double avatarSize;
  final bool avatarCircle;
  final int lines;
  final Widget? trailing;

  const SkeletonListTile({
    super.key,
    this.hasAvatar = true,
    this.avatarSize = 44,
    this.avatarCircle = true,
    this.lines = 2,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (hasAvatar) ...[
          SkeletonBox(
            width: avatarSize.r,
            height: avatarSize.r,
            radius: 10,
            shape: avatarCircle ? BoxShape.circle : BoxShape.rectangle,
          ),
          SizedBox(width: 12.w),
        ],
        Expanded(child: SkeletonText(lines: lines)),
        if (trailing != null) ...[SizedBox(width: 12.w), trailing!],
      ],
    );
  }
}

/// Canonical "list first-load" skeleton: [count] rows, each (optionally) inside
/// solid card chrome, each wrapped in its own [AppShimmer] so the chrome stays
/// solid while only the inner shapes shimmer. Provide the real row layout via
/// [itemBuilder] (build it with [SkeletonBox]/[SkeletonText]/[SkeletonListTile]).
class SkeletonList extends StatelessWidget {
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double gap;
  final bool sliver;
  final bool card;

  const SkeletonList({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.padding,
    this.gap = 8,
    this.sliver = false,
    this.card = true,
  });

  Widget _row(BuildContext context, int index) {
    final content = AppShimmer(child: itemBuilder(context, index));
    if (!card) return content;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark ? BrandColors.darkSurface : BrandColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: BrandColors.divider.withValues(alpha: 0.3)),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (sliver) {
      return SliverPadding(
        padding: padding ?? EdgeInsets.zero,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: EdgeInsets.only(bottom: gap.h),
              child: _row(context, index),
            ),
            childCount: count,
          ),
        ),
      );
    }
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : gap.h),
              child: _row(context, i),
            ),
        ],
      ),
    );
  }
}
