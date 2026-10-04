import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'base_api_service.dart';
import 'base_storage_service.dart';
import 'brand_colors.dart';
import 'request_type.dart';
import 'review_config.dart';

/// Drives the in-app rating pre-prompt.
///
/// Strategy (see the `app_review_config` platform setting): after a POSITIVE
/// moment (order delivered, review published) we show a maison pre-prompt
/// ("Do you like EbènIvoire?"). Happy users are routed to the native store
/// rating (protects the public rating); unhappy users go to a private feedback
/// form. All gating state (session count, install date, cooldown, prompt count)
/// lives locally in SharedPreferences; the thresholds come from the backend.
abstract class BaseAppReviewService extends GetxService {
  // ── Crochets ──────────────────────────────────────────────────────────────

  @protected
  BaseStorageService get storageService;

  @protected
  BaseApiService? get apiService;

  /// Seuls les utilisateurs connectés sont sollicités (le retour exige un
  /// jeton).
  @protected
  bool get isAuthenticated;

  /// Nom de l'app joint au retour (`'vendor'`…) ; null = cliente.
  @protected
  String? get feedbackApp => null;

  /// Ouvre la feuille de retour. Par défaut : feuille du bas ; la cliente
  /// passe par sa surface adaptative (tablette / ordinateur).
  @protected
  Future<T?> presentSheet<T>(WidgetBuilder builder) {
    final context = Get.context;
    if (context == null) return Future.value(null);
    return Get.bottomSheet<T>(
      Builder(builder: builder),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  static const _kInstallTs = 'app_review_install_ts';
  static const _kSessionCount = 'app_review_session_count';
  static const _kLastPromptTs = 'app_review_last_prompt_ts';
  static const _kPromptCount = 'app_review_prompt_count';
  static const _kCompleted = 'app_review_completed';

  final InAppReview _inAppReview = InAppReview.instance;
  bool _askingNow = false;

  BaseStorageService get _storage => storageService;

  /// Call once per app launch. Seeds the install date on first run and counts
  /// the session (drives the `min_sessions` gate).
  Future<void> recordSessionStart() async {
    try {
      final prefs = _storage.storage;
      if (prefs.getInt(_kInstallTs) == null) {
        await prefs.setInt(_kInstallTs, DateTime.now().millisecondsSinceEpoch);
      }
      await prefs.setInt(
        _kSessionCount,
        (prefs.getInt(_kSessionCount) ?? 0) + 1,
      );
    } catch (e) {
      debugPrint('⚠️ AppReview recordSessionStart failed: $e');
    }
  }

  /// Show the pre-prompt if every gate passes. Safe to call from any positive
  /// moment — it self-throttles. [trigger] is only for local debugging.
  Future<void> maybePrompt({required String trigger}) async {
    if (_askingNow) return;
    if (!_isEligible()) return;
    _askingNow = true;
    try {
      await _recordPromptShown();
      final likesApp = await _showPrePrompt();
      if (likesApp == null) return; // dismissed → counts as a prompt (cooldown)
      if (likesApp) {
        await _handlePositive();
      } else {
        await _handleNegative();
      }
    } finally {
      _askingNow = false;
    }
  }

  bool _isEligible() {
    final cfg = reviewConfig;
    if (!cfg.enabled) return false;

    // Only prompt authenticated users — the feedback POST needs auth and
    // triggers fire from authenticated flows anyway.
    if (!isAuthenticated) return false;

    final prefs = _storage.storage;
    if (prefs.getBool(_kCompleted) == true) return false;
    if ((prefs.getInt(_kPromptCount) ?? 0) >= cfg.maxPrompts) return false;
    if ((prefs.getInt(_kSessionCount) ?? 0) < cfg.minSessions) return false;

    final now = DateTime.now();
    final installTs = prefs.getInt(_kInstallTs);
    if (installTs != null) {
      final daysSinceInstall = now
          .difference(DateTime.fromMillisecondsSinceEpoch(installTs))
          .inDays;
      if (daysSinceInstall < cfg.minDaysSinceInstall) return false;
    }

    final lastPromptTs = prefs.getInt(_kLastPromptTs);
    if (lastPromptTs != null) {
      final daysSincePrompt = now
          .difference(DateTime.fromMillisecondsSinceEpoch(lastPromptTs))
          .inDays;
      if (daysSincePrompt < cfg.cooldownDays) return false;
    }
    return true;
  }

  Future<void> _recordPromptShown() async {
    final prefs = _storage.storage;
    await prefs.setInt(_kLastPromptTs, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_kPromptCount, (prefs.getInt(_kPromptCount) ?? 0) + 1);
  }

  // ── Positive branch: route to the native store rating ──────────────────────
  Future<void> _handlePositive() async {
    // Never ask again once we've sent someone to the store.
    await _storage.storage.setBool(_kCompleted, true);
    bool routed = false;
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        routed = true;
      }
    } catch (e) {
      debugPrint('⚠️ requestReview failed: $e');
    }
    unawaited(_postFeedback(sentiment: 'positive', routedToStore: routed));
  }

  // ── Negative branch: private feedback form ─────────────────────────────────
  Future<void> _handleNegative() async {
    final result = await _showFeedbackSheet();
    if (result == null) {
      // Closed without submitting — still log the negative sentiment so admins
      // see dissatisfaction even without a comment.
      unawaited(_postFeedback(sentiment: 'negative'));
      return;
    }
    unawaited(
      _postFeedback(
        sentiment: 'negative',
        rating: result.rating,
        comment: result.comment,
      ),
    );
  }

  Future<void> _postFeedback({
    required String sentiment,
    int? rating,
    String? comment,
    bool routedToStore = false,
  }) async {
    final api = apiService;
    if (api == null) return;
    try {
      String? platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        platform = 'android';
      }
      String? appVersion;
      try {
        appVersion = (await PackageInfo.fromPlatform()).version;
      } catch (_) {}

      await api.create(
        endpoint: '/api/app-review/feedback',
        type: RequestType.protected,
        data: {
          'sentiment': sentiment,
          'rating': ?rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
          'platform': ?platform,
          'app_version': ?appVersion,
          'routed_to_store': routedToStore,
          'app': ?feedbackApp,
        },
      );
    } catch (e) {
      debugPrint('⚠️ AppReview feedback POST failed: $e');
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  /// Returns true (loves it), false (not really), or null (dismissed).
  Future<bool?> _showPrePrompt() {
    return Get.dialog<bool>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: BrandColors.brandPrimary,
                size: 44,
              ),
              const SizedBox(height: 16),
              Text(
                'app_review.prompt.title'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(
                  Get.context!,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'app_review.prompt.subtitle'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(Get.context!).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back<bool>(result: false),
                      child: Text('app_review.prompt.no'.tr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back<bool>(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.brandPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('app_review.prompt.yes'.tr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<_FeedbackResult?> _showFeedbackSheet() {
    return presentSheet<_FeedbackResult>((_) => const _FeedbackSheet());
  }
}

class _FeedbackResult {
  final int? rating;
  final String? comment;
  const _FeedbackResult({this.rating, this.comment});
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _controller = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? BrandColors.darkSurface : BrandColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? BrandColors.darkSurfaceVariant
                      : BrandColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'app_review.feedback.title'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'app_review.feedback.subtitle'.tr,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? BrandColors.warningColor : null,
                    size: 34,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'app_review.feedback.hint'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Get.back<_FeedbackResult>(
                result: _FeedbackResult(
                  rating: _rating > 0 ? _rating : null,
                  comment: _controller.text,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('app_review.feedback.submit'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
