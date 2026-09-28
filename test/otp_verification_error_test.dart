import 'package:ebenivoire_common/auth/verification/otp_verification_error.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'fr': {
      'auth.otp.verification_failed': 'Échec de la vérification',
      'auth.otp.invalid_request': 'Requête invalide',
      'auth.otp.invalid_expired': 'Code incorrect ou expiré',
      'auth.otp.user_not_found': 'Compte introuvable',
    },
  };
}

/// Le serveur APLATIT ses erreurs (`message`, `error_code` au premier
/// niveau) : lues seulement sous `detail`, elles donnaient l'anglais
/// « Verification failed » à l'écran (vu sur téléphone le 28/09).
void main() {
  setUpAll(() {
    Get.addTranslations(_Messages().keys);
    Get.locale = const Locale('fr');
  });

  test('erreur à plat : le code du serveur est lu', () {
    final e = OtpVerificationError.fromJson({
      'statusCode': 400,
      'body': {
        'success': false,
        'message': 'Code incorrect ou expiré.',
        'error_code': 'INVALID_OTP',
      },
    });
    expect(e.errorType, 'INVALID_OTP');
    expect(e.userMessage, 'Code incorrect ou expiré');
  });

  test(
    '422 du serveur (validation) : jamais l\'anglais ni « Value error »',
    () {
      final e = OtpVerificationError.fromJson({
        'statusCode': 422,
        'body': {
          'success': false,
          'message':
              'Erreur de validation: Value error, Saisissez une adresse e-mail',
          'error_code': 'VALIDATION_ERROR',
        },
      });
      expect(e.userMessage, 'Requête invalide');
    },
  );

  test('corps vide : message traduit, pas le repli anglais', () {
    final e = OtpVerificationError.fromJson({'statusCode': 500, 'body': null});
    expect(e.userMessage, 'Échec de la vérification');
    expect(e.userMessage, isNot(OtpVerificationError.fallbackMessage));
  });

  test('trop de tentatives : la phrase française du serveur', () {
    final e = OtpVerificationError.fromJson({
      'statusCode': 429,
      'body': {
        'detail': {
          'message': 'Trop de tentatives. Réessayez dans quelques minutes.',
          'error_type': 'TOO_MANY_OTP_ATTEMPTS',
        },
      },
    });
    expect(e.userMessage, startsWith('Trop de tentatives'));
  });
}
