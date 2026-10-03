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

## Police — consigne du user du 03/10/2026 (non négociable)
- La police des apps est la **police de départ** : celle que le thème demande
  déjà (`grandisExtendedFont = 'GrandisExtended'`). Ce nom n'est déclaré nulle
  part dans `pubspec.yaml` (la famille déclarée s'écrit `Grandis Extended`, avec
  une espace) : Flutter retombe donc sur la police système (Roboto sur Android).
  C'est EXACTEMENT ce que le user veut garder.
- Interdit : corriger l'orthographe de `grandisExtendedFont`, écrire
  `fontFamily: 'Plus Jakarta'` ou `'Grandis Extended'` dans un widget ou un thème,
  charger ces deux polices dans un rendu de test, ou « aligner la police sur la
  maquette ». Les polices des maquettes HTML (Bricolage Grotesque, Plus Jakarta
  Sans, Sora, Manrope…) sont de la présentation, pas la police de l'app.
- Les rendus de test chargent Roboto (aussi sous l'alias `GrandisExtended`) : c'est
  la vraie police de l'app. Dans la cliente, `test/helpers/customer_real_fonts.dart`
  le fait.
- Si une autre police te semble meilleure : propose-la au user, ne la mets pas.
