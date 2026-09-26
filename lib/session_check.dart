/// Verdict du démarrage sur la session enregistrée.
///
/// Trois issues, pas deux : « le serveur n'a pas pu répondre » n'est PAS « le
/// serveur a refusé ». Les confondre déconnectait tout utilisateur qui
/// ouvrait l'app sans réseau ou pendant un redéploiement.
enum SessionCheck {
  /// Session confirmée (ou jeton encore valide et serveur injoignable).
  valid,

  /// Le serveur a répondu non : session effacée, retour à la connexion.
  refused,

  /// Pas de réponse exploitable (réseau, délai, 5xx, 429) : la session est
  /// GARDÉE, l'écran propose de réessayer.
  unreachable,
}
