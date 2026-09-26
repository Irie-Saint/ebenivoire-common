import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'base_authentication_manager.dart';
import 'base_session_manager.dart';
import 'jwt_utils.dart';
import 'network_exceptions.dart' as net;
import 'request_type.dart';
import 'server_reachability.dart';

/// Appels au serveur, communs aux trois apps.
///
/// Toutes les méthodes renvoient `{'statusCode': …, 'body': …}` (plus
/// `filename`… pour [downloadFile]) ; les 400 et 422 sont rendus tels quels
/// pour que le service lise le détail, les autres erreurs lèvent une
/// exception.
///
/// ⚠️ Session : une requête protégée vérifie (et renouvelle) le jeton AVANT
/// de partir. Sur un 401 lié au jeton, on renouvelle et on réessaie une fois ;
/// c'est la réponse du renouvellement qui décide : refus → session fermée,
/// panne → 503 `REFRESH_UNAVAILABLE`, session gardée. Seuls les codes d'état
/// du COMPTE ([sessionEndingCodes]) ferment la session directement.
///
/// Crochets : [baseUrl], [apiKey], [enableLogging], [ensureEnvironment],
/// [sessionManager], [authManager], [extraSessionEndingCodes], [onForbidden].
abstract class BaseApiService {
  late final Dio _dio;

  BaseApiService() {
    _initializeDio();
    _watchReachability();
  }

  /// Intervalle entre deux sondages quand le serveur est injoignable.
  static Duration reachabilityProbeInterval = const Duration(seconds: 10);

  Timer? _probeTimer;

  /// Tant que le serveur est injoignable, on le sonde (GET `/`). Sans cela,
  /// aucune requête ne part toute seule au retour du réseau, et personne ne
  /// voit que le serveur répond de nouveau (écran resté en erreur, vu sur
  /// téléphone le 26/09). N'importe quelle réponse — même un 404 — suffit ;
  /// un 502/503/504 de la passerelle laisse « injoignable ».
  void _watchReachability() {
    ever(ServerReachability.instance.isReachable, (bool reachable) {
      if (reachable) {
        _probeTimer?.cancel();
        _probeTimer = null;
      } else {
        _probeTimer ??= Timer.periodic(
          reachabilityProbeInterval,
          (_) => _probe(),
        );
      }
    });
  }

