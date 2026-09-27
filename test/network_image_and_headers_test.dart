import 'package:ebenivoire_common/api_request_guard.dart';
import 'package:ebenivoire_common/brand_name_loader.dart';
import 'package:ebenivoire_common/network_image_with_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Image réseau et en-têtes communs du vendeur et de la console.
void main() {
  test('en-têtes : clé d’API, et mode débogage seulement si demandé', () {
    expect(defaultApiHeaders(apiKey: 'k'), {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Key': 'k',
    });
    expect(
      defaultApiHeaders(apiKey: 'k', debugMode: true)['X-Debug-Mode'],
      'true',
    );
  });

  testWidgets('image en chargement : le nom de la marque, même en liste', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: NetworkImageWithLoader.forList(
            imageUrl: 'https://exemple.invalid/p.jpg',
            width: 120,
            height: 120,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(BrandNameLoader), findsOneWidget);
  });

  testWidgets('adresse vide : image de secours, aucune requête', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: NetworkImageWithLoader(imageUrl: '  ', width: 80, height: 80),
        ),
      ),
    );
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.byType(BrandNameLoader), findsNothing);
  });
}
