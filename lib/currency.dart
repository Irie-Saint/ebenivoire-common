/// La devise affichée, la même dans les trois apps.
///
/// Elle est pilotée par le backend (réglages admin) : `GET /api/app/config`
/// au démarrage, puis chaque réponse d'argent qui porte `currency_symbol` /
/// `currency`. « FCFA » n'est que le secours tant que rien n'est arrivé.
///
/// Avant ce fichier, chaque app avait sa version, et elles divergeaient :
/// - les montants : « 16000 FCFA » dans l'app cliente, « 16 000 FCFA » dans
///   la console ;
/// - un montant en euros : « FCFA » (faux) dans l'app cliente, « € » dans
///   l'app vendeur, « EUR » dans la console.
library;

import 'package:intl/intl.dart';

const String kDefaultCurrencySymbol = 'FCFA';

String _symbol = kDefaultCurrencySymbol;
String _code = 'XOF';

/// Le symbole de la devise de la plateforme (« FCFA » pour XOF). Jamais vide.
String get appCurrencySymbol => _symbol;

/// Le code ISO de la devise de la plateforme (« XOF »).
String get appCurrencyCode => _code;

/// Retient la devise envoyée par le serveur : le [symbol] d'affichage s'il
/// est là, sinon celui qui correspond au [code]. Une valeur vide ne change
/// rien (le serveur qui oublie le champ ne vide pas tous les montants).
void hydrateCurrency({Object? symbol, Object? code}) {
  final c = code?.toString().trim() ?? '';
  if (c.isNotEmpty) _code = c.toUpperCase();
  final s = symbol?.toString().trim() ?? '';
  if (s.isNotEmpty) {
    _symbol = s;
  } else if (c.isNotEmpty) {
    _symbol = _symbolForKnownCode(_code) ?? _code;
  }
}

/// Symbole d'un montant qui porte SA PROPRE devise (une commande, un
/// transfert…) : celui de la plateforme pour la devise de la plateforme, le
/// symbole connu sinon, le code brut en dernier recours. Un montant en euros
/// ne s'affiche jamais en FCFA.
///
/// Même correspondance que le backend (`CURRENCY_SYMBOLS`).
String currencySymbolForCode(String? code) {
  final c = (code ?? '').trim().toUpperCase();
  if (c.isEmpty || c == _code) return _symbol;
  return _symbolForKnownCode(c) ?? c;
}

String? _symbolForKnownCode(String code) {
  switch (code) {
    case 'XOF':
    case 'XAF':
      return kDefaultCurrencySymbol;
    case 'EUR':
      return '€';
    case 'USD':
      return r'$';
  }
  return null;
}

/// `16000` → « 16 000 FCFA ».
///
/// Les milliers sont groupés comme en français, par une espace FINE
/// INSÉCABLE : lisible, et un montant ne se coupe jamais en fin de ligne.
/// XOF n'a pas de centimes, d'où 0 décimale par défaut.
///
/// [symbol] : celui que porte la réponse du serveur, s'il est là.
/// [code] : la devise propre du montant, s'il en a une.
/// [fallback] : affiché quand le montant manque.
String formatMoney(
  num? amount, {
  String? symbol,
  String? code,
  int decimals = 0,
  String fallback = '—',
}) {
  if (amount == null) return fallback;
  final s = (symbol != null && symbol.trim().isNotEmpty)
      ? symbol.trim()
      : currencySymbolForCode(code);
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: s,
    decimalDigits: decimals,
  ).format(amount);
}

/// [formatMoney] pour un montant reçu en TEXTE (« 16000.00 », « 16 000 ») :
/// le nombre est relu puis mis en forme. Un texte qui n'est pas un nombre
/// s'affiche tel quel, suivi du symbole — jamais « null », jamais perdu.
String formatMoneyText(
  Object? raw, {
  String? symbol,
  String? code,
  int decimals = 0,
  String fallback = '—',
}) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return fallback;
  final value = num.tryParse(text.replaceAll(RegExp(r'[\s\u00a0\u202f]'), ''));
  if (value != null) {
    return formatMoney(value, symbol: symbol, code: code, decimals: decimals);
  }
  final s = (symbol != null && symbol.trim().isNotEmpty)
      ? symbol.trim()
      : currencySymbolForCode(code);
  return '$text\u00a0$s';
}

/// [formatMoney] pour un montant qui porte sa propre devise.
String formatMoneyForCode(
  num? amount,
  String? code, {
  int decimals = 0,
  String fallback = '—',
}) => formatMoney(amount, code: code, decimals: decimals, fallback: fallback);

/// Un montant déjà mis en forme par le serveur avec le CODE (« 3 500 XOF »,
/// anciens champs `formatted`) s'affiche avec le symbole.
String displayCurrencyText(String text) =>
    _code.isEmpty ? text : text.replaceAll(_code, _symbol);

/// Remise à zéro (tests).
void resetCurrencyForTests() {
  _symbol = kDefaultCurrencySymbol;
  _code = 'XOF';
}