  Future<void> _probe() async {
    try {
      await _dio.get(
        '/',
        options: Options(
          headers: {'X-API-KEY': apiKey},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
    } catch (_) {
      // Toujours injoignable : l'intercepteur l'a noté, on réessaiera.
    }
  }

  // ==================== CROCHETS ====================

  @protected
  String get baseUrl;

  @protected
  String get apiKey;

  @protected
  bool get enableLogging;

  /// Charger la configuration de l'app avant le premier appel.
  @protected
  void ensureEnvironment() {}

  @protected
  BaseSessionManager? get sessionManager;

  @protected
  BaseAuthenticationManager? get authManager;

  /// Codes d'état du compte propres à l'app (compte client suspendu, vendeur
  /// inactif, admin désactivé…) : ils ferment la session tout de suite.
  @protected
  Set<String> get extraSessionEndingCodes => const {};

  /// Un 403 reçu sur une requête non publique (le vendeur y lit son statut).
  @protected
  void onForbidden(Map<String, dynamic>? payload, RequestType type) {}

  // ==================== CODES ====================

  /// Le jeton est refusé : un renouvellement peut suffire.
  static const Set<String> tokenErrorCodes = {
    'TOKEN_REVOKED',
    'TOKEN_EXPIRED',
    'INVALID_TOKEN',
    'SESSION_REVOKED',
  };

  /// L'état du COMPTE interdit la session : fermeture immédiate.
  Set<String> get sessionEndingCodes => {
    'INVALID_REFRESH_TOKEN',
    'USER_NOT_FOUND',
    'USER_INACTIVE',
    'ACCOUNT_INACTIVE',
    'ACCOUNT_SUSPENDED',
    ...extraSessionEndingCodes,
  };

  bool isAuthErrorCode(String? code) =>
      code != null &&
      (tokenErrorCodes.contains(code) || sessionEndingCodes.contains(code));

  /// Marqueur d'une requête protégée partie sans session : inutile de tenter
  /// un renouvellement.
  static const String noSessionCode = 'NO_SESSION';

  // ==================== DIO ====================

  static const Set<String> _sensitiveLogKeys = {
    'authorization',
    'x-api-key',
    'api_key',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'token',
    'password',
    'confirm_password',
    'new_password',
    'old_password',
    'verification_token',
    'code',
    'otp',
  };

  @protected
  dynamic redactSensitiveData(dynamic value) {
    if (value == null) return null;
    if (value is FormData) {
      return {
        'fields': value.fields
            .map(
              (entry) => MapEntry(
                entry.key,
                _isSensitiveLogKey(entry.key) ? '<redacted>' : entry.value,
              ),
            )
            .toList(),
        'files': value.files.map((entry) => entry.key).toList(),
      };
    }
    if (value is Map) {
      return value.map(
        (key, dynamic item) => MapEntry(
          key,
          _isSensitiveLogKey(key.toString())
              ? '<redacted>'
              : redactSensitiveData(item),
        ),
      );
    }
    if (value is Iterable && value is! String) {
      return value.map(redactSensitiveData).toList();
    }
    return value;
  }

  bool _isSensitiveLogKey(String key) {
    final normalized = key.toLowerCase();
    return _sensitiveLogKeys.any(normalized.contains);
  }

  void _initializeDio() {
    ensureEnvironment();

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        // Tous les statuts sont rendus : ils sont traités à la main.
        validateStatus: (status) => true,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (enableLogging) {
            debugPrint('🚀 ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Le serveur a répondu : il est joignable, sauf si c'est la
          // passerelle qui annonce qu'il ne l'est pas.
          final status = response.statusCode ?? 0;
          if (status == 502 || status == 503 || status == 504) {
            ServerReachability.instance.reportUnreachable();
          } else {
            ServerReachability.instance.reportReachable();
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (enableLogging) {
            debugPrint(
              '❌ Error [${error.response?.statusCode}]: ${error.message}',
            );
          }
          if (error.response == null) {
            ServerReachability.instance.reportUnreachable();
          }
          handler.next(error);
        },
      ),
    );

    if (enableLogging) {
      debugPrint('🔗 ApiService initialized — base URL: $baseUrl');
      debugPrint('🔑 API Key configured: ${apiKey.isNotEmpty ? "YES" : "NO"}');
    }
  }

  Dio get dio => _dio;

  // ==================== EN-TÊTES ====================

  String get _currentAccessToken => authManager?.currentToken.value ?? '';

  Map<String, String> _headers(
    RequestType type, {
    Map<String, String>? additionalHeaders,
    bool jsonBody = true,
    String accept = 'application/json',
  }) {
    final headers = <String, String>{
      'X-API-KEY': apiKey,
      'Accept': accept,
      if (jsonBody) 'Content-Type': 'application/json',
      ...?additionalHeaders,
    };
    if (!jsonBody) {
      headers.removeWhere((key, _) => key.toLowerCase() == 'content-type');
    }

    void removeAuthorization() =>
        headers.removeWhere((key, _) => key.toLowerCase() == 'authorization');

    if (type == RequestType.public) {
      removeAuthorization();
    } else if (type.requiresTokenValidation) {
      // Le jeton COURANT, vérifié juste avant l'envoi, remplace celui que
      // l'appelant aurait lu plus tôt.
      final token = _currentAccessToken;
      if (token.isNotEmpty) {
        removeAuthorization();
        headers['Authorization'] = 'Bearer $token';
      }
    } else if (type == RequestType.optionalAuth) {
      // Jamais le jeton d'un invité, ni un jeton expiré : la requête reste
      // publique.
      final token = _currentAccessToken;
      removeAuthorization();
      if (token.isNotEmpty &&
          JWTUtils.isValidJWTStructure(token) &&
          !JWTUtils.isJWTExpired(token)) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ==================== EXÉCUTION ====================

  /// Vérifie (et renouvelle) le jeton avant une requête protégée.
  Future<void> _ensureValidToken() async {
    final session = sessionManager;
    if (session == null) return;
    final bool isValid;
    try {
      isValid = await session.ensureValidTokenForRequest();
    } catch (e) {
      debugPrint('⚠️ Token validation error (continuing): $e');
      return;
    }
    if (isValid) return;
    if (session.isRefreshTemporarilyUnavailable) {
      // Panne au renouvellement : la session tient, c'est le serveur qui ne
      // répond pas. « Serveur injoignable », jamais « non autorisé ».
      throw net.HttpException(
        'core_session.unreachable'.tr,
        503,
        errorCode: 'REFRESH_UNAVAILABLE',
      );
    }
    throw net.UnauthorizedException(
      'Invalid or expired token',
      errorCode: noSessionCode,
    );
  }

  Future<Response> _execute(Future<Response> Function() request) {
    return request().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Request timed out'),
    );
  }

  Future<dynamic> makeRequest(
    Future<Response> Function() request,
    RequestType type,
  ) async {
    try {
      if (type.requiresTokenValidation) {
        await _ensureValidToken();
      }
      final response = await _execute(request);
      if (response.data == null) {
        throw net.HttpException('Server error', 500);
      }
      return response;
    } on TimeoutException catch (e) {
      debugPrint('⏰ Request timeout: $e');
      ServerReachability.instance.reportUnreachable();
      rethrow;
    } on net.UnauthorizedException catch (e) {
      debugPrint('🔒 Auth error: ${e.message}');
      final session = sessionManager;
      if (!type.requiresTokenValidation ||
          session == null ||
          e.errorCode == noSessionCode ||
          sessionEndingCodes.contains(e.errorCode)) {
        rethrow;
      }
      // Le jeton est refusé : renouveler, puis réessayer UNE fois.
      final refreshed = await session.forceRefreshSession();
      if (refreshed) {
        debugPrint('Token refreshed after 401, retrying request once');
        final retry = await _execute(request);
        if (retry.data == null) {
          throw net.HttpException('Server error', 500);
        }
        return retry;
      }
      if (session.isRefreshTemporarilyUnavailable) {
        throw net.HttpException(
          'core_session.unreachable'.tr,
          503,
          errorCode: 'REFRESH_UNAVAILABLE',
        );
      }
      // Refus explicite : le renouvellement a déjà fermé la session.
      rethrow;
    } on DioException catch (e) {
      debugPrint('🌐 Dio error: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw TimeoutException('Request timed out');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw net.HttpException('No internet connection', 503);
      }
      final statusCode = e.response?.statusCode ?? 500;
      throw _mapStatusCodeToException(
        statusCode,
        e.response?.statusMessage ?? e.message ?? 'Unknown error',
      );
    }
  }

  // ==================== LECTURE DES RÉPONSES ====================

  Map<String, dynamic>? _extractErrorPayload(dynamic data) {
    if (data is! Map) return null;
    final payload = Map<String, dynamic>.from(data);
    final detail = payload['detail'];
    if (detail is Map) return Map<String, dynamic>.from(detail);
    return payload;
  }

  String? _extractErrorCode(dynamic data) {
    final payload = _extractErrorPayload(data);
    return (payload?['error_code'] ?? payload?['error_type'])?.toString();
  }

  String? _extractErrorMessage(dynamic data) {
    final payload = _extractErrorPayload(data);
    return (payload?['message'] ?? payload?['detail'])?.toString();
  }

  net.HttpException _mapStatusCodeToException(
    int statusCode,
    String message, {
    String? errorCode,
  }) {
    switch (statusCode) {
      case 503:
        return net.HttpException(
          'Service unavailable: $message',
          503,
          errorCode: errorCode,
        );
      case 504:
        return net.HttpException(
          'Gateway timeout: $message',
          504,
          errorCode: errorCode,
        );
      default:
        return net.HttpException(message, statusCode, errorCode: errorCode);
    }
  }

  Never _handleUnauthorizedResponse(String message, String? errorCode) {
    debugPrint('Unauthorized response: $message (${errorCode ?? 'NO_CODE'})');
    if (sessionEndingCodes.contains(errorCode)) {
      final session = sessionManager;
      if (session != null) unawaited(session.handleSessionExpired());
    }
    throw net.UnauthorizedException(message, errorCode: errorCode);
  }

  void _handleResponse(Response response, RequestType type) {
    // Connexion, inscription : le service d'authentification lit tout,
    // 403 compris (code par e-mail des super admins…).
    if (type.isAuthRequest) return;

    final status = response.statusCode ?? 0;
    final code = _extractErrorCode(response.data);
    final message =
        _extractErrorMessage(response.data) ??
        response.statusMessage ??
        'Unauthorized';

    if ((type == RequestType.public || type == RequestType.optionalAuth) &&
        (status == 401 || isAuthErrorCode(code))) {
      debugPrint('Public request received auth error; session untouched.');
      return;
    }

    if (status == 401 || isAuthErrorCode(code)) {
      _handleUnauthorizedResponse(message, code ?? 'UNAUTHORIZED');
    }

    if (status < 200 || status >= 300) {
      debugPrint('❌ HTTP $status on ${response.requestOptions.path}');
      if (status == 400 || status == 422) return;
      if (status == 403 && type != RequestType.public) {
        onForbidden(_extractErrorPayload(response.data), type);
      }
      throw _mapStatusCodeToException(status, message, errorCode: code);
    }
  }

  void _logError(String label, Object error) {
    debugPrint('API Error: $label (${error.runtimeType})');
  }

  // ==================== MÉTHODES ====================

  Future<dynamic> fetch({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: Options(
            headers: _headers(type, additionalHeaders: additionalHeaders),
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);
      return {'statusCode': response.statusCode, 'body': response.data};
    } catch (e) {
      _logError('GET $endpoint failed', e);
      rethrow;
    }
  }

  /// GET renvoyant des OCTETS (PDF, image), avec les mêmes en-têtes que
  /// [fetch]. ⚠️ Ne jamais appeler `dio.get` directement : `BaseOptions` ne
  /// porte ni `X-API-KEY` ni `Authorization`.
  Future<List<int>?> fetchBytes({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    final response = await makeRequest(() async {
      final response = await _dio.get<List<int>>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.bytes,
          headers: _headers(
            type,
            additionalHeaders: additionalHeaders,
            jsonBody: false,
          ),
        ),
      );
      _handleResponse(response, type);
      return response;
    }, type);

    final code = response.statusCode ?? 500;
    if (code >= 400) {
      throw net.HttpException('Download failed (status $code)', code);
    }
    return response.data;
  }

  /// POST : JSON, ou formulaire pour la connexion ([RequestType.loginAuth]).
  Future<dynamic> create({
    required String endpoint,
    required dynamic data,
    required RequestType type,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
  }) async {
    final response = await makeRequest(() async {
      final asForm =
          type == RequestType.loginAuth && data is Map<String, dynamic>;
      final response = await _dio.post(
        endpoint,
        data: asForm ? FormData.fromMap(data) : data,
        queryParameters: queryParameters,
        options: Options(
          headers: _headers(
            type,
            additionalHeaders: additionalHeaders,
            jsonBody: !asForm,
          ),
        ),
      );
      _handleResponse(response, type);
      return response;
    }, type);
    return {'statusCode': response.statusCode, 'body': response.data};
  }

  Future<dynamic> update({
    required String endpoint,
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.put(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          options: Options(
            headers: _headers(type, additionalHeaders: additionalHeaders),
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);
      return {'statusCode': response.statusCode, 'body': response.data};
    } catch (e) {
      _logError('PUT $endpoint failed', e);
      rethrow;
    }
  }

  Future<dynamic> patch({
    required String endpoint,
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.patch(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          options: Options(
            headers: _headers(type, additionalHeaders: additionalHeaders),
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);
      return {'statusCode': response.statusCode, 'body': response.data};
    } catch (e) {
      _logError('PATCH $endpoint failed', e);
      rethrow;
    }
  }

  Future<dynamic> remove({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.delete(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          options: Options(
            headers: _headers(type, additionalHeaders: additionalHeaders),
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);
      return {'statusCode': response.statusCode, 'body': response.data};
    } catch (e) {
      _logError('DELETE $endpoint failed', e);
      rethrow;
    }
  }

  // ==================== FICHIERS ====================

  /// Fichier (dart:io) sur mobile, XFile (octets) sur le web.
  Future<MultipartFile?> _createMultipartFile(
    dynamic file, [
    int? index,
  ]) async {
    try {
      if (file is File) {
        final filename = file.path.split(RegExp(r'[\\/]')).last;
        return await MultipartFile.fromFile(
          file.path,
          filename: filename,
          contentType: MediaType.parse(_getContentType(filename)),
        );
      }
      if (file is XFile) {
        final bytes = await file.readAsBytes();
        final filename = file.name.isNotEmpty
            ? file.name
            : 'image_${index ?? 0}.jpg';
        return MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(_getContentType(filename)),
        );
      }
      debugPrint('⚠️ Unsupported file type: ${file.runtimeType}');
      return null;
    } catch (e) {
      debugPrint('❌ Error creating MultipartFile: $e');
      return null;
    }
  }

  String _getContentType(String filename) {
    switch (filename.toLowerCase().split('.').last) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'image/jpeg';
    }
  }

  /// Champs + fichiers. Une liste part sous la MÊME clé (attendu par
  /// FastAPI) ; un champ liste part en `clé[i]`.
  Future<FormData> _buildFormData(
    Map<String, dynamic> data,
    Map<String, dynamic> files,
  ) async {
    final formData = FormData();
    data.forEach((key, value) {
      if (value == null) return;
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          formData.fields.add(MapEntry('$key[$i]', value[i].toString()));
        }
      } else {
        formData.fields.add(MapEntry(key, value.toString()));
      }
    });
    for (final entry in files.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          if (value[i] == null) continue;
          final file = await _createMultipartFile(value[i], i);
          if (file != null) formData.files.add(MapEntry(entry.key, file));
        }
      } else {
        final file = await _createMultipartFile(value);
        if (file != null) formData.files.add(MapEntry(entry.key, file));
      }
    }
    debugPrint(
      '📋 FormData: fields ${formData.fields.map((e) => e.key).toList()}, '
      'files ${formData.files.map((e) => e.key).toList()}',
    );
    return formData;
  }

  /// POST multipart. [sendTimeout] / [receiveTimeout] : délai plus long pour
  /// les gros médias sur une connexion mobile lente.
  ///
  /// Une erreur est rendue comme une réponse 500 (comportement historique
  /// des trois apps : les services lisent `statusCode`).
  Future<dynamic> createMultipart({
    required String endpoint,
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.post(
          endpoint,
          data: await _buildFormData(data, files),
          queryParameters: queryParameters,
          options: Options(
            contentType: Headers.multipartFormDataContentType,
            headers: _headers(
              type,
              additionalHeaders: additionalHeaders,
              jsonBody: false,
            ),
            sendTimeout: sendTimeout,
            receiveTimeout: receiveTimeout,
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);
      return {'statusCode': response.statusCode, 'body': response.data};
    } catch (e) {
      _logError('POST multipart $endpoint failed', e);
      return {
        'statusCode': 500,
        'body': {
          'detail': 'Response parsing error',
          'error_type': e.runtimeType.toString(),
        },
      };
    }
  }

  /// PUT multipart : champs et fichiers facultatifs.
  Future<dynamic> updateMultipart({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, dynamic> files = const {},
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.put(
          endpoint,
          data: await _buildFormData(data, files),
          queryParameters: queryParameters,
          options: Options(
            contentType: Headers.multipartFormDataContentType,
            headers: _headers(
              type,
              additionalHeaders: additionalHeaders,
              jsonBody: false,
            ),
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);
      return {'statusCode': response.statusCode, 'body': response.data};
    } catch (e) {
      _logError('PUT multipart $endpoint failed', e);
      rethrow;
    }
  }

  /// Téléchargement d'un fichier (PDF…) : octets + nom tiré de
  /// `Content-Disposition`.
  Future<dynamic> downloadFile({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? additionalHeaders,
    RequestType type = RequestType.protected,
  }) async {
    try {
      final response = await makeRequest(() async {
        final response = await _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: Options(
            headers: _headers(
              type,
              additionalHeaders: additionalHeaders,
              jsonBody: false,
              accept: 'application/pdf',
            ),
            responseType: ResponseType.bytes,
          ),
        );
        _handleResponse(response, type);
        return response;
      }, type);

      String? filename;
      final disposition = response.headers['content-disposition']?.first;
      if (disposition != null) {
        final match = RegExp(r'filename=([^;]+)').firstMatch(disposition);
        filename = match?.group(1)?.replaceAll('"', '').trim();
      }
      return {
        'statusCode': response.statusCode,
        'body': response.data,
        'filename': filename,
        'contentType': response.headers['content-type']?.first,
        'contentLength': response.headers['content-length']?.first,
      };
    } catch (e) {
      _logError('Download $endpoint failed', e);
      rethrow;
    }
  }
}
