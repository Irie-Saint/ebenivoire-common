import '../debug_utils.dart';
import 'package:get/get.dart';

class AuthError implements Exception {
  final bool success;
  final String message;
  final String errorType;
  final int statusCode;
  final String? email;
  final bool? requiresVerification;
  final bool? requiresPasswordReset;
  final String? userRole;

  /// Minutes avant de pouvoir réessayer (blocage après échecs répétés).
  final int? retryAfterMinutes;

  /// Adresse masquée où le code de connexion a été envoyé (super admins).
  final String? emailHint;

  AuthError({
    required this.success,
    required this.message,
    required this.errorType,
    required this.statusCode,
    this.email,
    this.requiresVerification,
    this.requiresPasswordReset,
    this.userRole,
    this.retryAfterMinutes,
    this.emailHint,
  });

  factory AuthError.fromResponse(Map<String, dynamic> response) {
    try {
      debugPrint('\n🔍 Parsing AuthError from response:');
      debugPrint('Full Response: $response');

      final statusCode = response['statusCode'] as int? ?? 400;
      final body = response['body'] as Map<String, dynamic>;

      // Check if error is nested in 'detail' or directly in 'body'
      final errorData = body['detail'] as Map<String, dynamic>? ?? body;

      debugPrint('Error data: $errorData');

      final authError = AuthError(
        success: errorData['success'] as bool? ?? false,
        message: errorData['message'] as String? ?? 'Unknown error',
        errorType: errorData['error_type'] as String? ?? 'UNKNOWN_ERROR',
        statusCode: statusCode,
        email: errorData['email'] as String?,
        requiresVerification: errorData['requires_verification'] as bool?,
        requiresPasswordReset: errorData['requires_password_reset'] as bool?,
        userRole: errorData['user_role'] as String?,
        retryAfterMinutes: errorData['retry_after_minutes'] as int?,
        emailHint: errorData['email_hint'] as String?,
      );

      debugPrint('\n✅ Successfully parsed AuthError:');
      debugPrint('Type: ${authError.errorType}');
      debugPrint('Message: ${authError.message}');
      debugPrint('Success: ${authError.success}');
      debugPrint('Email: ${authError.email}');
      debugPrint('Requires Verification: ${authError.requiresVerification}\n');

      return authError;
    } catch (e, stack) {
      debugPrint('\n❌ Error parsing AuthError:');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace:\n$stack');
      debugPrint('Response was: $response\n');

      return AuthError(
        success: false,
        message: 'Failed to parse error response',
        errorType: 'PARSE_ERROR',
        statusCode: 500,
      );
    }
  }

  String get userMessage {
    // Use error type for more accurate message mapping
    switch (errorType) {
      case 'INVALID_CREDENTIALS':
      case 'INVALID_EMAIL_CREDENTIALS':
      case 'INVALID_USERNAME_CREDENTIALS':
        return 'auth.error.invalid_credentials'.tr;
      case 'ACCOUNT_NOT_VERIFIED':
        return 'auth.error.account_not_verified'.tr;
      case 'ACCOUNT_INACTIVE':
        return 'auth.error.account_inactive'.tr;
      case 'NOT_VENDOR':
        return 'auth.error.not_vendor'.tr;
      case 'NOT_ADMIN':
        return 'auth.error.not_admin'.tr;
      case 'NO_ADMIN_ROLE':
        return 'auth.error.no_admin_role'.tr;
      case 'SESSION_REVOKED':
        return 'auth.error.session_revoked'.tr;
      case 'RATE_LIMITED':
        return 'auth.error.rate_limited'.trParams({
          'minutes': '${retryAfterMinutes ?? 1}',
        });
      case 'INTERNAL_ERROR':
        return 'auth.error.internal_error'.tr;
      case 'ADMIN_CODE_REQUIRED':
        return 'auth.admin_code.sent'.trParams({'email': emailHint ?? ''});
      case 'ADMIN_CODE_INVALID':
        return 'auth.admin_code.invalid'.tr;
      case 'USER_EXISTS':
        return 'auth.error.account_exists'.tr;
      case 'INVALID_EMAIL':
        return 'auth.error.invalid_email'.tr;
      case 'MISSING_CREDENTIALS':
        return 'auth.error.missing_credentials'.tr;
      case 'TOKEN_EXPIRED':
        return 'auth.error.token_expired'.tr;
      case 'SESSION_EXPIRED':
        return 'auth.error.session_expired'.tr;
      case 'MISSING_EMAIL':
        return 'auth.error.missing_email'.tr;
      case 'MISSING_PASSWORD':
        return 'auth.error.missing_password'.tr;
      case 'ACCOUNT_CREATION_FAILED':
        return 'auth.error.account_creation'.tr;
      case 'MISSING_NEW_PASSWORD':
        return 'auth.error.missing_new_password'.tr;
      case 'MIGRATED_USER_PASSWORD_RESET_REQUIRED':
        return 'auth.error.migrated_user_password_reset'.tr;
      default:
        // If no specific mapping, return the message from the API
        return message.isNotEmpty ? message : 'auth.error.unknown'.tr;
    }
  }

  // Helper methods for verification flow
  bool get isAccountNotVerified => errorType == 'ACCOUNT_NOT_VERIFIED';
  bool get isAccountInactive => errorType == 'ACCOUNT_INACTIVE';
  bool get isAdminCodeRequired => errorType == 'ADMIN_CODE_REQUIRED';
  bool get isAdminCodeInvalid => errorType == 'ADMIN_CODE_INVALID';
  bool get isInvalidCredentials => errorType == 'INVALID_CREDENTIALS';
  bool get isMigratedUserPasswordResetRequired =>
      errorType == 'MIGRATED_USER_PASSWORD_RESET_REQUIRED';
  bool get isNotVendor => errorType == 'NOT_VENDOR';
  bool get needsVerification => requiresVerification == true;
  bool get needsPasswordReset => requiresPasswordReset == true;

  @override
  String toString() =>
      'AuthError(type: $errorType, message: $message, statusCode: $statusCode)';
}
