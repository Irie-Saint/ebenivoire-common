import 'package:ebenivoire_common/media_viewer_messages.dart';
import 'package:ebenivoire_common/media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => mediaViewerMessages;
}

Widget _app(Widget Function(BuildContext) child) => GetMaterialApp(
  translations: _Messages(),
  locale: const Locale('fr'),
  home: Scaffold(body: Builder(builder: child)),
);

void main() {
  testWidgets('galerie : « 1 / 3 », flèches sur grand écran, fermer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        (context) => TextButton(
          onPressed: () => MediaViewer.showImages(context, const [
            'https://example.invalid/a.png',
            'https://example.invalid/b.png',
            'https://example.invalid/c.png',
          ]),
          child: const Text('ouvrir'),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Suivante'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 / 3'), findsNothing);
  });

  testWidgets('une seule image : ni compteur ni flèches', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        (context) => TextButton(
          onPressed: () => MediaViewer.showImages(context, const [
            'https://example.invalid/a.png',
          ], title: 'Photo'),
          child: const Text('ouvrir'),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('1 / 1'), findsNothing);
    expect(find.byTooltip('Suivante'), findsNothing);
  });
}
