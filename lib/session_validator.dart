import 'package:flutter/foundation.dart';

import 'jwt_utils.dart';
import 'refresh_token_error.dart';
import 'server_unreachable.dart';
import 'session_check.dart';
import 'verify_token_error.dart';

/// Décide, au démarrage, ce que vaut la session enregistrée.
///
/// Règle : **seul un refus explicite du serveur efface la session**. Une
/// absence de réponse (réseau, délai, 5xx pendant un redéploiement) la
/// garde : jeton encore valide → on entre ; jeton expiré → « réessayer ».
///
/// Pure (tout est injecté) pour être testée sans stockage ni réseau.
class SessionValidator {
  SessionValidator({
    required this.hasUserData,
    required this.readAccessToken,
    required this.verify,
    required this.refresh,
    required this.clearSession,
    bool Function(String token)? isValidStructure,
    bool Function(String token)? isExpired,
  }) : _isValidStructure = isValidStructure ?? JWTUtils.isValidJWTStructure,
       _isExpired = isExpired ?? JWTUtils.isJWTExpired;

  final Future<bool> Function() hasUserData;
  final Future<String?> Function() readAccessToken;

  /// `true` = le serveur confirme un compte actif ; `false` = il répond non.
  /// Lève en cas d'échec (classé ensuite en refus ou panne).
  final Future<bool> Function(String token) verify;

  /// Renouvelle ET enregistre les jetons ; lève en cas d'échec.
  final Future<void> Function() refresh;

  /// Efface la session (stockage + état en mémoire).
  final Future<void> Function() clearSession;

  final bool Function(String token) _isValidStructure;
  final bool Function(String token) _isExpired;

  Future<SessionCheck> check() async {
    if (!await hasUserData()) return SessionCheck.refused;

    final token = await readAccessToken();
    if (token == null || token.isEmpty) return SessionCheck.refused;
    if (!_isValidStructure(token)) {
      await clearSession();
      return SessionCheck.refused;
    }

    if (_isExpired(token)) {
      switch (await _tryRefresh()) {
        case SessionCheck.valid:
          // Le serveur vient de répondre au renouvellement : s'il ne répond
          // plus à la vérification, le nouveau jeton suffit.
          final fresh = await readAccessToken() ?? token;
          final verdict = await _tryVerify(fresh);
          if (verdict == SessionCheck.refused) {
            await clearSession();
          }
          return verdict == SessionCheck.refused
              ? SessionCheck.refused
              : SessionCheck.valid;
        case SessionCheck.unreachable:
          // Jeton expiré ET serveur injoignable : on ne peut pas entrer,
          // mais on ne déconnecte pas non plus.
          return SessionCheck.unreachable;
        case SessionCheck.refused:
          await clearSession();
          return SessionCheck.refused;
      }
    }

    switch (await _tryVerify(token)) {
      case SessionCheck.valid:
        return SessionCheck.valid;
      case SessionCheck.unreachable:
        // Jeton encore valide, serveur injoignable : on lui fait confiance.
        return SessionCheck.valid;
      case SessionCheck.refused:
        // Le serveur refuse ce jeton : un renouvellement peut encore sauver
        // la session (jeton d'accès révoqué, renouvellement accepté).
        final renewed = await _tryRefresh();
        if (renewed == SessionCheck.refused) await clearSession();
        return renewed;
    }
  }

  Future<SessionCheck> _tryVerify(String token) async {
    try {
      return await verify(token) ? SessionCheck.valid : SessionCheck.refused;
    } on VerifyTokenError catch (e) {
      debugPrint('[SESSION] verify: ${e.errorCode}');
      return e.isUnreachable ? SessionCheck.unreachable : SessionCheck.refused;
    } catch (e) {
      debugPrint('[SESSION] verify: ${e.runtimeType}');
      return isServerUnreachable(e)
          ? SessionCheck.unreachable
          : SessionCheck.refused;
    }
  }

  /// ⚠️ Un échec de renouvellement n'est un REFUS que si le serveur l'a dit
  /// ([RefreshTokenError.requiresReLogin]). Tout le reste — réseau, 502/503
  /// de la passerelle pendant un redéploiement, réponse illisible — garde la
  /// session : avant, un 503 au démarrage l'effaçait.
  Future<SessionCheck> _tryRefresh() async {
    try {
      await refresh();
      return SessionCheck.valid;
    } on RefreshTokenError catch (e) {
      debugPrint('[SESSION] refresh: ${e.errorType}');
      return e.requiresReLogin
          ? SessionCheck.refused
          : SessionCheck.unreachable;
    } catch (e) {
      debugPrint('[SESSION] refresh: ${e.runtimeType}');
      return isServerUnreachable(e)
          ? SessionCheck.unreachable
          : SessionCheck.refused;
    }
  }
}
