import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jwt_utils.dart';

/// Stockage local commun aux trois apps : jetons (stockage sécurisé),
/// identité et indicateurs du parcours de connexion (préférences).
///
/// Chaque app en hérite et y ajoute ses propres données (panier et paiement
/// pour la cliente, statut et droits pour le vendeur, droits pour la console).
///
/// Crochets :
/// - [migrateIfNeeded] : nettoyage au démarrage d'une nouvelle version ;
/// - [extraDefaultFlags] : indicateurs posés à la première ouverture ;
/// - [extraAuthKeys] : clés des préférences effacées avec la session.
abstract class BaseStorageService extends GetxService {
  SharedPreferences? _prefs;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final isInitialized = false.obs;

  static const String tempEmailKey = 'temp_email';
  static const String tempVerifyTokenKey = 'temp_verify_token';

  // ==================== DÉMARRAGE ====================

  Future<BaseStorageService> init() async {
    try {
      debugPrint('🔧 Initializing SharedPreferences...');
      _prefs = await SharedPreferences.getInstance();

      await migrateIfNeeded();

      debugPrint('📦 Setting default values if needed...');
      await _ensureDefaultValues();

      isInitialized.value = true;
      debugPrint('✅ StorageService initialized successfully');
      return this;
    } catch (e, stack) {
      debugPrint('❌ Error initializing StorageService: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// Crochet : nettoyage à la première ouverture d'une nouvelle version.
  /// Ne doit jamais empêcher l'app de démarrer.
  @protected
  Future<void> migrateIfNeeded() async {}

  /// Crochet : indicateurs propres à l'app, posés s'ils n'existent pas.
  @protected
  Map<String, bool> get extraDefaultFlags => const {};

  /// Crochet : clés des préférences propres à l'app, effacées avec la session.
  @protected
  List<String> get extraAuthKeys => const [];

  /// Crochet : appelé quand une connexion vient d'être enregistrée
  /// (la cliente y marque l'introduction comme vue).
  @protected
  Future<void> onSessionStarted() async {}

  Future<void> _ensureDefaultValues() async {
    final defaults = <String, bool>{
      ...extraDefaultFlags,
      'isLoginOrRegister': false,
      'isOtpVerification': false,
      'isResetPassword': false,
    };

    for (final entry in defaults.entries) {
      if (!storage.containsKey(entry.key)) {
        await storage.setBool(entry.key, entry.value);
        debugPrint('📝 Set default value for ${entry.key}: ${entry.value}');
      }
    }
  }

  SharedPreferences get storage {
    if (_prefs == null) {
      throw StateError('StorageService not initialized');
    }
    return _prefs!;
  }

  // ==================== JETONS ====================

  Future<String?> getAccessToken() async {
    try {
      final token = await secureStorage.read(key: 'accessToken');
      if (token == null || token.isEmpty) {
        debugPrint('📭 No access token found in storage');
        return null;
      }
      debugPrint('🔑 Access token retrieved from storage');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting access token: $e');
      return null;
    }
  }

  Future<void> saveAccessToken(String? token) async {
    if (token == null || token.isEmpty) {
      await secureStorage.delete(key: 'accessToken');
      return;
    }
    await secureStorage.write(key: 'accessToken', value: token);
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await secureStorage.read(key: 'refreshToken');
      if (token == null || token.isEmpty) {
        debugPrint('📭 No refresh token found in storage');
        return null;
      }
      debugPrint('🔑 Refresh token retrieved from storage');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting refresh token: $e');
      return null;
    }
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    if (refreshToken.isEmpty) {
      await secureStorage.delete(key: 'refreshToken');
      return;
    }
    await secureStorage.write(key: 'refreshToken', value: refreshToken);
  }

  Future<bool> isTokenValid() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return false;
      return !JWTUtils.isJWTExpired(token);
    } catch (e) {
      debugPrint('❌ Error validating token: $e');
      return false;
    }
  }

