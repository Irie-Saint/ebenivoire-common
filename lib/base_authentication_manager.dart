import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_storage_service.dart';
import 'jwt_utils.dart';

/// État de connexion, commun aux trois apps : les jetons en mémoire et la
/// réponse à « l'utilisateur est-il connecté ? ».
///
/// ⚠️ Règle : l'utilisateur est connecté tant que la session peut être
/// RENOUVELÉE (jeton de renouvellement valide, 7 jours), pas seulement tant
/// que le jeton d'ACCÈS vit (30 minutes). Le jeton d'accès est renouvelé
/// juste avant chaque requête protégée. Seuls un refus explicite du serveur
/// ou l'expiration du jeton de renouvellement ferment la session.
///
/// Crochets : [storageService], [onTokensLoaded], [clearUserInfo],
/// [onAuthenticationCleared], [extraAuthStatus].
abstract class BaseAuthenticationManager extends GetxService {
  final RxBool isAuthenticated = false.obs;
  final RxString currentToken = ''.obs;
  final RxString currentRefreshToken = ''.obs;
  final RxString userEmail = ''.obs;
  final RxString userId = ''.obs;

  /// Crochet : le stockage de l'app.
  @protected
  BaseStorageService get storageService;

  /// Crochet : données propres à l'app relues avec les jetons au démarrage.
  @protected
  Future<void> onTokensLoaded() async {}

  /// Crochet : données propres à l'app effacées avec la session.
  @protected
  Future<void> onAuthenticationCleared() async {}

