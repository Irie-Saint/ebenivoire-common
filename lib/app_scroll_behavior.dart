import 'package:flutter/material.dart';

/// App-wide scroll behavior.
///
/// Flutter web hides scrollbars by default on inner scrollables, so on a
/// desktop browser users can't tell long lists/tables are scrollable. This
/// shows a vertical scrollbar on desktop platforms (web-on-desktop included)
/// while leaving horizontal rails and touch platforms untouched.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Never decorate horizontal scrollables (horizontal rails/carousels).
    if (details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right) {
      return child;
    }
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(controller: details.controller, child: child);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
