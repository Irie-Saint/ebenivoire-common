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

  test('le gras d’un mot reste sur ce mot', () {
    final html = roundTrip('<p>Texte avec <strong>gras</strong> ok.</p>');
    expect(html, '<p>Texte avec <strong>gras</strong> ok.</p>');
  });

  test('aucun titre ni puce vide fabriqué à l’enregistrement', () {
    const source =
        '<h2>Titre ici</h2><p>Texte.</p><ul><li>Un</li><li>Deux</li></ul>';
    final once = roundTrip(source);
    expect(once, source);
    // Enregistrer dix fois ne fait rien grossir.
    var html = once;
    for (var i = 0; i < 10; i++) {
      html = roundTrip(html);
    }
    expect(html, source);
  });

  test('listes numérotées, italique, souligné, lien', () {
    const source =
        '<ol><li><em>Premier</em></li><li><u>Second</u></li></ol>'
        '<p>Voir <a href="https://ebenivoire.test">le site</a>.</p>';
    expect(roundTrip(source), source);
  });

  test('HTML d’un autre éditeur : espaces et balises sans importance', () {
    final html = roundTrip(
      '<div>\n  <p>  Bonjour <b>vous</b></p>\n</div><p></p>',
    );
    expect(html, '<p>Bonjour <strong>vous</strong></p>');
  });

  test('un caractère spécial reste du texte', () {
    expect(
      roundTrip('<p>2 &lt; 3 &amp; « ok »</p>'),
      '<p>2 &lt; 3 &amp; « ok »</p>',
    );
  });

  test('une image entre deux paragraphes garde sa place', () {
    const source =
        '<p>Avant</p><img src="https://cdn.test/a.jpg" alt="" style="width:50%" /><p>Après</p>';
    expect(roundTrip(source), source);
  });
}
