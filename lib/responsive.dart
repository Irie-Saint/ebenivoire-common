import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  // Realistic breakpoints for better mobile experience
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  // Show permanent sidebar for desktop and above (including ultra-wide)
  static bool shouldShowPermanentSidebar(BuildContext context) =>
      isDesktop(context);

  // Get screen type as enum for cleaner conditionals
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return ScreenType.desktop;
    if (width >= 600) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  // Get responsive values based on screen size with enhanced mobile support
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? largeMobile, // New: for larger phones (400-600px)
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop;
    if (width >= 600) return tablet ?? largeMobile ?? mobile;
    if (width >= 400) return largeMobile ?? mobile;
    return mobile;
  }

  // Legacy method for backward compatibility (without largeMobile parameter)
  static T getResponsiveValueLegacy<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    return getResponsiveValue<T>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // Get responsive padding with standard spacing
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: const EdgeInsets.all(16), // Standard mobile padding
      largeMobile: const EdgeInsets.all(20), // Standard large mobile padding
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  // Get responsive horizontal padding (for edge-to-edge content)
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: const EdgeInsets.symmetric(
        horizontal: 16,
      ), // Standard horizontal padding
      largeMobile: const EdgeInsets.symmetric(
        horizontal: 20,
      ), // Standard large mobile padding
      tablet: const EdgeInsets.symmetric(horizontal: 24),
      desktop: const EdgeInsets.symmetric(horizontal: 32),
    );
  }

  // Get responsive content padding (for main content areas)
  static EdgeInsets getResponsiveContentPadding(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        20,
      ), // Standard content padding
      largeMobile: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        22,
      ), // Standard large mobile padding
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  // Get responsive grid columns for vendor product grids
  static int getGridColumns(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 1,
      largeMobile: 2, // New: 2 columns for larger phones
      tablet: 2,
      desktop: 3,
    );
  }

  // Get responsive sidebar width for vendor dashboard
  static double getSidebarWidth(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 0, // Hidden on mobile
      largeMobile: 0, // Still hidden on large mobile
      tablet: 250,
      desktop: 280,
    );
  }

  // Check if sidebar should be drawer (mobile/tablet only)
  static bool shouldUseDrawer(BuildContext context) {
    return isMobile(context) || isTablet(context);
  }

  // Get responsive spacing values
  static double getResponsiveSpacing(
    BuildContext context, {
    double mobile = 12.0,
    double? largeMobile,
    double? tablet,
    double desktop = 20.0,
  }) {
    return getResponsiveValue(
      context: context,
      mobile: mobile,
      largeMobile: largeMobile ?? mobile + 2,
      tablet: tablet ?? mobile + 4,
      desktop: desktop,
    );
  }

  // Helper method for safe area padding (accounts for notches, etc.)
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final basePadding = getResponsivePadding(context);

    return EdgeInsets.fromLTRB(
      basePadding.left,
      basePadding.top + mediaQuery.padding.top,
      basePadding.right,
      basePadding.bottom + mediaQuery.padding.bottom,
    );
  }

  // Helper method for minimum touch target size (accessibility)
  static double getMinTouchTarget(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 44.0, // iOS minimum
      largeMobile: 46.0,
      tablet: 48.0, // Material Design minimum
      desktop: 48.0,
    );
  }

  // ✅ NEW: Check orientation (optional - use only when needed)
  // Does NOT affect existing code - purely additive
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  // ✅ NEW: Get responsive font size with text scaling (accessibility)
  // Does NOT affect existing code - purely additive
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    double? largeMobile,
    double? tablet,
    required double desktop,
    bool respectTextScaling = true,
  }) {
    final baseFontSize = getResponsiveValue(
      context: context,
      mobile: mobile,
      largeMobile: largeMobile,
      tablet: tablet,
      desktop: desktop,
    );

    if (!respectTextScaling) return baseFontSize;

    // Respect user's text scaling preference (accessibility)
    final textScaler = MediaQuery.of(context).textScaler;
    return textScaler.scale(baseFontSize);
  }

  // ✅ NEW: Check if device is in compact mode
  // Does NOT affect existing code - purely additive
  static bool isCompactMode(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallPhone = size.width < 360 || size.height < 600;
    final isLandscapeTablet = isTablet(context) && isLandscape(context);
    return isSmallPhone || isLandscapeTablet;
  }

  @override
  Widget build(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.desktop:
        return desktop;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }
}

// Screen type enum for cleaner code
enum ScreenType { mobile, tablet, desktop }

// Responsive breakpoints as constants for consistency
class ResponsiveBreakpoints {
  static const double mobile = 600; // Updated to realistic mobile breakpoint
  static const double tablet = 1024; // Updated to standard tablet breakpoint

  // Additional breakpoints for enhanced responsiveness
  static const double largeMobile = 400; // For larger phones
  static const double smallTablet = 768; // For small tablets

  // Common vendor dashboard breakpoints
  static const double minDashboardWidth = 1024; // Updated
}

// Responsive mixins for common vendor layouts
mixin ResponsiveVendorMixin {
  // Get responsive card columns for vendor grids
  int getVendorCardColumns(BuildContext context) {
    return Responsive.getResponsiveValue(
      context: context,
      mobile: 1,
      largeMobile: 2, // Enhanced for larger phones
      tablet: 2,
      desktop: 3,
    );
  }

  // Get responsive table columns for vendor data tables
  int getVendorTableColumns(BuildContext context) {
    return Responsive.getResponsiveValue(
      context: context,
      mobile: 2, // Increased from 3 to 2 for better mobile UX
      largeMobile: 3,
      tablet: 4,
      desktop: 6,
    );
  }

  // Get responsive chart height for vendor analytics
  double getVendorChartHeight(BuildContext context) {
    return Responsive.getResponsiveValue(
      context: context,
      mobile: 280, // Increased from 250 for better visibility
      largeMobile: 300,
      tablet: 320, // Increased from 300
      desktop: 380, // Increased from 350
    );
  }
}
