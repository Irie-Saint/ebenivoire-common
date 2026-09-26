import 'package:get/get.dart';

class OtpUpdatePassError implements Exception {
  final String message;
  final bool success;
  final int statusCode;

  OtpUpdatePassError({
    required this.message,
    required this.success,
    required this.statusCode,
  });

  factory OtpUpdatePassError.fromJson(Map<String, dynamic> response) {
    final statusCode = response['statusCode'] as int? ?? 500;
    final body = response['body'] ?? {};
    final detail = body['detail'] ?? {};

    return OtpUpdatePassError(
      message: detail['message'] ?? 'Failed to update password',
      success: detail['success'] ?? false,
      statusCode: statusCode,
    );
  }

  String get userMessage {
    // Map status codes and error types to user-friendly messages
    switch (statusCode) {
      case 404:
        return 'auth.otp.user_not_found'.tr;
      case 400:
        if (message.contains('Invalid or expired verification token') ||
            message.contains('INVALID_TOKEN')) {
          return 'auth.otp.invalid_token'.tr;
        }
        return 'auth.otp.invalid_request'.tr;
      case 500:
        if (message.contains('INTERNAL_ERROR')) {
          return 'auth.error.internal_server'.tr;
        }
        return 'auth.otp.update_password_failed'.tr;
      default:
        return 'auth.otp.update_password_failed'.tr;
    }
  }

  @override
  String toString() =>
      'OtpUpdatePassError(message: $message, success: $success, statusCode: $statusCode)';
}
