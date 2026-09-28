import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OtpVerificationError implements Exception {
  final String message;
  final bool success;
  final int statusCode;
  final String? errorType;
  final String? contactType;

  OtpVerificationError({
    required this.message,
    required this.success,
    required this.statusCode,
    this.errorType,
    this.contactType,
  });

  /// Message interne quand le serveur n'en donne pas. Jamais montré tel
  /// quel : [userMessage] le remplace par la traduction.
  static const fallbackMessage = 'Verification failed';

  factory OtpVerificationError.fromJson(Map<String, dynamic> response) {
    try {
      debugPrint('🔍 Parsing OtpVerificationError from response: $response');

      final statusCode = response['statusCode'] as int? ?? 500;
      final rawBody = response['body'];
      final body = rawBody is Map
          ? Map<String, dynamic>.from(rawBody)
          : <String, dynamic>{};

      // Check if this is a FastAPI validation error (422 with detail array)
      if (statusCode == 422 && body['detail'] is List) {
        debugPrint('🔍 Detected FastAPI validation error format');
        final detailList = body['detail'] as List;

        if (detailList.isNotEmpty) {
          final firstError = detailList[0] as Map<String, dynamic>;
          final loc = firstError['loc'] as List?;
          final field = loc != null && loc.length > 1
              ? loc.sublist(1).join('.')
              : 'unknown';
          final msg = firstError['msg'] as String? ?? 'Validation error';

          return OtpVerificationError(
            message: '$field: $msg',
            success: false,
            statusCode: statusCode,
            errorType: 'VALIDATION_ERROR',
          );
        }
      }

      // L'erreur est sous `detail` (HTTPException brute), ou À PLAT : le
      // serveur aplatit ses HTTPException (`message`, `error_code` au premier
      // niveau). Lire seulement `detail` perdait tout et affichait l'anglais
      // « Verification failed » (vu sur téléphone le 28/09).
      final detail = body['detail'] is Map
          ? Map<String, dynamic>.from(body['detail'] as Map)
          : body;
      final type = detail['error_type'] ?? detail['error_code'];

      return OtpVerificationError(
        message: detail['message'] as String? ?? fallbackMessage,
        success: detail['success'] as bool? ?? false,
        statusCode: statusCode,
        errorType: type?.toString(),
        contactType: detail['contact_type'] as String?,
      );
    } catch (e, stack) {
      debugPrint('❌ Error parsing OtpVerificationError: $e');
      debugPrint('Stack trace: $stack');
      return OtpVerificationError(
        message: fallbackMessage,
        success: false,
        statusCode: 500,
        errorType: 'PARSE_ERROR',
      );
    }
  }

  /// Le message à montrer, toujours traduit : jamais le repli anglais, ni un
  /// message technique de validation (« Value error, … »).
  String get userMessage {
    switch (errorType) {
      case 'USER_NOT_FOUND':
        return 'auth.otp.user_not_found'.tr;
      case 'INVALID_OTP':
        return 'auth.otp.invalid_expired'.tr;
      case 'INTERNAL_ERROR':
        return 'auth.error.internal_server'.tr;
      case 'VALIDATION_ERROR':
        return 'auth.otp.invalid_request'.tr;
      case 'TOO_MANY_OTP_ATTEMPTS':
        // Le serveur l'écrit pour l'utilisateur, en français.
        return _serverMessageOr('auth.otp.verification_failed');
    }

    switch (statusCode) {
      case 404:
        return 'auth.otp.user_not_found'.tr;
      case 400:
        return 'auth.otp.invalid_expired'.tr;
      case 422:
        return 'auth.otp.invalid_request'.tr;
      case 429:
        return _serverMessageOr('auth.otp.verification_failed');
      default:
        return 'auth.otp.verification_failed'.tr;
    }
  }

  String _serverMessageOr(String key) =>
      message.trim().isEmpty || message == fallbackMessage ? key.tr : message;

  @override
  String toString() =>
      'OtpVerificationError(message: $message, success: $success, statusCode: $statusCode, errorType: $errorType)';
}
