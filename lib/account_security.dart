import 'package:get/get.dart';

/// L'état sécurité du compte, tel que le backend le donne.
///
/// `GET /api/profile/me/security` — une route commune aux trois rôles, parce
/// que le profil simplifié qui portait déjà ces informations est réservé au
/// rôle CLIENT, et que le vendeur comme l'admin ont chacun leur propre schéma.
class AccountSecurity {
  /// Ce compte peut-il se connecter avec un mot de passe ?
  ///
  /// ⚠️ Calculé PAR LE BACKEND, jamais ici. Un compte créé via Google porte un
  /// hash argon2 aléatoire que son propriétaire n'a jamais connu : la présence
  /// d'un mot de passe en base ne dit rien de sa capacité à s'en servir.
  final bool hasPassword;

  /// `google`, … quand il n'y a pas de mot de passe.
  final String? oauthProvider;

  /// Le contact de connexion, et sa nature (`email` ou `phone`).
  final String contact;
  final String contactType;

  final bool isVerified;

  /// Identité : qui est connecté (nom, e-mail, rôle d'administration).
  final String displayName;
  final String? email;
  final String? phone;
  final String? adminRole;

  const AccountSecurity({
    required this.hasPassword,
    this.oauthProvider,
    required this.contact,
    required this.contactType,
    this.isVerified = false,
    this.displayName = '',
    this.email,
    this.phone,
    this.adminRole,
  });

  factory AccountSecurity.fromJson(Map<String, dynamic> json) {
    return AccountSecurity(
      // Défaut `true` : le cas majoritaire. Une réponse antérieure à ce champ
      // ne doit pas priver de l'entrée les comptes qui ont un mot de passe.
      hasPassword: json['has_password'] != false,
      oauthProvider: json['oauth_provider']?.toString(),
      contact: json['contact']?.toString() ?? '',
      contactType: json['contact_type']?.toString() ?? 'email',
      isVerified: json['is_verified'] == true,
      displayName: json['display_name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      adminRole: json['admin_role']?.toString(),
    );
  }

  bool get isEmail => contactType.toLowerCase() == 'email';

  /// Le nom à montrer, ou `null` si le compte a un mot de passe.
  String? get providerLabel {
    if (hasPassword) return null;
    switch (oauthProvider?.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'facebook':
        return 'Facebook';
      case 'apple':
        return 'Apple';
      default:
        return null;
    }
  }
}

/// Où en est le changement de contact après la première étape.
///
/// Un compte sans mot de passe ne peut rien prouver par mot de passe : le
/// backend lui envoie d'abord un code sur son contact ACTUEL. Ce n'est pas une
/// erreur, c'est une étape — d'où ce type plutôt qu'une exception.
class ContactChangeStep {
  /// `true` quand il faut d'abord saisir un code reçu sur l'ANCIEN contact.
  final bool needsCurrentOtp;

  /// `email` ou `phone` — la nature du nouveau contact.
  final String kind;

  /// Le message du serveur, déjà rédigé pour l'utilisateur.
  final String message;

  const ContactChangeStep({
    required this.needsCurrentOtp,
    required this.kind,
    this.message = '',
  });

  const ContactChangeStep.codeSent(this.kind)
    : needsCurrentOtp = false,
      message = '';

  const ContactChangeStep.verifyCurrent(this.kind, this.message)
    : needsCurrentOtp = true;
}

/// Une erreur du parcours compte, qui CONSERVE le code d'erreur du serveur.
///
/// Sans lui, l'écran ne peut pas distinguer « il faut un mot de passe » de
/// « cette adresse est déjà prise » et retombe sur un message attrape-tout.
class AccountException implements Exception {
  final String message;
  final String? errorCode;

  const AccountException(this.message, {this.errorCode});

  /// Traduit le code d'erreur du serveur ; à défaut, garde SON message.
  ///
  /// ⚠️ Ne jamais remplacer un message serveur inconnu par un texte générique :
  /// c'est ainsi qu'on perd la seule explication utile que le client aurait pu
  /// lire.
  factory AccountException.fromBody(dynamic body, int statusCode) {
    String? code;
    String? serverMessage;

    final detail = body is Map ? body['detail'] : null;
    if (detail is Map) {
      code = detail['error_code']?.toString();
      serverMessage = detail['message']?.toString();
    } else if (detail != null) {
      serverMessage = detail.toString();
    }

    return AccountException(
      _messageFor(code, serverMessage, statusCode),
      errorCode: code,
    );
  }

  factory AccountException.fromMessage(String raw, {String? errorCode}) {
    return AccountException(
      _messageFor(errorCode, raw, null),
      errorCode: errorCode,
    );
  }

  static String _messageFor(String? code, String? serverMessage, int? _) {
    // ⚠️ Ces codes sont exactement les clés de `_CONTACT_ERRORS` du backend,
    // mises en majuscules (`routers/users/profile.py`). Un code inconnu n'est
    // pas grave — on retombe alors sur le message du serveur, déjà en français.
    switch (code) {
      case 'PASSWORD_REQUIRED':
        return 'account.contact.error.password_required'.tr;
      case 'WRONG_PASSWORD':
        return 'account.contact.error.wrong_password'.tr;
      case 'WRONG_CURRENT_OTP':
        return 'account.contact.error.wrong_current_otp'.tr;
      case 'TAKEN':
        return 'account.contact.error.taken'.tr;
      case 'SAME_CONTACT':
        return 'account.contact.error.same'.tr;
      case 'INVALID_CONTACT':
        return 'account.contact.error.invalid'.tr;
      case 'DISPOSABLE_EMAIL':
        return 'account.contact.error.disposable'.tr;
      case 'INVALID_OTP':
        return 'account.contact.error.invalid_otp'.tr;
      case 'SEND_FAILED':
        return 'account.contact.error.send_failed'.tr;
      case 'OAUTH_ACCOUNT_NO_PASSWORD':
        return 'account.password.error.social'.tr;
      case 'WRONG_CURRENT_PASSWORD':
        return 'account.password.error.wrong_current'.tr;
      case 'SAME_PASSWORD':
        return 'account.password.error.same'.tr;
    }
    // Le message du serveur vaut mieux qu'un texte générique.
    if (serverMessage != null && serverMessage.trim().isNotEmpty) {
      return serverMessage;
    }
    return 'account.error.generic'.tr;
  }

  @override
  String toString() => message;
}
