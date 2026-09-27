import 'package:ebenivoire_common/base_app_auth_guard.dart';
import 'package:ebenivoire_common/base_authentication_manager.dart';
import 'package:ebenivoire_common/base_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Garde racine commune (vendeur, console).
///
/// ⚠️ Défaut signalé en device (20/09) : changer le thème du téléphone
/// renvoyait à la connexion. La garde enveloppe TOUTE l'app ; un redessin lui
/// faisait lire « pas authentifié » (jeton d'ACCÈS expiré) et elle éjectait
/// l'utilisateur, alors qu'un simple renouvellement suffisait.
class _Guard extends BaseAppAuthGuard {
  const _Guard({required super.child, required this.authenticated});

  final RxBool authenticated;

  @override
  bool get servicesReady => true;

  @override
  AuthGuardState readState() => AuthGuardState(
    isInitializing: false,
    status: authenticated.value ? 'authenticated' : 'unauthenticated',
    isAuthenticated: authenticated.value,
  );

  @override
  bool routeRequiresAuth(String route) => route != '/auth';

  @override
  BaseAuthenticationManager? get authManager => null;

  @override
  BaseSessionManager? get sessionManager => null;
}

void main() {
  AuthGuardAction action({
    bool isInitializing = false,
    String status = 'authenticated',
    bool isAuthenticated = true,
    bool canRecoverSession = true,
    bool routeRequiresAuth = true,
  }) => authGuardAction(
    isInitializing: isInitializing,
    status: status,
    isAuthenticated: isAuthenticated,
    canRecoverSession: canRecoverSession,
    routeRequiresAuth: routeRequiresAuth,
  );

  test(
    'jeton d’accès expiré mais renouvelable : on RESTE et on renouvelle',
    () {
      expect(
        action(isAuthenticated: false, canRecoverSession: true),
        AuthGuardAction.refresh,
      );
    },
  );

  test('plus rien à renouveler : retour à la connexion', () {
    expect(
      action(isAuthenticated: false, canRecoverSession: false),
      AuthGuardAction.goToAuth,
    );
  });

  test('compte bloqué par le serveur : retour à la connexion', () {
    expect(action(status: 'blocked'), AuthGuardAction.goToAuth);
  });

  test('écran public ou session valide : la garde ne fait rien', () {
    expect(
      action(isAuthenticated: false, routeRequiresAuth: false),
      AuthGuardAction.stay,
    );
    expect(action(), AuthGuardAction.stay);
  });

  test('pendant le démarrage, c’est le démarrage qui décide', () {
    expect(
      action(
        isInitializing: true,
        isAuthenticated: false,
        canRecoverSession: false,
      ),
      AuthGuardAction.stay,
    );
  });

  testWidgets('session terminée pendant le travail : renvoi à la connexion', (
    tester,
  ) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    final authenticated = true.obs;
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const Text('travail')),
          GetPage(name: '/auth', page: () => const Text('connexion')),
        ],
        builder: (_, child) =>
            _Guard(authenticated: authenticated, child: child!),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('travail'), findsOneWidget);

    // Refus du serveur, rien à renouveler : la garde réagit toute seule.
    authenticated.value = false;
    await tester.pumpAndSettle();
    expect(find.text('connexion'), findsOneWidget);
  });
}
