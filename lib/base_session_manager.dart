import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_api_service.dart';
import 'base_authentication_manager.dart';
import 'base_storage_service.dart';
import 'jwt_utils.dart';
import 'refresh_token_error.dart';
import 'request_type.dart';
import 'server_unreachable.dart';

/// Jetons reçus d'un renouvellement réussi.
class TokenRefreshResult {
  final String accessToken;
  final String refreshToken;
  final bool refreshRotated;

  /// L'objet `user` tel que servi (pour un admin : ses droits à jour).
  final Map<String, dynamic> rawUser;

  const TokenRefreshResult({
    required this.accessToken,
    required this.refreshToken,
    required this.refreshRotated,
    this.rawUser = const {},
  });

  factory TokenRefreshResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return TokenRefreshResult(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      refreshRotated: json['refresh_rotated'] == true,
      rawUser: user is Map ? Map<String, dynamic>.from(user) : const {},
    );
  }
}

/// La session, commune aux trois apps : vérifier le jeton avant chaque
/// requête, le renouveler, et décider — seul — quand la session se ferme.
///
/// ⚠️ Règle : une panne du serveur ou du réseau ne déconnecte JAMAIS. La
/// requête est retenue avec « serveur injoignable » (503
/// `REFRESH_UNAVAILABLE`). Seuls un refus explicite du serveur
/// ([RefreshTokenError.requiresReLogin]) ou l'expiration du jeton de
/// renouvellement ferment la session.
///
/// Crochets remplis par chaque app : [storageService], [apiService],
/// [authManager], [appInBackground], [onTokensRefreshed], [onSessionCleared],
/// [onSessionExpiredNotice], [authRoute], [authNavigationDelay],
/// [onNetworkRecovered].
abstract class BaseSessionManager extends GetxService {
  // ==================== CROCHETS ====================

  @protected
  BaseStorageService get storageService;

  @protected
  BaseApiService get apiService;

  @protected
  BaseAuthenticationManager get authManager;

  /// L'app passe-t-elle en arrière-plan ? (`AppLifecycleService`).
  @protected
  RxBool? get appInBackground => null;

  /// Après un renouvellement réussi (profil, droits admin…).
  @protected
  Future<void> onTokensRefreshed(TokenRefreshResult result) async {}

  /// Après la fermeture de la session : vider les données de l'app (panier,
  /// notifications, contrôleurs…).
  @protected
  Future<void> onSessionCleared() async {}

  /// Prévenir l'utilisateur que sa session est fermée (la cliente affiche un
  /// message ; le vendeur et la console vont droit à la connexion).
  @protected
  void onSessionExpiredNotice() {}

  @protected
  String get authRoute => '/auth';

  /// Délai avant d'ouvrir la connexion (le temps de lire le message).
  @protected
  Duration get authNavigationDelay => Duration.zero;

  /// Le réseau est revenu et la session tient.
  @protected
  void onNetworkRecovered() {}

  // ==================== ÉTAT ====================

  final RxBool isSessionValid = true.obs;
  final RxBool isRefreshingToken = false.obs;
  final RxString sessionStatus = 'unknown'.obs;
  final RxInt tokenRefreshCount = 0.obs;

  DateTime? _lastRefreshAttempt;
  DateTime? _lastSuccessfulRefresh;
  bool _refreshInProgress = false;

  /// Le dernier renouvellement a échoué à cause d'une PANNE (réseau, délai,
  /// 5xx) : la session est gardée, la requête est retenue.
  bool _lastRefreshFailureWasTemporary = false;

  /// Le serveur n'a pas pu renouveler la connexion À CAUSE D'UNE PANNE : la
  /// session tient toujours. Les appelants montrent « serveur injoignable »,
  /// jamais l'écran de connexion.
  bool get isRefreshTemporarilyUnavailable =>
      sessionStatus.value == 'refresh_unavailable';

  DateTime? _lastAppResumeTime;
  DateTime? _lastTokenCheck;
  Timer? _backgroundCheckTimer;

