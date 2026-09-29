import 'dart:async';

class HttpException implements Exception {
  final String message;
  final int status;
  final String? errorCode;

  /// Corps de l'erreur renvoyé par le serveur (`message`, `error_code`,
  /// `field`, `errors`…), à plat. `null` quand le serveur n'a rien dit.
  final Map<String, dynamic>? payload;

  /// Aucune réponse du serveur (réseau coupé, serveur injoignable) : ≠ un
  /// refus, même si le statut vaut 503.
  final bool noAnswer;

  HttpException(
    this.message,
    this.status, {
    this.errorCode,
    this.payload,
    this.noAnswer = false,
  });

  /// Champ du formulaire visé par le refus (`field` du serveur).
  String? get field => payload?['field']?.toString();

  @override
  String toString() =>
      'HttpException: $message (Status: $status${errorCode != null ? ', Code: $errorCode' : ''})';
}

/// Vrai quand [error] veut dire « le serveur n'a pas répondu » (réseau
/// coupé, délai dépassé, serveur injoignable) — et non « le serveur a
/// refusé ». Un refus (409, 404, 422…) garde son message : l'afficher comme
/// « pas de connexion » trompe l'utilisateur (dossier vendeur, 29/09 : un
/// numéro de pièce déjà pris s'affichait « Pas de connexion »).
bool isNoServerAnswer(Object error) {
  if (error is HttpException) return error.noAnswer;
  // Le client HTTP ramène coupures et sockets à HttpException(noAnswer) ;
  // seul le délai dépassé arrive tel quel. Une autre exception (JSON
  // illisible…) n'est PAS une coupure.
  return error is TimeoutException;
}

class UnauthorizedException implements Exception {
  final String message;
  final String? errorCode;

  UnauthorizedException(this.message, {this.errorCode});

  @override
  String toString() =>
      'UnauthorizedException: $message${errorCode != null ? ' (Code: $errorCode)' : ''}';
}
