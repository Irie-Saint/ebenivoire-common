import 'package:ebenivoire_common/currency.dart';
import 'package:flutter_test/flutter_test.dart';

// Espace fine insécable entre les milliers, insécable avant le symbole.
String _plain(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

void main() {
  setUp(resetCurrencyForTests);

  test('les milliers sont séparés, jamais « 16000 FCFA »', () {
    expect(_plain(formatMoney(16000)), '16 000 FCFA');
    expect(_plain(formatMoney(1250000)), '1 250 000 FCFA');
    expect(_plain(formatMoney(500)), '500 FCFA');
  });

  test('un montant ne se coupe jamais en fin de ligne', () {
    final text = formatMoney(16000);
    expect(
      text.contains(' '),
      isFalse,
      reason: 'espace ordinaire = coupure possible',
    );
  });

  test('montant absent : le repli', () {
    expect(formatMoney(null), '—');
    expect(formatMoney(null, fallback: ''), '');
  });

  test('le symbole du serveur a la priorité', () {
    expect(_plain(formatMoney(100, symbol: 'CFA')), '100 CFA');
    expect(_plain(formatMoney(100, symbol: '  ')), '100 FCFA');
  });

  test('un montant en euros ne s\'affiche jamais en FCFA', () {
    expect(currencySymbolForCode('EUR'), '€');
    expect(currencySymbolForCode('usd'), r'$');
    expect(currencySymbolForCode('GHS'), 'GHS');
    expect(_plain(formatMoneyForCode(20, 'EUR')), '20 €');
    expect(currencySymbolForCode(null), 'FCFA');
    expect(currencySymbolForCode('XOF'), 'FCFA');
  });

  test(
    'la devise du serveur remplace le secours, une valeur vide ne change rien',
    () {
      hydrateCurrency(symbol: 'F CFA', code: 'xof');
      expect(appCurrencySymbol, 'F CFA');
      expect(appCurrencyCode, 'XOF');
      expect(currencySymbolForCode('XOF'), 'F CFA');

      hydrateCurrency(symbol: '', code: '');
      expect(appCurrencySymbol, 'F CFA');

      hydrateCurrency(code: 'EUR');
      expect(appCurrencySymbol, '€');
    },
  );

  test('texte déjà mis en forme par le serveur avec le code', () {
    expect(displayCurrencyText('3 500 XOF'), '3 500 FCFA');
  });

  test('montant reçu en texte', () {
    expect(_plain(formatMoneyText('16000.00')), '16 000 FCFA');
    expect(_plain(formatMoneyText('16 000', symbol: 'CFA')), '16 000 CFA');
    expect(_plain(formatMoneyText(24000)), '24 000 FCFA');
    expect(_plain(formatMoneyText('Gratuit')), 'Gratuit FCFA');
    expect(formatMoneyText(null), '—');
    expect(formatMoneyText('  '), '—');
  });
}
