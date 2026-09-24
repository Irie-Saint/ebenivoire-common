/// Remontée des plantages vers Sentry — même fichier dans les trois apps.
///
/// Avant, un plantage chez un utilisateur ne se voyait que s'il se
/// plaignait. Sentry reçoit maintenant l'erreur, l'écran, le téléphone et la
/// version de l'app.
///
/// - `SENTRY_DSN` vide (fichier `.env.*` passé par --dart-define-from-file) :
///   rien n'est activé, l'app fonctionne comme avant.
/// - Désactivé en mode débogage (`flutter run`) pour ne pas remplir Sentry
///   des erreurs de développement ; `SENTRY_DEBUG=true` le force pour tester.
/// - Aucune donnée personnelle : ni IP, ni capture d'écran, ni arbre des
///   widgets (désactivé par défaut) ; la clé d'API et les jetons sont
///   retirés des requêtes.
/// - Erreurs seulement : pas de mesures de performance (quota gratuit).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String _dsn = String.fromEnvironment('SENTRY_DSN');
const String _environment = String.fromEnvironment(
  'ENVIRONMENT',
  defaultValue: 'development',
);
const bool _forceInDebug = bool.fromEnvironment('SENTRY_DEBUG');

/// En-têtes jamais envoyés à Sentry.
const Set<String> _sensitiveHeaders = {
  'authorization',
  'x-api-key',
  'cookie',
  'set-cookie',
};

bool get sentryEnabled => _dsn.isNotEmpty && (!kDebugMode || _forceInDebug);

/// À appeler une fois, juste après `WidgetsFlutterBinding.ensureInitialized()`.
Future<void> initSentry() async {
  if (!sentryEnabled) return;
  try {
    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.environment = _environment;
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
      options.tracesSampleRate = null;
      options.beforeSend = scrubSentryEvent;
    });
  } catch (e) {
    debugPrint('Sentry non activé : $e');
  }
}

/// Retire les en-têtes sensibles d'un événement avant l'envoi.
FutureOr<SentryEvent?> scrubSentryEvent(SentryEvent event, Hint hint) {
  final request = event.request;
  if (request == null) return event;
  request.headers = Map<String, String>.of(request.headers)
    ..removeWhere((key, _) => _sensitiveHeaders.contains(key.toLowerCase()));
  return event;
}
