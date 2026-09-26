import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';

import 'network_exceptions.dart';

/// Un réessai automatique arrêté parce que l'écran n'est plus affiché.
class RetryPausedError extends Error {
  final String message;
  RetryPausedError(this.message);

  @override
  String toString() => 'RetryPausedError: $message';
}

/// Vrai quand [error] est une PANNE (réseau, délai, 5xx, 429) et non un refus.
///
/// ⚠️ Reconnue par le TYPE, jamais par des mots dans le texte :
/// « TimeoutException after 0:00:30: Request timed out » ne contient pas
/// « timeout » en minuscules, et l'ancienne détection ratait la panne.
bool isServerUnreachable(Object error) {
  if (error is TimeoutException || error is io.SocketException) return true;
  if (error is RetryPausedError) return true;
  if (error is HttpException) {
    // 503 = aussi « pas de connexion » côté ApiService (connectionError).
    return error.status >= 500 || error.status == 429 || error.status == 408;
  }
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == null || status >= 500 || status == 429;
  }
  return false;
}
