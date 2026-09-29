# EbenIvoire — paquet commun Flutter

**Avant toute action, lis `E:\PythonProjects\EbenIvoireBackend\docs\REPRISE_IA.md`**
(méthode, règles, mémoire, skills) et `docs/SUITE.md` (journal des versions).

Procédure de livraison (dans l'ordre) :
1. `flutter analyze` et `flutter test` ici ;
2. monter `version:` dans `pubspec.yaml`, ajouter une ligne à `docs/SUITE.md` ;
3. commit, push sur `main` ;
4. dans chaque app (`ebenivoire`, `ebenivoire_vendeur`, `ebenivoire_admin`) :
   mettre le hash dans `ref:` (avec `# version x.y.z`), `flutter pub get`,
   puis `flutter analyze` + `flutter test` **une app après l'autre** ;
5. commit LOCAL dans chaque app (branche `dev`, pas de push).

Le paquet ne doit jamais forcer une montée de version d'une dépendance chez
une app. Réponds au user en français.