  static const int tokenWarningMinutes = 5;
  static const int refreshCooldownSeconds = 30;
  static const int appResumeCheckThresholdMinutes = 1;
  static const int backgroundCheckIntervalMinutes = 15;

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔐 SessionManager initialized');
    _subscribeToLifecycleEvents();
    _startBackgroundTokenMonitoring();
  }

  void _subscribeToLifecycleEvents() {
    try {
      final background = appInBackground;
      if (background == null) {
        debugPrint(
          '⚠️ AppLifecycleService not available, lifecycle monitoring disabled',
        );
        return;
      }
      ever(background, (bool isInBackground) {
        if (isInBackground) {
          _lastTokenCheck = DateTime.now();
        } else {
          _handleAppResumed();
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to subscribe to lifecycle events: $e');
    }
  }

  void _startBackgroundTokenMonitoring() {
    _backgroundCheckTimer = Timer.periodic(
      const Duration(minutes: backgroundCheckIntervalMinutes),
      (_) => _performBackgroundTokenCheck(),
    );
  }

  Future<void> _performBackgroundTokenCheck() async {
    try {
      final accessToken = await storageService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;

      if (JWTUtils.isJWTExpired(accessToken) ||
          JWTUtils.isJWTNearExpiry(
            accessToken,
            warningMinutes: tokenWarningMinutes,
          )) {
        debugPrint('⚠️ Token expired or expiring - background refresh');
        await refreshTokenSilently();
      }
      _lastTokenCheck = DateTime.now();
    } catch (e) {
      debugPrint('❌ Background token check failed: $e');
    }
  }

  void _handleAppResumed() {
    final now = DateTime.now();
    _lastAppResumeTime = now;
    final lastCheck = _lastTokenCheck;
    if (lastCheck == null ||
        now.difference(lastCheck).inMinutes >= appResumeCheckThresholdMinutes) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await checkTokenBeforeRequest();
        } catch (e) {
          debugPrint('❌ Error validating token on resume: $e');
        }
      });
    }
  }

  // ==================== AVANT CHAQUE REQUÊTE ====================

  /// Vrai si une requête protégée peut partir. Un jeton d'accès expiré est
  /// renouvelé ICI, avant l'envoi (bloquant).
  ///
  /// Faux avec [isRefreshTemporarilyUnavailable] : panne, la session tient.
  /// Faux sans : la session est fermée (ou il n'y en a pas).
  Future<bool> checkTokenBeforeRequest() async {
    try {
      final accessToken = await storageService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        // Pas de jeton d'accès, mais peut-être encore une session
        // renouvelable (jeton effacé, écriture ratée) : on tente.
        if (await _isRefreshTokenValid()) {
          return _refreshBeforeRequest();
        }
        sessionStatus.value = 'no_token';
        isSessionValid.value = false;
        return false;
      }

      if (!JWTUtils.isValidJWTStructure(accessToken)) {
        sessionStatus.value = 'invalid_token';
        isSessionValid.value = false;
        await handleSessionExpired();
        return false;
      }

      if (JWTUtils.isJWTExpired(accessToken)) {
        debugPrint('🔄 Access token EXPIRED - attempting immediate refresh');
        sessionStatus.value = 'access_expired';
        if (!await _isRefreshTokenValid()) {
          debugPrint('❌ Refresh token also invalid - session expired');
          isSessionValid.value = false;
          await handleSessionExpired();
          return false;
        }
        return _refreshBeforeRequest();
      }

      if (JWTUtils.isJWTNearExpiry(
        accessToken,
        warningMinutes: tokenWarningMinutes,
      )) {
        // Renouvellement anticipé, sans bloquer la requête.
        sessionStatus.value = 'near_expiry';
        if (await _isRefreshTokenValid()) {
          unawaited(refreshTokenSilently());
        }
      }

      sessionStatus.value = 'valid';
      isSessionValid.value = true;
      _lastTokenCheck = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('❌ Error checking tokens before request: $e');
      sessionStatus.value = 'error';
      isSessionValid.value = false;
      return false;
    }
  }

  Future<bool> _refreshBeforeRequest() async {
    final refreshed = await refreshTokenSilently();
    if (refreshed) {
      sessionStatus.value = 'refreshed';
      isSessionValid.value = true;
      return true;
    }
    if (_lastRefreshFailureWasTemporary) {
      // Panne : la session est GARDÉE, la requête RETENUE (elle partirait
      // avec un jeton expiré). Une panne longue ne déconnecte personne.
      debugPrint('🌐 Refresh unavailable - keeping session, blocking request');
      sessionStatus.value = 'refresh_unavailable';
      isSessionValid.value = true;
      return false;
    }
    // Refus explicite : refreshTokenSilently a déjà fermé la session.
    return false;
  }

  Future<bool> ensureValidTokenForRequest() => checkTokenBeforeRequest();

  Future<bool> validateCurrentSession() => checkTokenBeforeRequest();

  // ==================== RENOUVELLEMENT ====================

  Future<bool> _isRefreshTokenValid() async {
    try {
      final refreshToken = await storageService.getRefreshToken();
      return refreshToken != null &&
          refreshToken.isNotEmpty &&
          JWTUtils.isValidJWTStructure(refreshToken) &&
          !JWTUtils.isJWTExpired(refreshToken);
    } catch (e) {
      debugPrint('❌ Error validating refresh token: $e');
      return false;
    }
  }

  Future<TokenRefreshResult> _performTokenRefresh(String refreshToken) async {
    try {
      final response = await apiService.create(
        endpoint: '/auth/refresh',
        data: {'refresh_token': refreshToken},
        type: RequestType.auth,
      );

      final statusCode = response['statusCode'] as int? ?? 500;
      final body = response['body'];

      if (statusCode >= 400) {
        throw RefreshTokenError.fromResponse(
          Map<String, dynamic>.from(response as Map),
        );
      }
      if (body is! Map) {
        throw RefreshTokenError(
          message: 'core_session.refresh_failed'.tr,
          errorType: 'PARSE_ERROR',
          success: false,
          statusCode: statusCode,
        );
      }
      return TokenRefreshResult.fromJson(Map<String, dynamic>.from(body));
    } catch (e) {
      if (e is RefreshTokenError) rethrow;
      // Réseau, délai, 5xx : le serveur n'a PAS refusé le jeton. Le dire tel
      // quel, sinon la session est effacée en pleine utilisation.
      if (isServerUnreachable(e)) {
        throw RefreshTokenError(
          message: 'core_session.unreachable'.tr,
          errorType: RefreshTokenError.unreachableType,
          success: false,
          statusCode: 503,
        );
      }
      throw RefreshTokenError(
        message: 'core_session.refresh_failed'.tr,
        errorType: 'REFRESH_FAILED',
        success: false,
        statusCode: 500,
      );
    }
  }

  /// Renouvelle le jeton d'accès. Vrai en cas de succès.
  ///
  /// Faux après une panne ([isRefreshTemporarilyUnavailable]) : la session
  /// est gardée. Faux après un refus : la session est fermée.
  Future<bool> refreshTokenSilently() async {
    try {
      if (_refreshInProgress || isRefreshingToken.value) {
        // Un renouvellement est déjà en cours : on attend son résultat
        // (10 s au plus). Une panne n'est JAMAIS un succès.
        var waitCount = 0;
        while ((_refreshInProgress || isRefreshingToken.value) &&
            waitCount < 20) {
          await Future.delayed(const Duration(milliseconds: 500));
          waitCount++;
        }
        return isSessionValid.value && !_lastRefreshFailureWasTemporary;
      }

      final lastAttempt = _lastRefreshAttempt;
      if (lastAttempt != null &&
          DateTime.now().difference(lastAttempt).inSeconds <
              refreshCooldownSeconds) {
        return isSessionValid.value && !_lastRefreshFailureWasTemporary;
      }

      _refreshInProgress = true;
      isRefreshingToken.value = true;
      _lastRefreshAttempt = DateTime.now();
      _lastRefreshFailureWasTemporary = false;

      final refreshToken = await storageService.getRefreshToken();
      if (refreshToken == null ||
          refreshToken.isEmpty ||
          !await _isRefreshTokenValid()) {
        debugPrint('❌ Refresh token missing, invalid or expired');
        await handleSessionExpired();
        return false;
      }

      final result = await _performTokenRefresh(refreshToken);

      if (!JWTUtils.isValidJWTStructure(result.accessToken) ||
          JWTUtils.isJWTExpired(result.accessToken)) {
        debugPrint('❌ New access token is invalid or expired');
        await handleSessionExpired();
        return false;
      }

      await storageService.saveAccessToken(result.accessToken);
      await storageService.saveRefreshToken(
        result.refreshToken.isNotEmpty ? result.refreshToken : refreshToken,
      );
      await authManager.updateTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken.isNotEmpty
            ? result.refreshToken
            : refreshToken,
      );
      await _verifyTokenSync();

      sessionStatus.value = 'refreshed';
      isSessionValid.value = true;
      _lastSuccessfulRefresh = DateTime.now();
      _lastRefreshFailureWasTemporary = false;
      tokenRefreshCount.value++;
      debugPrint(
        '✅ Silent token refresh successful'
        '${result.refreshRotated ? ' (refresh token rotated)' : ''}',
      );

      try {
        await onTokensRefreshed(result);
      } catch (e) {
        debugPrint('⚠️ onTokensRefreshed failed: $e');
      }
      return true;
    } on RefreshTokenError catch (e) {
      debugPrint(
        '❌ Silent token refresh failed: ${e.message} (Type: ${e.errorType})',
      );
      // ⚠️ SEUL un refus explicite du serveur ferme la session. Une panne ou
      // une réponse illisible la LAISSE INTACTE.
      if (e.requiresReLogin) {
        await handleSessionExpired();
        return false;
      }
      debugPrint('⚠️ Refresh not refused (${e.errorType}) - session kept');
      _markRefreshUnavailable();
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error during silent token refresh: $e');
      // Ni refus ni panne reconnue : la session est gardée, sans faux succès.
      _markRefreshUnavailable();
      return false;
    } finally {
      _refreshInProgress = false;
      isRefreshingToken.value = false;
    }
  }

  void _markRefreshUnavailable() {
    _lastRefreshFailureWasTemporary = true;
    sessionStatus.value = 'refresh_unavailable';
    isSessionValid.value = true;
  }

  /// Renouvellement demandé explicitement (après un 401) : sans délai.
  Future<bool> forceRefreshSession() async {
    _lastRefreshAttempt = null;
    return refreshTokenSilently();
  }

  /// Le stockage et la mémoire doivent porter les mêmes jetons ; sinon on
  /// recopie le stockage (la référence) dans la mémoire.
  Future<bool> _verifyTokenSync() async {
    try {
      final storageAccess = await storageService.getAccessToken();
      final storageRefresh = await storageService.getRefreshToken();
      if (storageAccess == authManager.currentToken.value &&
          storageRefresh == authManager.currentRefreshToken.value) {
        return true;
      }
      debugPrint('❌ TOKEN SYNC MISMATCH - recovering from storage');
      if (storageAccess != null && storageRefresh != null) {
        await authManager.updateTokens(
          accessToken: storageAccess,
          refreshToken: storageRefresh,
        );
        authManager.refreshAuthenticationState();
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error verifying token sync: $e');
      return false;
    }
  }

  Future<bool> verifyTokenSynchronization() => _verifyTokenSync();

  // ==================== FERMETURE DE LA SESSION ====================

  /// Ferme la session : efface les jetons, vide l'app, ouvre la connexion.
  ///
  /// Appelée seulement sur un refus explicite du serveur ou un jeton de
  /// renouvellement expiré — jamais sur une panne.
  Future<void> handleSessionExpired() async {
    try {
      debugPrint('🚪 Handling expired session');

      // Un invité (aucun jeton en mémoire) qui reçoit un 401 sur une requête
      // de fond n'a rien à fermer : ni message, ni renvoi à la connexion.
      final hadSession =
          authManager.currentToken.value.isNotEmpty ||
          authManager.currentRefreshToken.value.isNotEmpty ||
          authManager.isAuthenticated.value;
      if (!hadSession) {
        debugPrint('🚪 No session in memory — nothing to expire');
        sessionStatus.value = 'no_token';
        isSessionValid.value = false;
        return;
      }

      sessionStatus.value = 'expired';
      isSessionValid.value = false;

      await _clearSessionData();
      try {
        await onSessionCleared();
      } catch (e) {
        debugPrint('⚠️ onSessionCleared failed: $e');
      }
      onSessionExpiredNotice();

      final delay = authNavigationDelay;
      if (delay == Duration.zero) {
        _navigateToAuth();
      } else {
        Future.delayed(delay, _navigateToAuth);
      }
    } catch (e) {
      debugPrint('❌ Error handling session expiry: $e');
      _navigateToAuth();
    }
  }

  Future<void> _clearSessionData() async {
    try {
      await storageService.clearAuthData();
    } catch (e) {
      debugPrint('❌ Error clearing stored session: $e');
    }
    await authManager.clearAuthentication();

    sessionStatus.value = 'cleared';
    isSessionValid.value = false;
    isRefreshingToken.value = false;
    tokenRefreshCount.value = 0;
    _lastRefreshAttempt = null;
    _lastSuccessfulRefresh = null;
    _refreshInProgress = false;
    _lastRefreshFailureWasTemporary = false;
    _lastTokenCheck = null;
  }

  void _navigateToAuth() {
    try {
      Get.offAllNamed(authRoute);
    } catch (e) {
      debugPrint('❌ Error navigating to auth: $e');
    }
  }

  // ==================== RÉSEAU REVENU ====================

  Future<void> handleNetworkRecovery() async {
    try {
      if (await checkTokenBeforeRequest()) {
        await syncTokensWithAuthManager();
        authManager.refreshAuthenticationState();
        onNetworkRecovered();
      }
    } catch (e) {
      debugPrint('❌ Error in network recovery: $e');
    }
  }

  Future<void> syncTokensWithAuthManager() async {
    try {
      final accessToken = await storageService.getAccessToken();
      final refreshToken = await storageService.getRefreshToken();
      if (accessToken != null && refreshToken != null) {
        await authManager.updateTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      }
    } catch (e) {
      debugPrint('❌ Error syncing tokens: $e');
    }
  }

  // ==================== DIVERS ====================

  Future<void> performPeriodicTokenCheck() async {
    final lastCheck = _lastTokenCheck;
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck).inMinutes < 2) {
      return;
    }
    await checkTokenBeforeRequest();
  }

  void scheduleNextRefresh() {
    storageService.getAccessToken().then((token) {
      if (token == null || !JWTUtils.isValidJWTStructure(token)) return;
      final minutesUntilExpiry = JWTUtils.getTimeUntilExpiry(token);
      if (minutesUntilExpiry > tokenWarningMinutes) {
        Future.delayed(
          Duration(minutes: minutesUntilExpiry - tokenWarningMinutes),
          () {
            if (isSessionValid.value) refreshTokenSilently();
          },
        );
      }
    });
  }

  Future<void> forceTokenCheck() => _performBackgroundTokenCheck();

  bool get isAuthenticated =>
      isSessionValid.value && sessionStatus.value != 'no_token';

  int get refreshCount => tokenRefreshCount.value;

  DateTime? get lastRefreshTime => _lastSuccessfulRefresh;

  Map<String, dynamic> getSessionStatus() {
    return {
      'is_monitoring': _backgroundCheckTimer?.isActive ?? false,
      'last_token_check': _lastTokenCheck?.toIso8601String() ?? 'never',
      'last_refresh_attempt': _lastRefreshAttempt?.toIso8601String() ?? 'never',
      'last_app_resume': _lastAppResumeTime?.toIso8601String() ?? 'never',
      'refresh_attempt_count': tokenRefreshCount.value,
      'check_interval_minutes': backgroundCheckIntervalMinutes,
    };
  }

  Map<String, dynamic> getSessionInfo() {
    return {
      'isSessionValid': isSessionValid.value,
      'isRefreshingToken': isRefreshingToken.value,
      'sessionStatus': sessionStatus.value,
      'tokenRefreshCount': tokenRefreshCount.value,
      'lastRefreshAttempt': _lastRefreshAttempt?.toIso8601String(),
      'lastSuccessfulRefresh': _lastSuccessfulRefresh?.toIso8601String(),
      'lastTokenCheck': _lastTokenCheck?.toIso8601String(),
      'lastAppResumeTime': _lastAppResumeTime?.toIso8601String(),
      'refreshInProgress': _refreshInProgress,
    };
  }

  void debugSessionInfo() {
    debugPrint('\n🔍 === SESSION DEBUG INFO ===');
    getSessionInfo().forEach((key, value) => debugPrint('$key: $value'));
    debugPrint('=== END SESSION DEBUG ===\n');
  }

  Future<void> debugTokenComparison() async {
    final storageAccess = await storageService.getAccessToken();
    final storageRefresh = await storageService.getRefreshToken();
    debugPrint(
      'Tokens match: access=${storageAccess == authManager.currentToken.value}'
      ' refresh=${storageRefresh == authManager.currentRefreshToken.value}',
    );
  }

  @override
  void onClose() {
    _backgroundCheckTimer?.cancel();
    super.onClose();
  }
}