  Future<DateTime?> getTokenExpiryTime() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return null;
      final expiryTimestamp = JWTUtils.getJWTExpiry(token);
      if (expiryTimestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
    } catch (e) {
      debugPrint('❌ Error getting token expiry time: $e');
      return null;
    }
  }

  Future<bool> isTokenNearExpiry({int warningMinutes = 2}) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return false;
      return JWTUtils.isJWTNearExpiry(token, warningMinutes: warningMinutes);
    } catch (e) {
      debugPrint('❌ Error checking token near expiry: $e');
      return false;
    }
  }

  Future<int> getMinutesUntilExpiry() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return 0;
      return JWTUtils.getTimeUntilExpiry(token);
    } catch (e) {
      debugPrint('❌ Error getting minutes until expiry: $e');
      return 0;
    }
  }

  Future<Map<String, String?>> getUserInfoFromToken() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'userId': null, 'email': null};
      }
      return {
        'userId': JWTUtils.getUserIdFromJWT(token),
        'email': JWTUtils.getUserEmailFromJWT(token),
      };
    } catch (e) {
      debugPrint('❌ Error extracting user info from token: $e');
      return {'userId': null, 'email': null};
    }
  }

  Future<void> debugTokenInfo() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('🔍 DEBUG: No token found');
        return;
      }
      JWTUtils.debugJWTInfo(token);
    } catch (e) {
      debugPrint('❌ Error debugging token info: $e');
    }
  }

  // ==================== PARCOURS DE CONNEXION ====================

  Future<void> saveLoginData(
    String username,
    String email,
    String accessToken,
    String role,
  ) async {
    await storage.setString('username', username);
    await storage.setString('userEmail', email);
    await storage.setBool('isLoginOrRegister', true);
    await storage.setBool('isOtpVerification', true);
    await storage.setString('userRole', role);
    await secureStorage.write(key: 'accessToken', value: accessToken);
    await onSessionStarted();
  }

  Future<void> saveOtpVerificationData(
    String username,
    String email,
    String accessToken,
  ) async {
    await storage.setString('username', username);
    await storage.setString('userEmail', email);
    await storage.setBool('isLoginOrRegister', true);
    await storage.setBool('isOtpVerification', true);
    await secureStorage.write(key: 'accessToken', value: accessToken);
    await onSessionStarted();
  }

  Future<void> saveRegisterData(String username, String email) async {
    await storage.setString('username', username);
    await storage.setString('userEmail', email);
  }

  Future<void> saveTemporaryEmail(String email) async {
    await storage.setString(tempEmailKey, email);
  }

  Future<String?> getTemporaryEmail() async {
    return storage.getString(tempEmailKey);
  }

  Future<void> clearTemporaryEmail() async {
    await storage.remove(tempEmailKey);
  }

  /// Le jeton de vérification est un secret : stockage SÉCURISÉ. Une valeur
  /// laissée en clair par une ancienne version y est déplacée à la lecture.
  Future<void> saveTemporaryVerifyToken(String token) async {
    await secureStorage.write(key: tempVerifyTokenKey, value: token);
    await storage.remove(tempVerifyTokenKey);
  }

  Future<String?> getTemporaryVerifyToken() async {
    final secureToken = await secureStorage.read(key: tempVerifyTokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }
    final legacyToken = storage.getString(tempVerifyTokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await saveTemporaryVerifyToken(legacyToken);
      return legacyToken;
    }
    return null;
  }

  Future<void> clearTemporaryVerifyToken() async {
    await secureStorage.delete(key: tempVerifyTokenKey);
    await storage.remove(tempVerifyTokenKey);
  }

  Future<void> setIsResetPassword(bool status) async {
    await storage.setBool('isResetPassword', status);
  }

  Future<bool> getIsLoginOrRegister() async {
    return storage.getBool('isLoginOrRegister') ?? false;
  }

  Future<bool> getIsOtpVerification() async {
    return storage.getBool('isOtpVerification') ?? false;
  }

  Future<bool> getIsResetPassword() async {
    return storage.getBool('isResetPassword') ?? false;
  }

  // ==================== IDENTITÉ ====================

  Future<void> saveUsername(String username) async {
    await storage.setString('username', username);
  }

  Future<String?> getUsername() async {
    return storage.getString('username');
  }

  Future<void> saveEmail(String? email) async {
    if (email != null) {
      await storage.setString('userEmail', email);
    } else {
      await storage.remove('userEmail');
    }
  }

  Future<String?> getEmail() async {
    try {
      return storage.getString('userEmail');
    } catch (e) {
      debugPrint('Error getting email from storage: $e');
      return null;
    }
  }

  Future<void> saveUserId(String userId) async {
    await secureStorage.write(key: 'userId', value: userId);
  }

  Future<String?> getUserId() async {
    try {
      return await secureStorage.read(key: 'userId');
    } catch (e) {
      debugPrint('Error getting userId from storage: $e');
      return null;
    }
  }

  Future<void> saveUserRole(String role) async {
    await storage.setString('userRole', role);
  }

  Future<String?> getUserRole() async {
    return storage.getString('userRole');
  }

  Future<void> saveStoreId(String storeId) async {
    await storage.setString('storeId', storeId);
  }

  Future<String?> getStoreId() async {
    return storage.getString('storeId');
  }

  bool hasStoredEmail() {
    return storage.containsKey('userEmail');
  }

  Future<bool> hasStoredUserId() async {
    final userId = await secureStorage.read(key: 'userId');
    return userId != null && userId.isNotEmpty;
  }

  Future<bool> hasUserData() async {
    try {
      final token = await getAccessToken();
      final userId = await secureStorage.read(key: 'userId');
      final userEmail = storage.getString('userEmail');
      return token != null &&
          token.isNotEmpty &&
          ((userId != null && userId.isNotEmpty) ||
              (userEmail != null && userEmail.isNotEmpty));
    } catch (e) {
      debugPrint('❌ Error checking user data: $e');
      return false;
    }
  }

  // ==================== EFFACEMENT ====================

  Future<void> clearAllData() async {
    await storage.clear();
    await secureStorage.deleteAll();
  }

  /// Efface la session : jetons, identité, indicateurs du parcours de
  /// connexion, plus les clés propres à l'app ([extraAuthKeys]).
  Future<void> clearAuthData() async {
    try {
      debugPrint('🧹 Clearing auth data...');

      await secureStorage.delete(key: 'accessToken');
      await secureStorage.delete(key: 'refreshToken');
      await secureStorage.delete(key: 'userId');

      await storage.remove('username');
      await storage.remove('userEmail');
      await storage.remove('userRole');
      await storage.remove('isLoginOrRegister');
      await storage.remove('isOtpVerification');
      await storage.setBool('isResetPassword', false);
      for (final key in extraAuthKeys) {
        await storage.remove(key);
      }
      await clearTemporaryVerifyToken();

      debugPrint('✅ Auth data cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing auth data: $e');
      rethrow;
    }
  }
}
