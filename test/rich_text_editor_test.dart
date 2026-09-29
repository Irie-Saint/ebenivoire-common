import 'package:ebenivoire_common/material_localizations.dart';
import 'package:ebenivoire_common/rich_text/rich_html_view.dart';
import 'package:ebenivoire_common/rich_text/rich_text_editor.dart';
import 'package:ebenivoire_common/rich_text/rich_text_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: appSupportedLocales,
  locale: const Locale('fr'),
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  testWidgets('un tableau se modifie dans l’app et reste un tableau', (
    tester,
  ) async {
    String? html;
    await tester.pumpWidget(
      _app(
        RichTextEditor(
          value:
              '<p>Tailles</p><hr />'
              '<table><tbody><tr><th><p>Taille</p></th><th><p>Prix</p></th></tr>'
              '<tr><td><p>M</p></td><td><p>9 000</p></td></tr></tbody></table>',
          onChanged: (value) => html = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('M'), findsOneWidget);
    expect(find.byTooltip('Insérer un tableau'), findsOneWidget);
    expect(find.byTooltip('Ligne de séparation'), findsOneWidget);
    // Sans envoi d'image fourni, pas d'outil image.
    expect(find.byTooltip('Insérer une image'), findsNothing);

    await tester.tap(find.byKey(const Key('rich-table')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '9 000'), '10 000');
    await tester.tap(find.byKey(const Key('rich-table-done')));
    await tester.pumpAndSettle();

    expect(find.text('10 000'), findsOneWidget);
    expect(
      html,
      '<p>Tailles</p><hr />'
      '<table><tbody><tr><th><p>Taille</p></th><th><p>Prix</p></th></tr>'
      '<tr><td><p>M</p></td><td><p>10 000</p></td></tr></tbody></table>',
    );
  });

  testWidgets('une image envoyée est insérée, puis réduite à 50 %', (
    tester,
  ) async {
    String? html;
    await tester.pumpWidget(
      _app(
        RichTextEditor(
          value: '<p>Texte</p>',
          onChanged: (value) => html = value,
          onPickImage: () async => 'https://cdn.test/a.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insérer une image'));
    await tester.pumpAndSettle();
    expect(html, '<p>Texte</p><img src="https://cdn.test/a.jpg" alt="" />');

    await tester.tap(find.byKey(const Key('rich-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rich-image-width-50')));
    await tester.pumpAndSettle();
    expect(html, contains('style="width:50%"'));

    await tester.tap(find.byKey(const Key('rich-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rich-image-remove')));
    await tester.pumpAndSettle();
    expect(html, isNot(contains('<img')));
  });

  testWidgets('l’erreur d’envoi d’une image s’affiche sous l’éditeur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        RichTextEditor(
          value: '',
          onChanged: (_) {},
          onPickImage: () async =>
              throw const RichTextImageException('Image trop lourde (5 Mo).'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insérer une image'));
    await tester.pumpAndSettle();
    expect(find.text('Image trop lourde (5 Mo).'), findsOneWidget);
  });

  testWidgets('un lien javascript: est refusé à la saisie', (tester) async {
    await tester.pumpWidget(
      _app(RichTextEditor(value: '<p>Texte</p>', onChanged: (_) {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lien'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rich-link-input')),
      'javascript:alert(1)',
    );
    await tester.tap(find.byKey(const Key('rich-link-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saisissez une adresse web'), findsOneWidget);
  });

  testWidgets('une valeur venue de l’extérieur recharge le document', (
    tester,
  ) async {
    final value = ValueNotifier('<p>Avant</p>');
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: value,
          builder: (_, html, _) =>
              RichTextEditor(value: html, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Avant', findRichText: true), findsOneWidget);
    value.value = '<h2>Proposé par l’IA</h2><p>Après</p>';
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Proposé par l’IA', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Avant', findRichText: true), findsNothing);
    expect(find.textContaining('Après', findRichText: true), findsOneWidget);
  });

  test('liste blanche des liens', () {
    expect(RichTextLinks.parse('https://ebenivoire.ci/a'), isNotNull);
    expect(RichTextLinks.parse('mailto:contact@ebenivoire.ci'), isNotNull);
    expect(RichTextLinks.parse('tel:+2250700000000'), isNotNull);
    expect(RichTextLinks.parse('javascript:alert(1)'), isNull);
    expect(RichTextLinks.parse('https://'), isNull);
    expect(RichTextLinks.parse(''), isNull);
  });

  testWidgets('le lecteur affiche un tableau, une citation et une liste', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const RichHtmlView(
          html:
              '<h2>Guide</h2><blockquote><p>Coton bio</p></blockquote>'
              '<ul><li>Lavage 30°</li></ul>'
              '<table><tbody><tr><th><p>Taille</p></th></tr>'
              '<tr><td><p>M</p></td></tr></tbody></table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Guide'), findsOneWidget);
    expect(find.textContaining('Coton bio'), findsOneWidget);
    expect(find.textContaining('Lavage 30°'), findsOneWidget);
    expect(find.textContaining('Taille'), findsOneWidget);
    expect(find.textContaining('M'), findsWidgets);
  });

  testWidgets('le lecteur respecte la largeur d’une image (50 %)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const RichHtmlView(
          html: '<img src="https://cdn.test/a.jpg" alt="" style="width:50%" />',
        ),
      ),
    );
    await tester.pump();
    final box = tester.getSize(
      find
          .descendant(
            of: find.byKey(const Key('rich-view-image')),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.width, closeTo(200, 1));
  });
}
