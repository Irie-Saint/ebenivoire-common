import '../../debug_utils.dart';
import 'package:get/get.dart';

class ChangePasswordError implements Exception {
  final String message;
  final int errorCode;
  final bool success;

  ChangePasswordError({
    required this.message,
    required this.errorCode,
    this.success = false,
  });

  factory ChangePasswordError.fromJson(Map<String, dynamic> response) {
    try {
      final statusCode = response['statusCode'] as int? ?? 500;
      final body = response['body'] as Map<String, dynamic>? ?? {};
      final detail = body['detail'] as Map<String, dynamic>? ?? {};

      final message = detail['message'] as String? ?? 'Password reset failed';
      final errorType = detail['error_type'] as String? ?? '';
      final success = detail['success'] as bool? ?? false;

      return ChangePasswordError(
        message: _getTranslatedMessage(statusCode, errorType, message),
        errorCode: statusCode,
        success: success,
      );
    } catch (e) {
      debugPrint('❌ Error parsing ChangePasswordError: $e');
      debugPrint('❌ Response data: $response');

      return ChangePasswordError(
        message: 'auth.error.change_password.unknown'.tr,
        errorCode: 500,
        success: false,
      );
    }
  }

  static String _getTranslatedMessage(
    int statusCode,
    String errorType,
    String message,
  ) {
    switch (statusCode) {
      case 400:
        if (errorType == 'INVALID_TOKEN') {
          return 'auth.error.change_password.invalid_code'.tr;
        }
        return 'auth.error.change_password.invalid_request'.tr;
      case 500:
        if (errorType == 'INTERNAL_ERROR') {
          return 'auth.error.internal_error'.tr;
        }
        return 'auth.error.change_password.server_error'.tr;
      default:
        return message.isNotEmpty
            ? message
            : 'auth.error.change_password.unknown'.tr;
    }
  }

  @override
  String toString() => message;
}
