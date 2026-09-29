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
