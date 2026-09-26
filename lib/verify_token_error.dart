import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Échec de la vérification du jeton au démarrage (`/auth/verify-token`).
class VerifyTokenError implements Exception {
  /// Le serveur n'a pas pu répondre (réseau, délai, 5xx). Ce n'est pas un
  /// refus : la session doit être gardée.
  static const unreachableCode = 'SERVER_UNREACHABLE';

  bool get isUnreachable => errorCode == unreachableCode;

  final String message;
  final String errorCode;
  final String status;
  final bool success;

  VerifyTokenError({
    required this.message,
    required this.errorCode,
    this.status = 'error',
    this.success = false,
  });

  /// Lit `{body: {detail: {message, error_code, status, success}}}`. Rien de
  /// la réponse n'est écrit dans le journal (données personnelles).
  factory VerifyTokenError.fromJson(Map<String, dynamic> response) {
    try {
      final body = response['body'] as Map<String, dynamic>;
      final detail = body['detail'] as Map<String, dynamic>;
      debugPrint('VerifyTokenError: ${detail['error_code'] ?? 'unknown'}');
      return VerifyTokenError(
        message: detail['message'] as String,
        errorCode: detail['error_code'] as String,
        status: detail['status'] as String? ?? 'error',
        success: detail['success'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('VerifyTokenError: unreadable response (${e.runtimeType})');
      return VerifyTokenError(
        message: 'loading.error.token.unknown'.tr,
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  String get translatedMessage {
    switch (errorCode) {
      case 'TOKEN_EXPIRED':
        return 'loading.error.token.expired'.tr;
      case 'TOKEN_REVOKED':
        return 'loading.error.token.revoked'.tr;
      case 'INVALID_TOKEN':
        return 'loading.error.token.invalid'.tr;
      case 'VERIFICATION_ERROR':
        return 'loading.error.token.verification_failed'.tr;
      case unreachableCode:
        return 'core_session.unreachable'.tr;
      default:
        return 'loading.error.token.unknown'.tr;
    }
  }

  @override
  String toString() => translatedMessage;
}
