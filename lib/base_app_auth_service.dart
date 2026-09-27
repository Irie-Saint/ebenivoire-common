import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_authentication_manager.dart';

/// État de session de l'app entière (vendeur, console) : ce que lit la garde
/// racine ([BaseAppAuthGuard]).
///
/// - [isInitializing] / [authStatus] / [isAppAuthenticated] sont posés par
///   l'écran de démarrage à la fin de sa vérification ;
/// - ensuite, [isAppAuthenticated] suit la connexion ([authManager]).
///
/// ⚠️ Plus aucune vérification de démarrage ici : elle vit dans la session
/// commune (une panne ne déconnecte jamais). L'ancienne version effaçait la
/// session dès qu'un renouvellement échouait, panne comprise.
abstract class BaseAppAuthService extends GetxService {
  final RxBool isAppAuthenticated = false.obs;
  final RxBool isInitializing = true.obs;
  final RxString authStatus = 'initializing'.obs;

  /// Crochet : le gestionnaire de connexion de l'app.
  BaseAuthenticationManager get authManager;

  @override
  void onInit() {
    super.onInit();
    try {
      ever(authManager.isAuthenticated, (bool isAuth) {
        isAppAuthenticated.value = isAuth;
        authStatus.value = isAuth ? 'authenticated' : 'unauthenticated';
      });
    } catch (e) {
      debugPrint('❌ AppAuthService: gestionnaire de connexion absent ($e)');
      authStatus.value = 'error';
    }
  }
}