  /// Crochet : informations de débogage propres à l'app.
  @protected
  Map<String, dynamic> get extraAuthStatus => const {};

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔐 AuthenticationManager initialized');
    _setupTokenWatcher();
    loadTokensFromStorage();
  }

  void _setupTokenWatcher() {
    ever(currentToken, (String token) {
      final wasAuthenticated = isAuthenticated.value;
      final nowAuthenticated = _isAuthenticatedRobust();
      isAuthenticated.value = nowAuthenticated;

      if (wasAuthenticated != nowAuthenticated) {
        debugPrint(
          '🔐 Authentication state changed: $wasAuthenticated → $nowAuthenticated',
        );
        if (nowAuthenticated) {
          _extractUserInfoFromToken(token);
        } else {
          clearUserInfo();
        }
      } else if (nowAuthenticated && token.isNotEmpty) {
        // Jeton renouvelé : l'identité suit le nouveau jeton.
        _extractUserInfoFromToken(token);
      }
    });

    ever(currentRefreshToken, (String _) {
      final wasAuthenticated = isAuthenticated.value;
      final nowAuthenticated = _isAuthenticatedRobust();
      if (wasAuthenticated != nowAuthenticated) {
        isAuthenticated.value = nowAuthenticated;
        debugPrint(
          '🔐 Authentication state changed via refresh token: $wasAuthenticated → $nowAuthenticated',
        );
        if (!nowAuthenticated) clearUserInfo();
      }
    });
  }

  /// Relit les jetons du stockage. L'attente du stockage est BORNÉE (~5 s) :
  /// un stockage cassé ne doit jamais bloquer cette boucle pour toujours.
  @protected
  Future<void> loadTokensFromStorage() async {
    try {
      final storage = storageService;
      if (!storage.isInitialized.value) {
        debugPrint('⏳ Waiting for StorageService to be initialized...');
        var attempts = 0;
        const maxAttempts = 50;
        await Future.doWhile(() async {
          if (attempts >= maxAttempts) return false;
          attempts++;
          await Future.delayed(const Duration(milliseconds: 100));
          return !storage.isInitialized.value;
        });
        if (!storage.isInitialized.value) {
          debugPrint(
            '⚠️ StorageService still not initialized after $maxAttempts attempts',
          );
        }
      }

      final accessToken = await storage.getAccessToken();
      final refreshToken = await storage.getRefreshToken();

      currentToken.value = accessToken ?? '';
      currentRefreshToken.value = refreshToken ?? '';

      await onTokensLoaded();

      // Le jeton d'accès a pu être absent ou identique : l'état doit suivre
      // aussi le jeton de renouvellement.
      refreshAuthenticationState();
      if (isAuthenticated.value && currentToken.value.isNotEmpty) {
        _extractUserInfoFromToken(currentToken.value);
      }

      debugPrint(
        '🔐 Tokens loaded from storage (access: '
        '${accessToken?.isNotEmpty == true ? 'present' : 'missing'}, refresh: '
        '${refreshToken?.isNotEmpty == true ? 'present' : 'missing'})',
      );
    } catch (e) {
      debugPrint('❌ Error loading tokens from storage: ${e.runtimeType}');
      currentToken.value = '';
      currentRefreshToken.value = '';
    }
  }

  bool _validateToken(String token) {
    if (token.isEmpty) return false;
    try {
      return JWTUtils.isValidJWTStructure(token) &&
          !JWTUtils.isJWTExpired(token);
    } catch (e) {
      debugPrint('❌ Error validating token: $e');
      return false;
    }
  }

  /// La session peut être renouvelée : le jeton de renouvellement est encore
  /// valide, même si le jeton d'accès a expiré.
  bool get canRecoverSession {
    final refresh = currentRefreshToken.value;
    return refresh.isNotEmpty &&
        JWTUtils.isValidJWTStructure(refresh) &&
        !JWTUtils.isJWTExpired(refresh);
  }

  bool _isAuthenticatedRobust() {
    if (_validateToken(currentToken.value)) return true;
    // Jeton d'accès expiré mais session renouvelable : toujours connecté.
    return canRecoverSession;
  }

  void _extractUserInfoFromToken(String token) {
    if (!JWTUtils.isValidJWTStructure(token)) return;
    try {
      userId.value = JWTUtils.getUserIdFromJWT(token) ?? '';
      userEmail.value = JWTUtils.getUserEmailFromJWT(token) ?? '';
    } catch (e) {
      debugPrint('❌ Error extracting user info from token: $e');
    }
  }

  /// Efface l'identité en mémoire. Les apps y ajoutent la leur (droits…) en
  /// appelant `super.clearUserInfo()`.
  @protected
  @mustCallSuper
  void clearUserInfo() {
    userId.value = '';
    userEmail.value = '';
  }

  /// Enregistre de nouveaux jetons (connexion ou renouvellement).
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await storageService.saveAccessToken(accessToken);
      await storageService.saveRefreshToken(refreshToken);
      currentToken.value = accessToken;
      currentRefreshToken.value = refreshToken;
      debugPrint('🔐 Tokens updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating tokens: ${e.runtimeType}');
    }
  }

  /// Ferme la session en mémoire ET dans le stockage.
  Future<void> clearAuthentication() async {
    try {
      await storageService.clearAuthData();
      await onAuthenticationCleared();
      debugPrint('🔐 Authentication cleared');
    } catch (e) {
      debugPrint('❌ Error clearing authentication: ${e.runtimeType}');
    } finally {
      // Tout de suite, sans attendre les écouteurs des jetons : un garde qui
      // lit l'état juste après doit voir « non connecté », même si le
      // stockage a échoué.
      currentToken.value = '';
      currentRefreshToken.value = '';
      isAuthenticated.value = false;
      clearUserInfo();
    }
  }

  bool needsTokenRefresh({int warningMinutes = 10}) {
    if (currentToken.value.isEmpty) return false;
    try {
      return JWTUtils.isJWTNearExpiry(
        currentToken.value,
        warningMinutes: warningMinutes,
      );
    } catch (e) {
      return false;
    }
  }

  int getTimeUntilExpiry() {
    if (currentToken.value.isEmpty) return 0;
    try {
      return JWTUtils.getTimeUntilExpiry(currentToken.value);
    } catch (e) {
      return 0;
    }
  }

  bool get isUserLoggedIn => _isAuthenticatedRobust();

  String get currentUserId => userId.value;

  String get currentUserEmail => userEmail.value;

  bool canRefreshSession() => canRecoverSession;

  void refreshAuthenticationState() {
    final newState = _isAuthenticatedRobust();
    if (isAuthenticated.value != newState) {
      isAuthenticated.value = newState;
      debugPrint('🔐 Authentication state updated: $newState');
    }
  }

  /// État pour le débogage — sans donnée personnelle.
  Map<String, dynamic> getAuthStatus() {
    return {
      'isAuthenticated': isAuthenticated.value,
      'hasAccessToken': currentToken.value.isNotEmpty,
      'hasRefreshToken': currentRefreshToken.value.isNotEmpty,
      'hasUserId': userId.value.isNotEmpty,
      'hasUserEmail': userEmail.value.isNotEmpty,
      'tokenValid': _validateToken(currentToken.value),
      'canRecoverSession': canRecoverSession,
      'needsRefresh': needsTokenRefresh(),
      'minutesUntilExpiry': getTimeUntilExpiry(),
      ...extraAuthStatus,
    };
  }

  void debugAuthStatus() {
    debugPrint('\n🔍 === AUTHENTICATION STATUS ===');
    getAuthStatus().forEach((key, value) => debugPrint('$key: $value'));
    debugPrint('=== END AUTH STATUS ===\n');
  }

  Future<void> reloadTokensFromStorage() => loadTokensFromStorage();
}
