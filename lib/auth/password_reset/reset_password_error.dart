import '../../debug_utils.dart';
import 'package:get/get.dart';

class ResetPasswordError implements Exception {
  final String message;
  final int errorCode;
  final bool success;

  ResetPasswordError({
    required this.message,
    required this.errorCode,
    this.success = false,
  });

  factory ResetPasswordError.fromJson(Map<String, dynamic> response) {
    try {
      // For forgot password endpoint, backend always returns success=true for security
      // This model is only used when there's an actual error (network, parsing, etc.)
      final statusCode = response['statusCode'] as int? ?? 500;
      final body = response['body'] as Map<String, dynamic>? ?? {};

      final message =
          body['message'] as String? ?? 'Password reset request failed';
      final success = body['success'] as bool? ?? false;

      return ResetPasswordError(
        message: _getTranslatedMessage(statusCode, message),
        errorCode: statusCode,
        success: success,
      );
    } catch (e) {
      debugPrint('❌ Error parsing ResetPasswordError: $e');
      debugPrint('❌ Response data: $response');

      return ResetPasswordError(
        message: 'auth.error.reset_password.unknown'.tr,
        errorCode: 500,
        success: false,
      );
    }
  }

  static String _getTranslatedMessage(int statusCode, String message) {
    // For forgot password endpoint, backend handles security by always returning success
    // This error handling is for network/parsing errors
    switch (statusCode) {
      case 500:
        return 'auth.error.reset_password.server_error'.tr;
      case 400:
        return 'auth.error.reset_password.invalid_request'.tr;
      default:
        return message.isNotEmpty
            ? message
            : 'auth.error.reset_password.unknown'.tr;
    }
  }

  @override
  String toString() => message;
}
