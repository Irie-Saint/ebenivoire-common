import 'package:ebenivoire_common/purchase_summary.dart';
import 'package:flutter_test/flutter_test.dart';

String _translate(String key, Map<String, String> values) => switch (key) {
  'purchase.delay.one' => '1 jour',
  'purchase.delay.days' => '${values['max']} jours',
  'purchase.delay.range' => '${values['min']} à ${values['max']} jours',
  'purchase.deferred.one' =>
    '1 article sur commande. ${values['delay']} Expédition complète.',
  'purchase.deferred.many' =>
    '${values['quantity']} articles sur commande. ${values['delay']} Expédition complète.',
  _ => throw StateError('Clé inattendue : $key'),
};

void main() {
  test('anciens contrats sans snapshot ne créent pas de faux délai', () {
    for (final raw in [null, <String, dynamic>{}, 'ancien contrat']) {
      expect(PurchaseSummary.fromJson(raw).describe(_translate), isEmpty);
    }
  });

  test('la promesse de la ligne reste celle annoncée à la commande', () {
    final snapshot = {
      'backorder_quantity': '3',
      'preparation': {'min_days': 3, 'max_days': 5},
    };
    final promise = PurchaseSummary.fromJson(snapshot);
    (snapshot['preparation'] as Map)['max_days'] = 10;
    expect(
      promise.describe(_translate),
      '3 articles sur commande. 3 à 5 jours Expédition complète.',
    );
  });

  test('singulier du délai et de la quantité, sans null dans les replis', () {
    final one = PurchaseSummary.fromJson({
      'backorder_quantity': 1,
      'preparation': {'min_days': 1, 'max_days': 1},
    });
    expect(
      one.describe(_translate),
      contains('1 article sur commande. 1 jour'),
    );
    final legacy = PurchaseSummary.fromJson({'backorder_quantity': 2});
    expect(legacy.describe(_translate), contains('2 articles sur commande.'));
    expect(legacy.describe(_translate), isNot(contains('null')));
  });
}
