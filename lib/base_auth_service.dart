import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'auth/auth_error.dart';
import 'auth/otp/otp_error.dart';
import 'auth/otp/otp_request.dart';
import 'auth/otp/otp_success.dart';
import 'auth/password_reset/change_password_error.dart';
import 'auth/password_reset/change_password_request.dart';
import 'auth/password_reset/change_password_response.dart';
import 'auth/password_reset/otp_update_pass_error.dart';
import 'auth/password_reset/otp_update_pass_request.dart';
import 'auth/password_reset/otp_update_pass_success.dart';
import 'auth/password_reset/reset_password_error.dart';
import 'auth/password_reset/reset_password_request.dart';
import 'auth/password_reset/reset_password_response.dart';
import 'auth/verification/otp_verification_error.dart';
import 'auth/verification/otp_verification_request.dart';
import 'auth/verification/otp_verification_response.dart';
import 'base_api_service.dart';
import 'device_identity.dart';
import 'email_validation_error.dart';
import 'request_type.dart';

/// Parcours de connexion commun au vendeur et à la console : connexion, codes
/// par SMS/e-mail, mot de passe oublié, changement de mot de passe.
///
/// Chaque app garde sa classe `AuthService`, qui en hérite : elle fournit son
/// [apiService] et sa méthode `login` (champs propres à l'app et lecture de
/// sa réponse), plus ce qui n'existe que chez elle (inscription du vendeur).
///
/// Journal : jamais le corps d'une réponse ni le détail d'une erreur (jetons,
/// données personnelles) — seulement le type.
abstract class BaseAuthService extends GetxService {
  static const String loginEndpoint = '/auth/login';
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String resetPasswordEndpoint = '/auth/reset-password';
  static const String requestVerificationEndpoint =
      '/auth/request-verification';

  /// Crochet : le service d'API de l'app.
  BaseApiService get apiService;

  /// Connexion : envoie l'identifiant, le mot de passe et les champs propres
  /// à l'app ([roleFields], ex. `is_vendor`, `is_admin` + `admin_code`), puis
  /// lit la réponse avec [parse]. Lève [AuthError] (ou
  /// [EmailValidationError]) ; toute autre panne devient `INTERNAL_ERROR`.
  @protected
  Future<R> loginWith<R>({
    required String email,
    required String password,
    required Map<String, dynamic> roleFields,
    required R Function(dynamic body) parse,
  }) async {
    try {
      final response = await apiService.create(
        endpoint: loginEndpoint,
        data: {
          'username': email, // l'API attend « username », on envoie l'e-mail
          'password': password,
          ...roleFields,
        },
        // Étiquette l'appareil pour la liste des sessions (en-têtes
        // facultatifs côté serveur).
        additionalHeaders: await DeviceIdentity.headers(),
        type: RequestType.loginAuth,
      );

      final statusCode = response['statusCode'];
      debugPrint('📥 Login response status: $statusCode');
      if (statusCode >= 400) {
        final error = AuthError.fromResponse(response);
        debugPrint('🔒 Auth error: ${error.errorType}');
        throw error;
      }
      return parse(response['body']);
    } catch (e) {
      if (e is AuthError || e is EmailValidationError) rethrow;
      debugPrint('❌ Login error: ${e.runtimeType}');
      throw AuthError(
        success: false,
        message: 'auth.error.internal_error'.tr,
        errorType: 'INTERNAL_ERROR',
        statusCode: 500,
      );
    }
  }

  Future<ResetPasswordResponse> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      final response = await apiService.create(
        endpoint: forgotPasswordEndpoint,
        data: request.toJson(),
        type: RequestType.auth,
      );
      if (response['statusCode'] >= 400) {
        throw ResetPasswordError.fromJson(response);
      }
      return ResetPasswordResponse.fromJson(response['body']);
    } catch (e) {
      debugPrint('❌ Reset password error: ${e.runtimeType}');
      if (e is ResetPasswordError) rethrow;
      throw ResetPasswordError(
        message: 'auth.error.reset_password.unknown'.tr,
        errorCode: 0,
        success: false,
      );
    }
  }

  Future<ChangePasswordResponse> changePassword(
    ChangePasswordRequest request,
  ) async {
    try {
      final response = await apiService.update(
        endpoint: resetPasswordEndpoint,
        data: request.toJson(),
        type: RequestType.auth,
      );
      if (response['statusCode'] >= 400) {
        throw ChangePasswordError.fromJson(response);
      }
      return ChangePasswordResponse.fromJson(response['body']);
    } catch (e) {
      debugPrint('❌ Change password error: ${e.runtimeType}');
      if (e is ChangePasswordError) rethrow;
      throw ChangePasswordError(
        message: 'auth.error.change_password.unknown'.tr,
        errorCode: 0,
        success: false,
      );
    }
  }

  Future<OtpVerificationResponse> verifyOtp(
    OtpVerificationRequest request,
  ) async {
    try {
      final response = await apiService.create(
        endpoint: request.endpoint, // selon le type de vérification
        data: request.toJson(),
        type: RequestType.auth,
      );
      if (response['statusCode'] >= 400) {
        throw OtpVerificationError.fromJson(response);
      }
      return OtpVerificationResponse.fromJson(response['body']);
    } catch (e) {
      debugPrint('❌ OTP verification error: ${e.runtimeType}');
      if (e is OtpVerificationError) rethrow;
      throw OtpVerificationError(
        message: 'auth.error.otp.verification_failed'.tr,
        success: false,
        statusCode: 0,
      );
    }
  }

  Future<OtpSuccess> sendOtp(OtpRequest request) async {
    try {
      final response = await apiService.create(
        endpoint: requestVerificationEndpoint,
        data: request.toJson(),
        type: RequestType.auth,
      );
      if (response['statusCode'] >= 400) {
        throw OtpError.fromJson(response);
      }
      return OtpSuccess.fromJson(response['body']);
    } catch (e) {
      debugPrint('❌ Send OTP error: ${e.runtimeType}');
      if (e is OtpError) rethrow;
      throw OtpError(
        message: 'auth.error.otp.send_failed'.tr,
        success: false,
        statusCode: 500,
      );
    }
  }

  Future<OtpUpdatePassSuccess> updatePasswordWithOtp(
    OtpUpdatePassRequest request,
  ) async {
    try {
      final response = await apiService.create(
        endpoint: resetPasswordEndpoint,
        data: request.toJson(),
        type: RequestType.auth,
      );
      if (response['statusCode'] >= 400) {
        throw OtpUpdatePassError.fromJson(response);
      }
      return OtpUpdatePassSuccess.fromJson(response['body']);
    } catch (e) {
      debugPrint('❌ Update password with OTP error: ${e.runtimeType}');
      if (e is OtpUpdatePassError) rethrow;
      throw OtpUpdatePassError(
        message: 'auth.otp.update_password_failed'.tr,
        success: false,
        statusCode: 500,
      );
    }
  }
}
