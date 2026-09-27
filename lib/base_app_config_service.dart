import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_api_service.dart';
import 'currency.dart';
import 'request_type.dart';
import 'review_config.dart';
import 'support_contact.dart';

/// Configuration publique de l'app (`GET /api/app/config`, sans connexion),
/// lue au démarrage : devise, contact support, réglages de la demande d'avis.
///
/// Toute erreur est avalée : l'app garde ses valeurs de secours.
///
/// Crochets : [apiService], [onConfigLoaded] (ce que l'app lit en plus — la
/// cliente : pied de page, délai de retour, zone de livraison).
abstract class BaseAppConfigService extends GetxService {
  @protected
  BaseApiService? get apiService;

  /// Crochet : les données reçues, pour ce qui est propre à l'app.
  @protected
  void onConfigLoaded(Map data) {}

  Future<void> hydrate() async {
    final api = apiService;
    if (api == null) return;
    try {
      final response = await api.fetch(
        endpoint: '/api/app/config',
        type: RequestType.public,
      );
      final body = response['body'];
      final data = body is Map ? body['data'] : null;
      if (data is Map) {
        hydrateCurrency(
          symbol: data['currency_symbol']?.toString(),
          code: data['currency']?.toString(),
        );
        final support = data['support_contact'];
        if (support is Map) {
          hydrateSupportContact(Map<String, dynamic>.from(support));
        }
        hydrateReviewConfig(data['app_review']);
        onConfigLoaded(data);
      }
      debugPrint('✅ App config hydrated');
    } catch (e) {
      debugPrint('⚠️ App config fetch failed, keeping fallbacks: $e');
    }
  }
}
