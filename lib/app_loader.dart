import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'brand_colors.dart';

/// Canonical small progress spinner shared by the apps.
///
/// Replaces ad-hoc `SizedBox(child: CircularProgressIndicator())`. Colour rule:
/// on a coloured/elevated button or FAB -> white (`onColored`); on a surface or
/// partial zone -> `brandPrimary`. Sizes are fixed dp, scaled internally (.w):
/// button 20, inline 18, zone 24; strokeWidth 2.
class AppLoader extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool onColored;

  const AppLoader({
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2,
    this.onColored = false,
  });

  /// Spinner inside a coloured/elevated button or FAB (white, 20).
  const AppLoader.button({super.key})
    : size = 20,
      color = null,
      strokeWidth = 2,
      onColored = true;

  /// Spinner inside an inline sub-zone on a surface (brandPrimary, 18).
  const AppLoader.inline({super.key})
    : size = 18,
      color = null,
      strokeWidth = 2,
      onColored = false;

  /// Spinner for a small partial-zone first load (brandPrimary, 24).
  /// Wrap in a [Center] when it should sit centred in its zone.
  const AppLoader.zone({super.key})
    : size = 24,
      color = null,
      strokeWidth = 2,
      onColored = false;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (onColored ? Colors.white : BrandColors.brandPrimary);
    return SizedBox(
      width: size.w,
      height: size.w,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: c),
    );
  }
}

/// Standalone primary button with a built-in inline loading state.
///
/// For FABs / single submits / inline action buttons that have a controller
/// [RxBool]. While [isLoading] is true the label is swapped for
/// [AppLoader.button] and the button is disabled. Matches the confirm button of
/// [AdminSurfaceActions] (radius 12, vertical 14, elevation 0, white foreground,
/// 0.45-alpha disabled bg). For dialog footers use AdminSurfaceActions instead.
class AppLoadingButton extends StatelessWidget {
  final String label;
  final Future<void> Function()? onPressed;
  final RxBool? isLoading;
  final Color? backgroundColor;
  final IconData? icon;
  final bool enabled;
  final bool expand;

  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading,
    this.backgroundColor,
    this.icon,
    this.enabled = true,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading == null) return _build(context, false);
    return Obx(() => _build(context, isLoading!.value));
  }

  Widget _build(BuildContext context, bool loading) {
    final bg = backgroundColor ?? BrandColors.brandPrimary;
    final button = ElevatedButton(
      onPressed: loading || !enabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: bg.withValues(alpha: 0.45),
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 0,
      ),
      child: loading
          ? const AppLoader.button()
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18.r),
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Canonical load-more footer for INFINITE-SCROLL lists only (e.g. customers,
/// reviews). Shows an inline spinner while [isLoadingMore], a sober end label
/// once [hasMore] is false, otherwise nothing. Page-button modules keep their
/// pager and must NOT use this.
class AppPaginationFooter extends StatelessWidget {
  final RxBool isLoadingMore;
  final RxBool hasMore;
  final String? endLabel;

  const AppPaginationFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
    this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      if (isLoadingMore.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: const Center(child: AppLoader.inline()),
        );
      }
      if (!hasMore.value && endLabel != null) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Center(
            child: Text(
              endLabel!,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark
                    ? BrandColors.darkSecondaryText
                    : BrandColors.lightSecondaryText,
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }
}

/// Canonical thin "refresh-over-content" bar for stats headers: a sober
/// [LinearProgressIndicator] that fades in while [isLoading] (e.g. a stats
/// refresh that should not re-skeleton the visible content).
class AppRefreshBar extends StatelessWidget {
  final RxBool isLoading;
  const AppRefreshBar({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading.value
            ? ClipRRect(
                key: const ValueKey('refresh-bar-on'),
                borderRadius: BorderRadius.circular(2.r),
                child: LinearProgressIndicator(
                  minHeight: 2.h,
                  backgroundColor: BrandColors.brandPrimary.withValues(
                    alpha: 0.08,
                  ),
                  valueColor: const AlwaysStoppedAnimation(
                    BrandColors.brandPrimary,
                  ),
                ),
              )
            : SizedBox(
                key: const ValueKey('refresh-bar-off'),
                height: 2.h,
                width: double.infinity,
              ),
      ),
    );
  }
}
