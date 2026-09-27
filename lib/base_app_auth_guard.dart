import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'base_authentication_manager.dart';
import 'base_session_manager.dart';

/// Ce que la garde racine doit faire, isolé pour être testé.
///
/// ⚠️ « Jeton d'accès expiré » n'est PAS « déconnecté ». Le jeton d'accès vit
/// 30 minutes ; tant que le jeton de renouvellement est valide, la session est
/// récupérable et l'app doit la renouveler, pas éjecter l'utilisateur.
/// Avant, la garde renvoyait à la connexion au moindre redessin (changer le
/// thème du téléphone suffisait) et le travail en cours était perdu.
enum AuthGuardAction {
  /// Rien à faire : on affiche l'écran demandé.
  stay,

  /// Session récupérable : on renouvelle en silence, sans quitter l'écran.
  refresh,

  /// Session bel et bien terminée : retour à la connexion.
  goToAuth,
}

AuthGuardAction authGuardAction({
  required bool isInitializing,
  required String status,
  required bool isAuthenticated,
  required bool canRecoverSession,
  required bool routeRequiresAuth,
}) {
  // Le démarrage pilote lui-même sa navigation.
  if (isInitializing) return AuthGuardAction.stay;

  // Le serveur a bloqué ce compte : il doit repasser par la connexion.
  if (status == 'blocked') return AuthGuardAction.goToAuth;

  if (!routeRequiresAuth || isAuthenticated) return AuthGuardAction.stay;

  return canRecoverSession ? AuthGuardAction.refresh : AuthGuardAction.goToAuth;
}

/// État de la session tel que la garde le lit (observables de l'app).
class AuthGuardState {
  const AuthGuardState({
    required this.isInitializing,
    required this.status,
    required this.isAuthenticated,
  });

  final bool isInitializing;
  final String status;
  final bool isAuthenticated;
}

/// Garde racine (vendeur, console) : enveloppe toute l'app et renvoie à la
/// connexion quand la session est vraiment terminée. Chaque app garde sa
/// classe `AppAuthGuard`, qui en hérite et remplit les crochets.
abstract class BaseAppAuthGuard extends StatelessWidget {
  const BaseAppAuthGuard({super.key, required this.child});

  final Widget child;

  // ── Crochets ──────────────────────────────────────────────────────────────

  /// Le service de session de l'app existe (sinon : démarrage en cours).
  bool get servicesReady;

  /// Lit les observables de l'app (appelé dans un `Obx` : la garde se
  /// réévalue quand ils changent).
  AuthGuardState readState();

  /// La route demande-t-elle une session ?
  bool routeRequiresAuth(String route);

  /// Gestionnaire de connexion de l'app, s'il est prêt.
  BaseAuthenticationManager? get authManager;

  /// Gestionnaire de session de l'app, s'il est prêt.
  BaseSessionManager? get sessionManager;

  /// Écran de connexion.
  String get authRoute => '/auth';

  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Services pas encore prêts : le démarrage s'occupe de la navigation.
    if (!servicesReady) return child;

    return Obx(() {
      final state = readState();
      final action = authGuardAction(
        isInitializing: state.isInitializing,
        status: state.status,
        isAuthenticated: state.isAuthenticated,
        canRecoverSession: authManager?.canRecoverSession ?? false,
        routeRequiresAuth: routeRequiresAuth(Get.currentRoute),
      );

      switch (action) {
        case AuthGuardAction.stay:
          break;
        case AuthGuardAction.refresh:
          // Jeton d'accès expiré mais renouvelable : on reste sur l'écran et
          // on renouvelle en silence.
          WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
        case AuthGuardAction.goToAuth:
          debugPrint(
            '🔒 AppAuthGuard: session terminée sur ${Get.currentRoute}',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) => _goToAuth());
      }

      // On garde l'écran courant dans tous les cas : jamais un second
      // MaterialApp, jamais un écran blanc pendant la décision.
      return child;
    });
  }

  void _recover() {
    final session = sessionManager;
    if (session == null || session.isRefreshingToken.value) return;
    session.refreshTokenSilently();
  }

  void _goToAuth() {
    try {
      // Déjà sur la connexion : pas de boucle.
      if (Get.currentRoute == authRoute || Get.currentRoute == '/login') return;
      Get.offAllNamed(authRoute);
    } catch (e) {
      debugPrint('❌ AppAuthGuard navigation failed: $e');
    }
  }
}
