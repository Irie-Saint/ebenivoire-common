import 'package:ebenivoire_common/rich_text/rich_text_html.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texte riche ↔ HTML. Les six premiers cas sont ceux d'AEECI
/// (`gestion_rich_text_test.dart`), les suivants les nôtres.
String roundTrip(String html) => richDeltaToHtml(richHtmlToDelta(html));

void main() {
  test('garde paragraphes, titres et formatage', () {
    const html =
        '<h2>Titre</h2><p>Un <strong>gras</strong> et <em>italique</em> '
        '<u>souligné</u> <span style="text-decoration: line-through;">barré</span> '
        '<code>c</code> <a href="https://ebenivoire.test">lien</a></p>'
        '<p style="text-align: center;">Centré</p><p>Deux</p>';
    expect(roundTrip(html), html);
  });

  test('listes imbriquées, citations et paragraphes vides', () {
    const html =
        '<ul class="list-bullet"><li value="1">a<ul><li>a1</li></ul></li>'
        '<li value="2">b</li></ul><ol><li>un</li></ol>'
        '<blockquote>cit</blockquote><p></p><h3>Fin</h3>';
    expect(
      roundTrip(html),
      '<ul><li>a<ul><li>a1</li></ul></li><li>b</li></ul><ol><li>un</li></ol>'
      '<blockquote><p>cit</p></blockquote><p></p><h3>Fin</h3>',
    );
  });

  test('les images gardent leur texte alternatif', () {
    const html =
        '<p>Avant</p><img src="https://s/a.jpg" alt="Table" /><p>Après</p>';
    expect(roundTrip(html), html);
  });

  test('échappe le texte et signale les éléments non modifiables', () {
    expect(
      roundTrip('<p>a &lt; b &amp; "c"</p>'),
      '<p>a &lt; b &amp; &quot;c&quot;</p>',
    );
    expect(
      richTextUnsupported(
        '<p>x</p><table><tr><td><strong>1</strong></td></tr></table><hr /><iframe src="y"></iframe>',
      ),
      {'table', 'iframe'},
    );
    expect(richTextUnsupported('<p>x</p><hr />'), isEmpty);
    expect(roundTrip(''), '');
  });

  test('tableaux à cellules de texte et lignes de séparation modifiables', () {
    const html =
        '<p>Avant</p><hr />'
        '<table class="lexical-table"><tbody>'
        '<tr><th style="border:1px"><p>Taille</p></th><th><p>Prix</p></th></tr>'
        '<tr><td><p>100 cm</p></td><td><p>45 000<br>FCFA</p></td></tr>'
        '</tbody></table><p>Après</p>';
    expect(
      roundTrip(html),
      '<p>Avant</p><hr />'
      '<table><tbody><tr><th><p>Taille</p></th><th><p>Prix</p></th></tr>'
      '<tr><td><p>100 cm</p></td><td><p>45 000<br>FCFA</p></td></tr></tbody></table>'
      '<p>Après</p>',
    );
  });

  test('un élément non modifiable est conservé tel quel au milieu du texte', () {
    const video = '<iframe src="https://www.youtube.com/embed/x"></iframe>';
    const rich =
        '<table><tbody><tr><td><strong>Gras</strong></td></tr></tbody></table>';
    expect(roundTrip('<p>A</p>$video<p>B</p>'), '<p>A</p>$video<p>B</p>');
    expect(roundTrip('<p>A</p>$rich'), '<p>A</p>$rich');
  });

  // --- EbènIvoire -----------------------------------------------------------

  test('la largeur d’une image (en %) survit à l’aller-retour', () {
    const html =
        '<p>Avant</p><img src="https://cdn.test/a.jpg" alt="" style="width:50%" /><p>Après</p>';
    expect(roundTrip(html), html);
    // Écrite sans espace par le nettoyage du serveur : relue pareil.
    expect(
      roundTrip('<img src="https://cdn.test/a.jpg" style="width: 30%">'),
      '<img src="https://cdn.test/a.jpg" alt="" style="width:30%" />',
    );
  });

  test('le gras d’un mot reste sur ce mot', () {
    expect(
      roundTrip('<p>Texte avec <strong>gras</strong> ok.</p>'),
      '<p>Texte avec <strong>gras</strong> ok.</p>',
    );
  });

  test('enregistrer dix fois ne fait rien grossir', () {
    const html =
        '<h2>Titre</h2><p>Texte.</p><ul><li>Un</li><li>Deux</li></ul>'
        '<table><tbody><tr><th><p>A</p></th></tr><tr><td><p>1</p></td></tr></tbody></table>';
    var out = roundTrip(html);
    for (var i = 0; i < 10; i++) {
      out = roundTrip(out);
    }
    expect(out, roundTrip(html));
  });

  test('du texte sans balise devient des paragraphes', () {
    expect(
      roundTrip('Premier paragraphe.\n\nSecond paragraphe.'),
      '<p>Premier paragraphe.</p><p>Second paragraphe.</p>',
    );
  });

  test('texte brut d’un HTML', () {
    expect(richHtmlPlainText('<h2>A</h2><p>b <strong>c</strong></p>'), 'A b c');
    expect(richHtmlPlainText('<p><br></p>'), '');
  });
}
