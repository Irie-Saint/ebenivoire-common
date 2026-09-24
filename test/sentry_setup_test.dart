import 'package:ebenivoire_common/sentry_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('sans DSN (tests), Sentry reste éteint', () {
    expect(sentryEnabled, isFalse);
  });

  test('la clé d’API et les jetons ne partent jamais', () async {
    final event = SentryEvent(
      request: SentryRequest(
        url: 'https://api.example/api/cart',
        headers: const {
          'X-API-Key': 'cle-secrete',
          'Authorization': 'Bearer abc',
          'Accept-Language': 'fr',
        },
      ),
    );
    final scrubbed = await scrubSentryEvent(event, Hint());
    expect(scrubbed!.request!.headers.keys, ['Accept-Language']);
  });
}
