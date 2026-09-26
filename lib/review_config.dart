/// Backend-hydrated config for the in-app rating pre-prompt. Admin-editable via
/// the `app_review_config` platform setting, served in `GET /api/app/config` as
/// `app_review`. Read by [AppReviewService].
///
/// Fallback defaults mirror the backend `get_app_review_config` defaults so the
/// prompt still behaves sanely if the config fetch fails.
library;

class ReviewConfig {
  final bool enabled;
  final int minSessions;
  final int minDaysSinceInstall;
  final int cooldownDays;
  final int maxPrompts;

  const ReviewConfig({
    required this.enabled,
    required this.minSessions,
    required this.minDaysSinceInstall,
    required this.cooldownDays,
    required this.maxPrompts,
  });

  static const ReviewConfig fallback = ReviewConfig(
    enabled: true,
    minSessions: 3,
    minDaysSinceInstall: 3,
    cooldownDays: 60,
    maxPrompts: 3,
  );

  factory ReviewConfig.fromJson(Map<dynamic, dynamic> json) {
    int asInt(dynamic v, int fallbackValue, {int min = 0}) {
      final n = v is int ? v : int.tryParse('$v');
      if (n == null || n < min) return fallbackValue;
      return n;
    }

    return ReviewConfig(
      enabled: json['enabled'] != false,
      minSessions: asInt(json['min_sessions'], 3, min: 1),
      minDaysSinceInstall: asInt(json['min_days_since_install'], 3),
      cooldownDays: asInt(json['cooldown_days'], 60, min: 1),
      maxPrompts: asInt(json['max_prompts'], 3, min: 1),
    );
  }
}

// Backend-hydrated value (fallback until /api/app/config lands).
ReviewConfig _reviewConfig = ReviewConfig.fallback;

ReviewConfig get reviewConfig => _reviewConfig;

/// Hydrate from the app-config `app_review` object. A malformed/absent value
/// keeps the safe fallback.
void hydrateReviewConfig(dynamic value) {
  if (value is Map) {
    _reviewConfig = ReviewConfig.fromJson(value);
  }
}
