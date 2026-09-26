import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Adresse e-mail refusée par le serveur à l'inscription (domaine réservé,
/// adresse jetable, format…).
class EmailValidationError implements Exception {
  final String code;
  final String errorType;
  final String message;
  final String? domain;
  final String? reason;
  final int statusCode;

  EmailValidationError({
    required this.code,
    required this.errorType,
    required this.message,
    this.domain,
    this.reason,
    required this.statusCode,
  });

  /// Lit `{statusCode, body: {detail: {error_code, message, domain, reason}}}`.
  /// Rien de la réponse n'est écrit dans le journal (l'adresse en fait partie).
  factory EmailValidationError.fromResponse(Map<String, dynamic> response) {
    try {
      final body = response['body'] as Map<String, dynamic>;
      final detail = body['detail'] as Map<String, dynamic>;
      debugPrint('EmailValidationError: ${detail['error_code'] ?? 'unknown'}');
      return EmailValidationError(
        code: detail['error_code'] ?? 'UNKNOWN_ERROR',
        errorType: detail['error_code'] ?? 'UNKNOWN_ERROR',
        message: detail['message'] ?? 'core.error.something_went_wrong'.tr,
        domain: detail['domain'],
        reason: detail['reason'],
        statusCode: response['statusCode'] ?? 400,
      );
    } catch (e) {
      debugPrint(
        'EmailValidationError: unreadable response (${e.runtimeType})',
      );
      return EmailValidationError(
        code: 'parse_error',
        errorType: 'PARSE_ERROR',
        message: 'core.error.something_went_wrong'.tr,
        statusCode: 500,
      );
    }
  }

  String get userMessage {
    switch (errorType) {
      case 'RESERVED_DOMAIN':
        return 'auth.error.email.reserved_domain'.tr;
      case 'DISPOSABLE_EMAIL':
        return 'auth.error.email.disposable'.tr;
      case 'SUSPICIOUS_EMAIL_PATTERN':
        return 'auth.error.email.suspicious'.tr;
      case 'INVALID_EMAIL_FORMAT':
        return 'auth.error.email.invalid_format'.tr;
      default:
        return message;
    }
  }
}
