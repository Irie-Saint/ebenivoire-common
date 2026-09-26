import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ebenivoire_common/api_request_guard.dart';
import 'package:ebenivoire_common/base_api_service.dart';
import 'package:ebenivoire_common/base_authentication_manager.dart';
import 'package:ebenivoire_common/base_session_manager.dart';
import 'package:ebenivoire_common/base_storage_service.dart';
import 'package:ebenivoire_common/network_exceptions.dart' as net;
import 'package:ebenivoire_common/refresh_token_error.dart';
import 'package:ebenivoire_common/request_type.dart';
import 'package:ebenivoire_common/server_reachability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

/// Le noyau de connexion commun aux trois apps.
///
/// Règle : une panne du serveur ou du réseau ne déconnecte JAMAIS ; la
/// requête est retenue avec « serveur injoignable » (503
/// REFRESH_UNAVAILABLE). Seuls un refus explicite du serveur ou l'expiration
/// du jeton de renouvellement ferment la session.
String _jwt(Duration fromNow) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': 'u1', 'email': 'a@b.c', 'exp': exp})}.signature';
}

class _Storage extends BaseStorageService {
  String access = _jwt(const Duration(minutes: -5)); // expiré
  String refresh = _jwt(const Duration(days: 7));

  _Storage() {
    isInitialized.value = true;
  }

  @override
  Future<String?> getAccessToken() async => access.isEmpty ? null : access;
  @override
  Future<String?> getRefreshToken() async => refresh.isEmpty ? null : refresh;
  @override
  Future<void> saveAccessToken(String? token) async => access = token ?? '';
  @override
  Future<void> saveRefreshToken(String refreshToken) async =>
      refresh = refreshToken;
  @override
  Future<void> clearAuthData() async {
    access = '';
    refresh = '';
  }
}

class _Auth extends BaseAuthenticationManager {
  _Auth(this._storage);
  final _Storage _storage;
  @override
  BaseStorageService get storageService => _storage;
}

class _Session extends BaseSessionManager {
  _Session(this._storage, this._auth, this._api);
  final _Storage _storage;
  final _Auth _auth;
  final _Api _api;
  int expired = 0;
  int refreshedHooks = 0;

  @override
  BaseStorageService get storageService => _storage;
  @override
  BaseApiService get apiService => _api;
  @override
  BaseAuthenticationManager get authManager => _auth;

  @override
  Future<void> handleSessionExpired() async {
    expired++;
    await super.handleSessionExpired();
  }

  @override
  Future<void> onTokensRefreshed(TokenRefreshResult result) async =>
      refreshedHooks++;
}

/// Le serveur simulé : chaque route renvoie ce qu'on lui dit, ou coupe la
/// connexion.
class _Server implements HttpClientAdapter {
  /// 'up' | 'down' | 'refused' | 'gateway'
  String refreshMode = 'up';

  /// Réponse des routes métier : (statut, corps).
  (int, Map<String, dynamic>) Function(RequestOptions) business = (_) =>
      (200, {'ok': true});

