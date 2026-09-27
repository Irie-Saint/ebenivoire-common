import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_skeleton.dart';
import 'brand_name_loader.dart';

/// Image réseau du vendeur et de la console (un seul exemplaire ; la cliente
/// a le sien, avec des cas en plus : fichiers locaux, avatars).
///
/// A wrapper widget for loading network images with caching.
///
/// ## ⚠️ CRITICAL - CORS Issues on Web Platform
///
/// ### The Problem
/// If you see this error on web:
/// ```
/// Access to XMLHttpRequest at 'https://asameb-furnitures.zeabur.app/...' from origin 'http://localhost'
/// has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present.
/// ```
///
/// ### Why This Happens
/// - CORS is a **browser security feature** (not a Flutter issue)
/// - The browser blocks cross-origin requests without proper server headers
/// - This affects ALL web apps, not just Flutter
///
/// ### ❌ Client-Side "Solutions" That DON'T Work
/// - `flutter_cors_image` - Uses dart:html (not WASM-compatible)
/// - `image_network` - Works with HTML renderer but NOT with WASM
/// - `network_image_plus` - Still gets CORS errors
/// - Proxy servers - Not practical for production
/// - Browser extensions - Only for development
///
/// ### ✅ The ONLY Real Solution: Fix Server CORS Headers
///
/// Your WordPress server at `asameb-furnitures.zeabur.app` MUST send:
/// ```
/// Access-Control-Allow-Origin: *
/// Access-Control-Allow-Methods: GET, OPTIONS
/// Access-Control-Allow-Headers: Content-Type
/// ```
///
/// ### How to Fix on WordPress
///
/// **Option 1: .htaccess (Apache)**
/// ```apache
/// <IfModule mod_headers.c>
///   <FilesMatch "\.(jpg|jpeg|png|gif|svg|webp)$">
///     Header set Access-Control-Allow-Origin "*"
///   </FilesMatch>
/// </IfModule>
/// ```
///
/// **Option 2: WordPress Plugin**
/// Install "WP CORS" plugin from WordPress admin
///
/// **Option 3: functions.php**
/// ```php
/// add_action('init', 'handle_cors');
/// function handle_cors() {
///   header("Access-Control-Allow-Origin: *");
///   header("Access-Control-Allow-Methods: GET, OPTIONS");
/// }
/// ```
///
/// **Option 4: Contact Zeabur Support**
/// Ask them to enable CORS for your uploads directory
///
/// ### Testing CORS Fix
/// ```bash
/// curl -I https://asameb-furnitures.zeabur.app/wp-content/uploads/2025/04/jdmej83c.png
/// ```
/// Should show: `Access-Control-Allow-Origin: *`
///
/// ### 📱 Good News for Mobile
/// CORS **only affects web browsers**. Android and iOS apps work fine
/// without any CORS configuration.
///
/// ### Summary
/// - ✅ Mobile apps: Work perfectly (no CORS)
/// - ❌ Web app: Needs server CORS headers
/// - 🔧 Fix: Configure WordPress server, NOT Flutter app
///
/// See [NETWORK_IMAGE_CORS_FIX.md] for detailed instructions.
class NetworkImageWithLoader extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isCircular;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final Color? placeholderColor;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final bool useLoading;
  final bool enableDebugPrint;
  final Duration? fadeInDuration;
  final bool disableAnimation;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  /// Pendant le chargement, le nom « EbènIvoire » scintille
  /// ([BrandNameLoader], paquet commun) — par défaut partout, comme dans la
  /// cliente (décision du 27/09). `false` = ancien bloc gris.
  final bool brandLoader;

  const NetworkImageWithLoader({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isCircular = false,
    this.errorWidget,
    this.loadingWidget,
    this.placeholderColor,
    this.memCacheWidth,
    this.memCacheHeight,
    this.useLoading = true,
    this.enableDebugPrint = false,
    this.fadeInDuration = const Duration(milliseconds: 100),
    this.disableAnimation = false,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.brandLoader = true,
  });

  factory NetworkImageWithLoader.forList({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool isCircular = false,
    Widget? errorWidget,
    Color? placeholderColor,
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    return NetworkImageWithLoader(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      isCircular: isCircular,
      errorWidget: errorWidget,
      placeholderColor: placeholderColor,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      useLoading: false,
      disableAnimation: true,
      fadeInDuration: Duration.zero,
    );
  }

  factory NetworkImageWithLoader.hero({
    required String imageUrl,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Widget? errorWidget,
    Color? placeholderColor,
  }) {
    return NetworkImageWithLoader(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      errorWidget: errorWidget,
      placeholderColor: placeholderColor,
      useLoading: true,
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guard blank/invalid URLs: CachedNetworkImage still attempts a fetch on an
    // empty string (and asserts on web), so short-circuit to the error widget.
    final url = imageUrl.trim();
    if (url.isEmpty || url == 'null') {
      return _wrap(_errorBox());
    }

    // Decode at display size (× devicePixelRatio) to cut memory use; fall back
    // to the provided hints when no display size is known.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    int? cacheW = memCacheWidth;
    if (cacheW == null && width != null && width!.isFinite && width! > 0) {
      cacheW = (width! * dpr).round();
    }
    int? cacheH = memCacheHeight;
    if (cacheH == null && height != null && height!.isFinite && height! > 0) {
      cacheH = (height! * dpr).round();
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      maxWidthDiskCache: maxWidthDiskCache ?? cacheW,
      maxHeightDiskCache: maxHeightDiskCache ?? cacheH,
      fadeInDuration: disableAnimation
          ? Duration.zero
          : (fadeInDuration ?? const Duration(milliseconds: 100)),
      placeholder: loadingWidget != null
          ? (context, _) => loadingWidget!
          // The brand loader shows even in lists (useLoading off there).
          : brandLoader
          ? (context, _) => SizedBox(
              width: width,
              height: height,
              child: const BrandNameLoader(),
            )
          : useLoading
          ? (context, _) => AppShimmer(
              child: Container(
                width: width,
                height: height,
                color: placeholderColor ?? skeletonBaseColor(context),
              ),
            )
          : null,
      errorWidget: (context, failedUrl, error) {
        if (enableDebugPrint) {
          debugPrint('Image load error: $error for URL: $failedUrl');
        }
        // Stale cache: the cache DB references a file already evicted from disk
        // (cleanup race) → loading throws PathNotFound. Drop the bad entry so it
        // re-downloads next render instead of staying broken (web-safe match).
        final msg = error.toString();
        if (msg.contains('No such file') ||
            msg.contains('Cannot retrieve length of file') ||
            msg.contains('PathNotFound')) {
          CachedNetworkImage.evictFromCache(url);
        }
        return _errorBox();
      },
    );

    return _wrap(imageWidget);
  }

  Widget _wrap(Widget child) {
    if (isCircular) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipOval(child: child),
      );
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _errorBox() {
    if (errorWidget != null) return errorWidget!;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Colors.grey[200],
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }
}
