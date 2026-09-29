import 'package:get/get.dart';

import 'network_exceptions.dart';

/// Le texte à montrer pour une erreur attrapée autour d'un appel au serveur.
///
/// * refus du serveur (409, 404, 403…) : SON message, déjà en français ;
/// * pas de réponse (réseau coupé, délai, serveur injoignable) :
///   « Pas de connexion… » ;
/// * tout le reste : [fallback], le message de l'écran.
///
/// Jamais le texte brut de l'exception (« HttpException: … (Status: 409) »),
/// ni un « pas de connexion » pour un refus.
String userMessageOf(Object error, {required String fallback}) {
  if (isNoServerAnswer(error)) return 'core.error.no_connection'.tr;
  if (error is HttpException) {
    final message = error.message.trim();
    return message.isEmpty ? fallback : message;
  }
  if (error is UnauthorizedException) {
    final message = error.message.trim();
    // Un refus d'identifiants garde son message ; « token invalide » (session)
    // n'a rien à dire à l'utilisateur.
    return message.isEmpty || message.toLowerCase().contains('token')
        ? fallback
        : message;
  }
  return fallback;
}

/// Le texte d'une erreur quelconque attrapée par un écran.
///
/// * refus / coupure du serveur : comme [userMessageOf] ;
/// * `Exception('…')` d'un service : son texte, sans « Exception: » ;
/// * erreur typée de l'app qui porte un `message` : ce message ;
/// * bug (Error) ou autre : [fallback] (« Une erreur est survenue » par
///   défaut), jamais le texte technique.
String errorTextOf(Object error, {String? fallback}) {
  final fb = fallback ?? 'core.error.something_went_wrong'.tr;
  if (error is HttpException ||
      error is UnauthorizedException ||
      isNoServerAnswer(error)) {
    return userMessageOf(error, fallback: fb);
  }
  if (error is Error) return fb;
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    final message = text.substring('Exception: '.length).trim();
    return message.isEmpty ? fb : message;
  }
  try {
    final message = (error as dynamic).message;
    if (message is String && message.trim().isNotEmpty) return message.trim();
  } catch (_) {
    // Pas de champ `message` : le texte générique.
  }
  return fb;
}
