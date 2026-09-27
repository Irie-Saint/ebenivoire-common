import 'package:ebenivoire_common/brand_colors.dart';
import 'package:ebenivoire_common/brand_name_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chargement des photos, commun aux 3 apps : le nom « EbènIvoire » qui
/// scintille (décision du 27/09), y compris dans la visionneuse plein écran.
Widget _box(Widget child) => MaterialApp(
  home: Center(child: SizedBox(width: 200, height: 200, child: child)),
);

Color _background(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(BrandNameLoader),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

void main() {
  testWidgets('fond clair : le nom sur le fond des squelettes', (tester) async {
    await tester.pumpWidget(_box(const BrandNameLoader()));
    expect(find.text(BrandNameLoader.brandName), findsOneWidget);
    expect(_background(tester), BrandColors.skeletonBaseLight);
  });

  testWidgets('visionneuse (fond noir) : le nom seul, sans fond gris', (
    tester,
  ) async {
    await tester.pumpWidget(_box(const BrandNameLoader(onDark: true)));
    expect(find.text(BrandNameLoader.brandName), findsOneWidget);
    expect(_background(tester), Colors.transparent);
  });
}