  int refreshCalls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      switch (refreshMode) {
        case 'down':
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'Failed host lookup',
          );
        case 'gateway':
          return _json(502, {'message': 'Bad Gateway'});
        case 'refused':
          return _json(401, {
            'success': false,
            'message': 'Votre session a été révoquée.',
            'error_type': 'TOKEN_REVOKED',
          });
        default:
          return _json(200, {
            'access_token': _jwt(const Duration(minutes: 30)),
            'refresh_token': _jwt(const Duration(days: 7)),
            'refresh_rotated': false,
            'user': {'id': 'u1'},
          });
      }
    }
    final (status, body) = business(options);
    if (status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      );
    }
    return _json(status, body);
  }

  ResponseBody _json(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _Api extends BaseApiService {
  _Session? session;
  _Auth? auth;

  @override
  String get baseUrl => 'https://api.test';
  @override
  String get apiKey => 'key';
  @override
  bool get enableLogging => false;
  @override
  BaseSessionManager? get sessionManager => session;
  @override
  BaseAuthenticationManager? get authManager => auth;
  @override
  Set<String> get extraSessionEndingCodes => const {'CUSTOMER_SUSPENDED'};
}

void main() {
  late _Storage storage;
  late _Auth auth;
  late _Api api;
  late _Server server;
  late _Session session;

  setUp(() {
    Get.testMode = true;
    storage = _Storage();
    auth = _Auth(storage);
    api = _Api();
    server = _Server();
    api.dio.httpClientAdapter = server;
    session = _Session(storage, auth, api);
    api
      ..session = session
      ..auth = auth;
    Get.put<BaseAuthenticationManager>(auth);
    Get.put<BaseSessionManager>(session);
    ServerReachability.instance.reportReachable();
  });

  tearDown(Get.reset);

  group('renouvellement', () {
    test('le serveur répond : jeton renouvelé, crochet appelé', () async {
      expect(await session.checkTokenBeforeRequest(), isTrue);
      expect(server.refreshCalls, 1);
      expect(session.refreshedHooks, 1);
      expect(auth.currentToken.value, storage.access);
      expect(session.expired, 0);
    });

    test('panne réseau : session GARDÉE, requête retenue', () async {
      server.refreshMode = 'down';
      expect(await session.checkTokenBeforeRequest(), isFalse);
      expect(session.isRefreshTemporarilyUnavailable, isTrue);
      expect(session.isSessionValid.value, isTrue);
      expect(session.expired, 0);
      expect(storage.refresh, isNotEmpty);
    });

    test('502 de la passerelle : panne, pas un refus', () async {
      server.refreshMode = 'gateway';
      expect(await session.checkTokenBeforeRequest(), isFalse);
      expect(session.isRefreshTemporarilyUnavailable, isTrue);
      expect(session.expired, 0);
    });

    test(
      'requêtes rapprochées : jamais un faux succès, un seul appel',
      () async {
        server.refreshMode = 'down';
        final results = await Future.wait(
          List.generate(5, (_) => session.checkTokenBeforeRequest()),
        );
        expect(results, everyElement(isFalse));
        expect(await session.checkTokenBeforeRequest(), isFalse);
        expect(server.refreshCalls, 1);
        expect(session.expired, 0);
      },
    );

    test('le serveur revient : la session reprend', () async {
      server.refreshMode = 'down';
      expect(await session.checkTokenBeforeRequest(), isFalse);
      server.refreshMode = 'up';
      expect(await session.forceRefreshSession(), isTrue);
      expect(session.isRefreshTemporarilyUnavailable, isFalse);
      expect(await session.checkTokenBeforeRequest(), isTrue);
      expect(session.expired, 0);
    });

    test('refus explicite : la session est fermée', () async {
      server.refreshMode = 'refused';
      expect(await session.checkTokenBeforeRequest(), isFalse);
      expect(session.expired, 1);
      expect(storage.refresh, isEmpty);
      expect(auth.isAuthenticated.value, isFalse);
    });

    test('jeton de renouvellement expiré : fermée, sans appel', () async {
      storage.refresh = _jwt(const Duration(minutes: -1));
      expect(await session.checkTokenBeforeRequest(), isFalse);
      expect(session.expired, greaterThan(0));
      expect(server.refreshCalls, 0);
    });
  });

  group('requêtes', () {
    test(
      'panne au renouvellement : 503 REFRESH_UNAVAILABLE, rien envoyé',
      () async {
        server.refreshMode = 'down';
        await expectLater(
          api.fetch(endpoint: '/api/orders'),
          throwsA(
            isA<net.HttpException>()
                .having((e) => e.status, 'status', 503)
                .having((e) => e.errorCode, 'code', 'REFRESH_UNAVAILABLE'),
          ),
        );
        expect(server.requests.where((r) => r.path == '/api/orders'), isEmpty);
        expect(session.expired, 0);
      },
    );

    test(
      '401 puis panne au renouvellement : session GARDÉE (ancien trou)',
      () async {
        storage.access = _jwt(const Duration(minutes: 20));
        auth.currentToken.value = storage.access;
        server
          ..refreshMode = 'down'
          ..business = (_) => (
            401,
            {
              'detail': {
                'success': false,
                'message': 'Session révoquée',
                'error_code': 'SESSION_REVOKED',
              },
            },
          );
        await expectLater(
          api.fetch(endpoint: '/api/orders'),
          throwsA(
            isA<net.HttpException>().having(
              (e) => e.errorCode,
              'code',
              'REFRESH_UNAVAILABLE',
            ),
          ),
        );
        expect(session.expired, 0);
        expect(storage.refresh, isNotEmpty);
      },
    );

    test('401 puis refus au renouvellement : session fermée', () async {
      storage.access = _jwt(const Duration(minutes: 20));
      auth.currentToken.value = storage.access;
      server
        ..refreshMode = 'refused'
        ..business = (_) => (401, {'detail': 'Not authenticated'});
      await expectLater(
        api.fetch(endpoint: '/api/orders'),
        throwsA(isA<net.UnauthorizedException>()),
      );
      expect(session.expired, 1);
    });

    test('401 puis renouvellement réussi : la requête est rejouée', () async {
      storage.access = _jwt(const Duration(minutes: 20));
      auth.currentToken.value = storage.access;
      var calls = 0;
      server.business = (_) => ++calls == 1
          ? (401, {'detail': 'Not authenticated'})
          : (200, {'ok': true});
      final res = await api.fetch(endpoint: '/api/orders');
      expect(res['statusCode'], 200);
      expect(calls, 2);
      expect(session.expired, 0);
    });

    test(
      'compte suspendu (code propre à l\'app) : fermeture immédiate',
      () async {
        storage.access = _jwt(const Duration(minutes: 20));
        auth.currentToken.value = storage.access;
        server.business = (_) => (
          401,
          {
            'detail': {
              'message': 'Suspendu',
              'error_code': 'CUSTOMER_SUSPENDED',
            },
          },
        );
        await expectLater(
          api.fetch(endpoint: '/api/orders'),
          throwsA(isA<net.UnauthorizedException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(session.expired, 1);
        expect(server.refreshCalls, 0);
      },
    );

    test('connexion : le 403 ADMIN_CODE_REQUIRED passe tel quel', () async {
      server.business = (_) => (
        403,
        {
          'detail': {'error_type': 'ADMIN_CODE_REQUIRED', 'message': 'Code'},
        },
      );
      final res = await api.create(
        endpoint: '/auth/login',
        data: {'username': 'a', 'password': 'b'},
        type: RequestType.loginAuth,
      );
      expect(res['statusCode'], 403);
      expect(session.expired, 0);
    });

    test(
      'joignabilité : fausse sur panne, vraie à la première réponse',
      () async {
        storage.access = _jwt(const Duration(minutes: 20));
        auth.currentToken.value = storage.access;
        server.business = (_) => (0, {});
        await expectLater(
          api.fetch(endpoint: '/api/orders'),
          throwsA(isA<net.HttpException>().having((e) => e.status, 's', 503)),
        );
        expect(ServerReachability.instance.isReachable.value, isFalse);

        server.business = (_) => (404, {'detail': 'x'});
        await expectLater(
          api.fetch(endpoint: '/api/orders'),
          throwsA(isA<net.HttpException>()),
        );
        expect(ServerReachability.instance.isReachable.value, isTrue);
      },
    );
  });

  test(
    'injoignable : le serveur est sondé, et joignable dès qu’il répond',
    () async {
      BaseApiService.reachabilityProbeInterval = const Duration(
        milliseconds: 20,
      );
      addTearDown(
        () => BaseApiService.reachabilityProbeInterval = const Duration(
          seconds: 10,
        ),
      );
      // Le premier service de test sonde avec l'intervalle d'avant : on en
      // crée un neuf, branché sur le même serveur simulé.
      final probing = _Api()..dio.httpClientAdapter = server;
      probing
        ..session = session
        ..auth = auth;

      server.business = (_) => (0, {}); // réseau coupé
      ServerReachability.instance.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(ServerReachability.instance.isReachable.value, isFalse);

      // Le réseau revient : la racine répond 404, c'est une réponse.
      server.business = (_) => (404, {'detail': 'Not Found'});
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(ServerReachability.instance.isReachable.value, isTrue);
      expect(server.requests.any((r) => r.path == '/'), isTrue);
    },
  );

  group('état de connexion', () {
    test('jeton d\'accès expiré, session renouvelable : connecté', () {
      auth.currentRefreshToken.value = _jwt(const Duration(days: 7));
      auth.currentToken.value = _jwt(const Duration(minutes: -5));
      expect(auth.isUserLoggedIn, isTrue);
      expect(auth.isAuthenticated.value, isTrue);
    });

    test('les deux jetons expirés : déconnecté', () {
      auth.currentRefreshToken.value = _jwt(const Duration(minutes: -1));
      auth.currentToken.value = _jwt(const Duration(minutes: -5));
      expect(auth.isUserLoggedIn, isFalse);
    });
  });

  group('garde de requêtes', () {
    test('panne : 503, jamais des en-têtes d\'invité', () async {
      server.refreshMode = 'down';
      auth.currentRefreshToken.value = storage.refresh;
      auth.currentToken.value = storage.access;
      await expectLater(
        validatedRequestHeaders(
          sessionManager: session,
          authManager: auth,
          guestHeaders: const {'guest': '1'},
        ),
        throwsA(
          isA<net.HttpException>().having(
            (e) => e.errorCode,
            'code',
            'REFRESH_UNAVAILABLE',
          ),
        ),
      );
    });

    test('invité : en-têtes par défaut', () async {
      await storage.clearAuthData();
      auth.currentRefreshToken.value = '';
      auth.currentToken.value = '';
      final headers = await validatedRequestHeaders(
        sessionManager: session,
        authManager: auth,
        guestHeaders: const {'guest': '1'},
      );
      expect(headers, {'guest': '1'});
    });

    test('session ouverte : jeton renouvelé joint', () async {
      auth.currentRefreshToken.value = storage.refresh;
      auth.currentToken.value = storage.access;
      final headers = await validatedRequestHeaders(
        sessionManager: session,
        authManager: auth,
      );
      expect(headers['Authorization'], 'Bearer ${storage.access}');
      expect(server.refreshCalls, 1);
    });
  });

  group('RefreshTokenError', () {
    RefreshTokenError parse(int status, Map<String, dynamic> body) =>
        RefreshTokenError.fromResponse({'statusCode': status, 'body': body});

    test('corps plat TOKEN_REVOKED : reconnexion exigée', () {
      final e = parse(401, {
        'success': false,
        'message': 'x',
        'error_type': 'TOKEN_REVOKED',
      });
      expect(e.errorType, 'TOKEN_REVOKED');
      expect(e.requiresReLogin, isTrue);
    });

    test('enveloppe detail : TOKEN_ROTATED lu', () {
      final e = parse(401, {
        'detail': {'error_type': 'TOKEN_ROTATED', 'message': 'x'},
      });
      expect(e.requiresReLogin, isTrue);
    });

    test('SESSION_REVOKED (console) : refus', () {
      expect(
        parse(401, {'error_type': 'SESSION_REVOKED'}).requiresReLogin,
        isTrue,
      );
    });

    test('5xx : panne, jamais un refus', () {
      final e = parse(500, {
        'error_type': 'INVALID_REFRESH_TOKEN',
        'message': 'x',
      });
      expect(e.requiresReLogin, isFalse);
      expect(e.isTemporaryError, isTrue);
    });

    test('API_ERROR plat : ni refus ni inconnu', () {
      final e = parse(401, {'message': 'x', 'error_type': 'API_ERROR'});
      expect(e.errorType, 'API_ERROR');
      expect(e.requiresReLogin, isFalse);
    });
  });
}
