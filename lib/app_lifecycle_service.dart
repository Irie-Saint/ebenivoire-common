import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// L'app passe-t-elle en arrière-plan ? La session s'y abonne pour revérifier
/// le jeton au retour au premier plan.
///
/// Crochet : [onAppResumed] (l'app rafraîchit, par exemple, l'autorisation
/// des notifications).
class BaseAppLifecycleService extends GetxService with WidgetsBindingObserver {
  final RxBool isAppInBackground = false.obs;
  final RxBool isForegroundRefreshNeeded = false.obs;

  DateTime? _backgroundStartTime;

  /// Durée minimale en arrière-plan avant de demander une revérification.
  static const int minBackgroundDurationForValidation = 60;

  /// Crochet : l'app revient au premier plan.
  @protected
  void onAppResumed() {}

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('🔄 AppLifecycleService initialized');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 App lifecycle state changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        if (isAppInBackground.value) {
          isAppInBackground.value = false;

          final backgroundDuration = _getBackgroundDuration();
          if (backgroundDuration >= minBackgroundDurationForValidation) {
            debugPrint(
              '🔄 App resumed after ${backgroundDuration}s - triggering validation',
            );
            isForegroundRefreshNeeded.value = true;
          }

          try {
            onAppResumed();
          } catch (e) {
            debugPrint('⚠️ onAppResumed failed: $e');
          }

          if (isForegroundRefreshNeeded.value) {
            debugPrint('🔄 App resumed - foreground refresh needed');
            isForegroundRefreshNeeded.value = false;
          }
        }
        _backgroundStartTime = null;
        break;
      case AppLifecycleState.paused:
        isAppInBackground.value = true;
        _backgroundStartTime = DateTime.now();
        break;
      default:
        break;
    }
  }

  int _getBackgroundDuration() {
    final start = _backgroundStartTime;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  Map<String, dynamic> getLifecycleStatus() {
    return {
      'isAppInBackground': isAppInBackground.value,
      'isForegroundRefreshNeeded': isForegroundRefreshNeeded.value,
      'backgroundStartTime': _backgroundStartTime?.toIso8601String(),
      'backgroundDuration': _getBackgroundDuration(),
    };
  }

  void debugLifecycleStatus() {
    debugPrint('🔍 Lifecycle: ${getLifecycleStatus()}');
  }
}
