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
      ref: <numéro de commit>   # version 0.1.0
```

`ref` pointe un commit précis : une app ne change jamais de version du
paquet sans qu'on le décide (une étiquette `vX.Y.Z` marche aussi).

```dart
import 'package:ebenivoire_common/media_viewer.dart';
```

## Modifier le paquet

1. Modifier ici, `flutter analyze` et `flutter test`.
2. Monter `version` dans `pubspec.yaml`, pousser sur `main`.
3. Dans chaque app, passer `ref:` au nouveau numéro de commit, puis
   `flutter pub upgrade ebenivoire_common`.

Travailler sur le paquet et une app en même temps, sans pousser : dans l'app,
un fichier `pubspec_overrides.yaml` (non commité) :

```yaml
dependency_overrides:
  ebenivoire_common:
    path: ../ebenivoire-common
```
