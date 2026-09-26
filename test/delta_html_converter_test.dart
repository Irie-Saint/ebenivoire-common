import 'package:ebenivoire_common/delta_html_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texte riche ↔ HTML (descriptions produits du vendeur, CGU et politique
/// produits de la console).
///
/// ⚠️ La copie de la console perdait la largeur choisie pour une image : une
/// image réduite à 50 % dans les CGU revenait pleine largeur à
/// l'enregistrement.
void main() {
  String roundTrip(String html) =>
      DeltaHtmlConverter.deltaToHtml(DeltaHtmlConverter.htmlToDelta(html));

  test('la largeur d’une image survit à l’aller-retour', () {
    final html = roundTrip(
      '<p>Avant</p><img src="https://cdn.test/a.jpg" style="width:50%" />'
      '<p>Après</p>',
    );
    expect(html, contains('https://cdn.test/a.jpg'));
    expect(html, contains('width:50%'));
  });

  test('une image sans largeur reste sans largeur', () {
    final html = roundTrip('<img src="https://cdn.test/b.jpg" />');
    expect(html, contains('https://cdn.test/b.jpg'));
    expect(html, isNot(contains('width:')));
  });

  test('du texte simple (sans balises) devient des paragraphes', () {
    final html = roundTrip('Premier paragraphe.\n\nSecond paragraphe.');
    expect(html, contains('Premier paragraphe.'));
    expect(html, contains('Second paragraphe.'));
  });
}
