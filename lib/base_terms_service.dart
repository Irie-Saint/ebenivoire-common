import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_api_service.dart';
import 'platform_terms.dart';
import 'request_type.dart';

/// Lire et accepter les conditions de la plateforme (CGU) et lire la
/// politique de confidentialité. Même logique pour la cliente et le vendeur,
/// seules les adresses changent.
///
/// Crochets : [apiService] et les quatre adresses.
abstract class BaseTermsService extends GetxService {
  @protected
  BaseApiService get apiService;

  /// Conditions + état d'acceptation de l'utilisateur connecté.
  @protected
  String get myTermsEndpoint;

  @protected
  String get acceptEndpoint;

  /// Conditions publiques (inscription, avant tout jeton).
  @protected
  String get publicTermsEndpoint;

  /// Politique de confidentialité publique (consultative, rien à accepter).
  @protected
  String get publicPrivacyEndpoint;

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) {
      return body.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<PlatformTerms> _read(String endpoint, RequestType type) async {
    final response = await apiService.fetch(endpoint: endpoint, type: type);
    final statusCode = response['statusCode'] as int? ?? 500;
    if (statusCode >= 400) {
      throw Exception('terms.error.load_failed');
    }
    return PlatformTerms.fromJson(_asMap(response['body']));
  }

  Future<PlatformTerms> getTerms() =>
      _read(myTermsEndpoint, RequestType.protected);

  Future<PlatformTerms> getPublicTerms() =>
      _read(publicTermsEndpoint, RequestType.public);

  Future<PlatformTerms> getPublicPrivacy() =>
      _read(publicPrivacyEndpoint, RequestType.public);

  /// Enregistre l'acceptation ; renvoie la version acceptée.
  ///
  /// [version] = celle que l'utilisateur a LUE : le serveur refuse
  /// (`TERMS_VERSION_CHANGED`) si une autre version a été publiée entre la
  /// lecture et le clic. Lève [TermsException].
  Future<String> acceptTerms([String? version]) async {
    final response = await apiService.create(
      endpoint: acceptEndpoint,
      data: <String, dynamic>{'version': ?version},
      type: RequestType.protected,
    );
    final statusCode = response['statusCode'] as int? ?? 500;
    if (statusCode >= 400) {
      final detail = _asMap(response['body'])['detail'];
      throw TermsException(
        detail is Map ? detail['error_code']?.toString() : null,
      );
    }
    final body = _asMap(response['body']);
    final data = body['data'] is Map ? _asMap(body['data']) : body;
    debugPrint('[TERMS] Accepted version ${data['accepted_version']}');
    return data['accepted_version']?.toString() ?? '';
  }
}
