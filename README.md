# ebenivoire_common

Le code Flutter commun aux trois apps EbenIvoire (cliente, vendeur, console),
en un seul exemplaire. Avant ce paquet, chaque fichier existait en trois
copies qu'il fallait penser à modifier ensemble.

| Fichier | Contenu |
|---|---|
| `media_viewer.dart` | Afficheur d'images et lecteur vidéo plein écran |
| `media_viewer_messages.dart` | Ses traductions FR/EN |
| `sentry_setup.dart` | Démarrage de Sentry (rien ne part sans DSN, pas de données personnelles) |
| `misconfigured_app.dart` | Écran affiché quand l'app est mal configurée |
| `material_localizations.dart` | Traductions des widgets Flutter (sélecteur de date…) |
| `responsive.dart` | Points de rupture mobile / tablette / bureau |
| `truncation_probe.dart`, `debug_utils.dart` | Outils de débogage |

## Utilisation dans une app

```yaml
dependencies:
  ebenivoire_common:
    git:
      url: https://github.com/Irie-Saint/ebenivoire-common.git
      ref: v0.1.0
```

```dart
import 'package:ebenivoire_common/media_viewer.dart';
```

## Modifier le paquet

1. Modifier ici, `flutter analyze` et `flutter test`.
2. Monter `version` dans `pubspec.yaml`, pousser, créer l'étiquette
   (`git tag v0.1.1 && git push origin v0.1.1`).
3. Dans chaque app, passer `ref:` à la nouvelle étiquette, puis
   `flutter pub upgrade ebenivoire_common`.

Travailler sur le paquet et une app en même temps, sans pousser : dans l'app,
un fichier `pubspec_overrides.yaml` (non commité) :

```yaml
dependency_overrides:
  ebenivoire_common:
    path: ../ebenivoire-common
```
