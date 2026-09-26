import 'package:get/get.dart';

/// Échec du renouvellement de la connexion (`/auth/refresh`).
///
/// La seule question qui compte : le serveur a-t-il REFUSÉ le jeton
/// ([requiresReLogin] → la session est fermée), ou n'a-t-il pas pu répondre
/// (panne, 5xx, réponse illisible → la session est gardée) ?
class RefreshTokenError implements Exception {
  /// Le serveur n'a pas pu répondre : ce n'est PAS un refus du jeton.
  static const unreachableType = 'SERVER_UNREACHABLE';

  bool get isUnreachable => errorType == unreachableType;

  final String message;
  final String errorType;
  final bool success;
  final int statusCode;

  RefreshTokenError({
    required this.message,
    required this.errorType,
    required this.success,
    required this.statusCode,
  });

  factory RefreshTokenError.fromResponse(Map<String, dynamic> response) {
    try {
      final int statusCode = response['statusCode'] ?? 401;
      final body = response['body'];

      if (body is Map) {
        final detail = body['detail'];

        // Enveloppe `detail` structurée.
        if (detail is Map) {
          return RefreshTokenError(
            message:
                detail['message']?.toString() ??
                'core_session.refresh_failed'.tr,
            errorType: _normalizeErrorType(
              (detail['error_type'] ?? detail['error_code'] ?? detail['code'])
                  ?.toString(),
              detail['message']?.toString(),
              statusCode,
            ),
            success: detail['success'] == true,
            statusCode: statusCode,
          );
        }

        // Le handler global du serveur APLATIT le détail : `{success,
        // message, error_type}` sans enveloppe. Sans ce cas, un
        // `TOKEN_REVOKED` net devenait UNKNOWN_ERROR et la session morte
        // restait « connectée » en mémoire (vu sur appareil).
        final flatType =
            body['error_type'] ?? body['error_code'] ?? body['code'];
        final flatMessage = body['message'] ?? detail;
        if (flatType != null || flatMessage is String) {
          return RefreshTokenError(
            message:
                flatMessage?.toString() ?? 'core_session.refresh_failed'.tr,
            errorType: _normalizeErrorType(
              flatType?.toString(),
              flatMessage?.toString(),
              statusCode,
            ),
            success: body['success'] == true,
            statusCode: statusCode,
          );
        }
      }

      return RefreshTokenError(
        message: 'core_session.refresh_failed'.tr,
        errorType: _normalizeErrorType(null, null, statusCode),
        success: false,
        statusCode: statusCode,
      );
    } catch (e) {
      return RefreshTokenError(
        message: 'core_session.refresh_failed'.tr,
        errorType: 'PARSE_ERROR',
        success: false,
        statusCode: 500,
      );
    }
  }

  static String _mapStringToErrorType(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('not authorized') ||
        normalized.contains('whitelist')) {
      return 'TOKEN_NOT_AUTHORIZED';
    } else if (normalized.contains('rotated')) {
      return 'TOKEN_ROTATED';
    } else if (normalized.contains('revoked')) {
      return 'SESSION_REVOKED';
    } else if (normalized.contains('bad gateway') ||
        normalized.contains('service unavailable') ||
        normalized.contains('gateway timeout') ||
        normalized.contains('server error')) {
      return 'SERVICE_UNAVAILABLE';
    } else if (normalized.contains('invalid') ||
        normalized.contains('expired')) {
      return 'INVALID_REFRESH_TOKEN';
    }
    return 'REFRESH_ERROR';
  }

  static String _normalizeErrorType(
    String? rawType,
    String? message,
    int statusCode,
  ) {
    final normalizedType = rawType?.trim().toUpperCase();
    // Un 5xx est une panne du serveur, quel que soit le code joint.
    if (statusCode >= 500) {
      if (normalizedType == 'GATEWAY_TIMEOUT') return 'GATEWAY_TIMEOUT';
      return 'SERVICE_UNAVAILABLE';
    }
    if (normalizedType != null && normalizedType.isNotEmpty) {
      return normalizedType;
    }
    if (message != null && message.isNotEmpty) {
      return _mapStringToErrorType(message);
    }
    return 'UNKNOWN_ERROR';
  }

  String get userMessage {
    switch (errorType) {
      case 'INVALID_REFRESH_TOKEN':
        return 'auth.error.refresh.invalid_token'.tr;
      case 'USER_NOT_FOUND':
        return 'auth.error.refresh.user_not_found'.tr;
      case 'USER_INACTIVE':
        return 'auth.error.refresh.user_inactive'.tr;
      case 'TOKEN_NOT_AUTHORIZED':
        return 'auth.error.refresh.not_authorized'.tr;
      case 'TOKEN_ROTATED':
        return 'auth.error.refresh.token_rotated'.tr;
      case 'REFRESH_FAILED':
        return 'auth.error.refresh.failed'.tr;
      case 'TOKEN_REVOKED':
        return 'loading.error.token.revoked'.tr;
      case unreachableType:
        return 'core_session.unreachable'.tr;
      default:
        return 'auth.error.refresh.unknown'.tr;
    }
  }

  /// Refus EXPLICITE du serveur : la session doit être fermée.
  bool get requiresReLogin =>
      errorType == 'TOKEN_ROTATED' ||
      errorType == 'INVALID_REFRESH_TOKEN' ||
      errorType == 'USER_NOT_FOUND' ||
      errorType == 'USER_INACTIVE' ||
      errorType == 'TOKEN_REVOKED' ||
      errorType == 'SESSION_REVOKED';

  bool get isTemporaryError =>
      statusCode >= 500 ||
      errorType == 'REFRESH_FAILED' ||
      errorType == 'TOKEN_NOT_AUTHORIZED' ||
      errorType == 'SERVICE_UNAVAILABLE' ||
      errorType == 'GATEWAY_TIMEOUT' ||
      errorType == 'NETWORK_ERROR' ||
      errorType == 'TIMEOUT_ERROR' ||
      errorType == unreachableType;

  String get errorCode => errorType;
  String get status => success ? 'success' : 'error';

  @override
  String toString() =>
      'RefreshTokenError(message: $message, errorType: $errorType, statusCode: $statusCode)';
}
