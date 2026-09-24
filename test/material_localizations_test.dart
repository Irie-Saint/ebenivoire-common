import 'package:ebenivoire_common/material_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Le calendrier s'affichait en anglais : l'app n'embarquait aucun libellé
/// Material français. Même configuration que `main.dart`.
void main() {
  testWidgets('le sélecteur de date parle français', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('fr'),
        fallbackLocale: const Locale('en', 'US'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 19),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.textContaining('septembre'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
