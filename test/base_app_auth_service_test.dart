import 'package:ebenivoire_common/base_app_auth_service.dart';
import 'package:ebenivoire_common/base_authentication_manager.dart';
import 'package:ebenivoire_common/base_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// État de session de l'app (vendeur, console) : il suit la connexion.
class _Auth extends BaseAuthenticationManager {
  @override
  BaseStorageService get storageService =>
      throw UnimplementedError('pas de stockage dans ce test');
}

class _Service extends BaseAppAuthService {
  _Service(this._auth);
  final _Auth _auth;

  @override
  BaseAuthenticationManager get authManager => _auth;
}

void main() {
  test(
    'démarrage : « en cours » tant que l’écran de démarrage n’a pas fini',
    () {
      final service = _Service(_Auth())..onInit();
      expect(service.isInitializing.value, isTrue);
      expect(service.authStatus.value, 'initializing');
    },
  );

  test('suit la connexion puis la déconnexion', () async {
    final auth = _Auth();
    final service = _Service(auth)..onInit();

    auth.isAuthenticated.value = true;
    await Future<void>.delayed(Duration.zero);
    expect(service.isAppAuthenticated.value, isTrue);
    expect(service.authStatus.value, 'authenticated');

    auth.isAuthenticated.value = false;
    await Future<void>.delayed(Duration.zero);
    expect(service.isAppAuthenticated.value, isFalse);
    expect(service.authStatus.value, 'unauthenticated');
  });
}
