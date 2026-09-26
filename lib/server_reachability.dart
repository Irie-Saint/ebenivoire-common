import 'package:get/get.dart';

/// Le serveur répond-il en ce moment ?
///
/// Tenu à jour par l'ApiService : FAUX dès qu'une requête échoue pour cause
/// de panne (réseau coupé, délai, 502/503/504), VRAI dès que le serveur
/// répond à nouveau, quel que soit le statut de la réponse.
///
/// Le retour du Wi-Fi ne suffit pas : le téléphone peut être connecté sans
/// que le serveur réponde. La première réponse du serveur est le seul signal
/// fiable pour recharger un écran resté en erreur.
class ServerReachability {
  ServerReachability._();

  static final ServerReachability instance = ServerReachability._();

  final RxBool isReachable = true.obs;

  void reportUnreachable() {
    if (isReachable.value) isReachable.value = false;
  }

  void reportReachable() {
    if (!isReachable.value) isReachable.value = true;
  }
}
