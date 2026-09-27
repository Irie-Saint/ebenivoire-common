import 'package:ebenivoire_common/auth/auth_error.dart';
import 'package:ebenivoire_common/base_api_service.dart';
import 'package:ebenivoire_common/base_auth_service.dart';
import 'package:ebenivoire_common/request_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Connexion commune (vendeur, console) : champs envoyés et erreurs.
class _Api extends Fake implements BaseApiService {
  _Api(this.reply);

  final Object Function() reply;
  Map<String, dynamic>? sent;

  @override
  Future<dynamic> create({
    required String endpoint,
    required dynamic data,
    required RequestType type,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
  }) async {
    sent = Map<String, dynamic>.from(data as Map);
    final r = reply();
    if (r is Exception) throw r;
    return r;
  }
}

class _Auth extends BaseAuthService {
  _Auth(this.api);
  final _Api api;

  @override
  BaseApiService get apiService => api;

  Future<String> login(String email, String password) => loginWith(
    email: email,
    password: password,
    roleFields: {'is_vendor': true},
    parse: (body) => (body as Map)['access_token'] as String,
  );
}

void main() {
  test('envoie l’e-mail comme « username » et les champs de l’app', () async {
    final api = _Api(
      () => {
        'statusCode': 200,
        'body': {'access_token': 'a'},
      },
    );
    final token = await _Auth(api).login('v@x.ci', 'secret');
    expect(token, 'a');
    expect(api.sent, {
      'username': 'v@x.ci',
      'password': 'secret',
      'is_vendor': true,
    });
  });

  test('refus du serveur : l’erreur garde son code', () async {
    final api = _Api(
      () => {
        'statusCode': 401,
        'body': {
          'detail': {
            'error_code': 'INVALID_CREDENTIALS',
            'message': 'Identifiants invalides',
          },
        },
      },
    );
    await expectLater(
      _Auth(api).login('v@x.ci', 'faux'),
      throwsA(isA<AuthError>()),
    );
  });

  test('panne inattendue : erreur interne, pas un plantage', () async {
    final api = _Api(() => Exception('socket'));
    await expectLater(
      _Auth(api).login('v@x.ci', 'secret'),
      throwsA(
        isA<AuthError>().having(
          (e) => e.errorType,
          'errorType',
          'INTERNAL_ERROR',
        ),
      ),
    );
  });
}
