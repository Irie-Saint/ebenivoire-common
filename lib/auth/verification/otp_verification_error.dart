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

  factory OtpVerificationError.fromJson(Map<String, dynamic> response) {
    try {
      debugPrint('🔍 Parsing OtpVerificationError from response: $response');

      final statusCode = response['statusCode'] as int? ?? 500;
      final body = response['body'] ?? {};

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

      // Handle custom error format with detail as Map
      final detail = body['detail'] is Map<String, dynamic>
          ? body['detail'] as Map<String, dynamic>
          : {};

      return OtpVerificationError(
        message: detail['message'] as String? ?? 'Verification failed',
        success: detail['success'] as bool? ?? false,
        statusCode: statusCode,
        errorType: detail['error_type'] as String?,
        contactType: detail['contact_type'] as String?,
      );
    } catch (e, stack) {
      debugPrint('❌ Error parsing OtpVerificationError: $e');
      debugPrint('Stack trace: $stack');
      return OtpVerificationError(
        message: 'Verification failed',
        success: false,
        statusCode: 500,
        errorType: 'PARSE_ERROR',
      );
    }
  }

  String get userMessage {
    // Map error types to user-friendly messages
    if (errorType != null) {
      switch (errorType) {
        case 'USER_NOT_FOUND':
          return 'auth.otp.user_not_found'.tr;
        case 'INVALID_OTP':
          return 'auth.otp.invalid_expired'.tr;
        case 'INTERNAL_ERROR':
          return 'auth.error.internal_server'.tr;
        case 'VALIDATION_ERROR':
          return message; // Show validation message directly
      }
    }

    // Map status codes to user-friendly messages
    switch (statusCode) {
      case 404:
        return 'auth.otp.user_not_found'.tr;
      case 400:
        if (message.contains('Invalid or expired OTP')) {
          return 'auth.otp.invalid_expired'.tr;
        }
        return 'auth.otp.invalid_expired'.tr;
      case 422:
        return message; // Show validation message
      case 500:
        return 'auth.otp.verification_failed'.tr;
      default:
        return 'auth.otp.verification_failed'.tr;
    }
  }

  @override
  String toString() =>
      'OtpVerificationError(message: $message, success: $success, statusCode: $statusCode, errorType: $errorType)';
}
