import 'dart:async';

import 'package:ebenivoire_common/error_messages.dart';
import 'package:ebenivoire_common/network_exceptions.dart';
import 'package:ebenivoire_common/session_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => sessionMessages;
}

void main() {
  setUp(() {
    Get.addTranslations(_Messages().keys);
    Get.locale = const Locale('fr');
  });

  test('refus du serveur : son message', () {
    expect(
      userMessageOf(
        HttpException('Stock insuffisant pour cette version.', 409),
        fallback: 'Échec',
      ),
      'Stock insuffisant pour cette version.',
    );
  });

  test('pas de réponse : « Pas de connexion »', () {
    const noConnection =
        'Pas de connexion. Vérifiez votre réseau et réessayez.';
    expect(
      userMessageOf(HttpException('x', 503, noAnswer: true), fallback: 'Échec'),
      noConnection,
    );
    expect(
      userMessageOf(TimeoutException('t'), fallback: 'Échec'),
      noConnection,
    );
  });

  test('autre erreur : le message de l’écran, jamais le texte brut', () {
    expect(
      userMessageOf(const FormatException('bad json'), fallback: 'Échec'),
      'Échec',
    );
    expect(isNoServerAnswer(const FormatException('bad json')), isFalse);
  });
}
