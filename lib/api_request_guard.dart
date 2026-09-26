import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_authentication_manager.dart';
import 'base_session_manager.dart';
import 'network_exceptions.dart';

/// En-têtes d'une requête protégée, avec un jeton vérifié (et renouvelé si
/// besoin) juste avant l'envoi.
///
/// - Session ouverte, jeton valide → en-têtes avec `Authorization`.
/// - Panne au renouvellement → `HttpException` 503 `REFRESH_UNAVAILABLE` :
///   la requête est RETENUE, la session tient. Jamais « non autorisé »,
///   jamais une requête envoyée sans jeton à la place.
/// - Aucune session : [guestHeaders] quand l'app accepte les invités
///   (la cliente), sinon `UnauthorizedException`.
Future<Map<String, String>> validatedRequestHeaders({
  required BaseSessionManager? sessionManager,
  required BaseAuthenticationManager? authManager,
  Map<String, String>? guestHeaders,
  Map<String, String> Function(String token)? authHeadersFor,
}) async {
  final hasSession =
      authManager != null &&
      (authManager.isUserLoggedIn || authManager.currentToken.value.isNotEmpty);

  if (!hasSession) {
    if (guestHeaders != null) return guestHeaders;
    throw UnauthorizedException('No session', errorCode: 'NO_SESSION');
  }

  if (sessionManager == null) {
    throw UnauthorizedException('SessionManager not available');
  }

  final isValid = await sessionManager.ensureValidTokenForRequest();
  if (!isValid) {
    if (sessionManager.isRefreshTemporarilyUnavailable) {
      debugPrint('🌐 ApiRequestGuard: refresh unavailable - session kept');
      throw HttpException(
        'core_session.unreachable'.tr,
        503,
        errorCode: 'REFRESH_UNAVAILABLE',
      );
    }
    if (guestHeaders != null) return guestHeaders;
    throw UnauthorizedException(
      'Token validation failed',
      errorCode: 'NO_SESSION',
    );
  }

  final token = authManager.currentToken.value;
  if (token.isEmpty) {
    if (guestHeaders != null) return guestHeaders;
    throw UnauthorizedException('No token available', errorCode: 'NO_SESSION');
  }

  if (authHeadersFor != null) return authHeadersFor(token);
  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
