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
| `currency.dart` | Devise et montants : `formatMoney(16000)` → « 16 000 FCFA » |
| `jwt_utils.dart`, `request_type.dart`, `network_exceptions.dart` | Jetons, nature des appels, erreurs réseau |
| `device_identity.dart` | Identité de l'appareil pour « Mes appareils » |
| `theme_mode_service.dart`, `app_scroll_behavior.dart`, `map_night_style.dart` | Thème clair/sombre, barres de défilement, carte de nuit |
| `truncation_probe.dart`, `debug_utils.dart` | Outils de débogage |
| `base_api_service.dart` | Appels au serveur : jeton vérifié avant l'envoi, 401 → renouvellement, panne → 503 `REFRESH_UNAVAILABLE` |
| `base_session_manager.dart` | Session : vérifier, renouveler, fermer (seulement sur refus explicite) |
| `base_authentication_manager.dart` | État de connexion : connecté tant que la session est renouvelable |
| `base_storage_service.dart` | Stockage des jetons, de l'identité et du parcours de connexion |
| `api_request_guard.dart` | En-têtes d'une requête protégée, jeton vérifié juste avant |
| `refresh_token_error.dart`, `server_unreachable.dart` | Refus du serveur ou panne ? |
| `server_reachability.dart` | Le serveur répond-il ? (sondé tant qu'il ne répond pas) |
| `session_messages.dart` | Leurs traductions FR/EN |
| `session_validator.dart`, `session_check.dart`, `verify_token_error.dart` | Démarrage : que vaut la session enregistrée (valide / refusée / injoignable) |
| `email_validation_error.dart` | Adresse e-mail refusée à l'inscription |
| `auth/…` | Parcours de connexion vendeur et console : erreurs de connexion (`auth_error`), code par SMS, mot de passe oublié, vérification |
| `account_security.dart` | Sécurité du compte (vendeur et console) |
| `auto_retry_mixin.dart` | Réessai automatique d'un chargement (vendeur et console ; la cliente garde le sien) |
| `greater_abidjan.dart` | Communes du Grand Abidjan (cliente et vendeur) |
| `review_config.dart` | Réglages de la demande d'avis sur le store (cliente et vendeur) |
| `rich_text/rich_text_editor.dart` | `RichTextEditor` : éditeur de texte riche Quill (repris d'AEECI) — barre complète, images (largeur en %), tableaux, liens filtrés ; la valeur est du HTML |
| `rich_text/rich_html_view.dart` | `RichHtmlView` : lecteur du même HTML (images en plein écran, tableaux qui défilent, liens filtrés) |
| `rich_text/rich_text_html.dart` | Convertisseur HTML ↔ Delta Quill de l'éditeur |
| `rich_text/rich_text_links.dart` | Liste blanche des liens (http, https, mailto, tel) |
| `rich_text/rich_text_messages.dart` | Clés `rich_text.*` (FR / EN) à déclarer dans les traductions de chaque app |
| `app_lifecycle_service.dart` | Premier plan / arrière-plan (crochet `onAppResumed`) — vendeur et console |
| `brand_colors.dart` | Palette de la marque (mêmes valeurs que les `AppColors` des trois apps) |
| `app_skeleton.dart`, `app_loader.dart` | Squelettes de chargement et indicateurs (cliente et console) |
| `support_contact.dart` | Contact support (secours : support@ebenivoire.com ; le serveur le remplace) |
| `base_app_config_service.dart` | Configuration publique au démarrage (crochet `onConfigLoaded`) |
| `platform_terms.dart`, `base_terms_service.dart` | CGU : lire, accepter la version lue (adresses par app) |
| `base_app_review_service.dart` | Demande d'avis sur le store (crochets `presentSheet`, `feedbackApp`) |
| `custom_snackbar.dart` | Messages courts en haut de l'écran, aux couleurs données par l'app (`configure`) — vendeur et console |

### Noyau de connexion : comment une app s'en sert

Chaque app garde ses classes au même endroit (`lib/core/services/…`), qui
**héritent** de celles du paquet et remplissent des crochets : services de
l'app, codes d'état du compte qui ferment la session
(`extraSessionEndingCodes`), ce qu'on vide à la fermeture
(`onSessionCleared`), ce qu'on fait après un renouvellement
(`onTokensRefreshed`), un 403 propre à l'app (`onForbidden`)… Règle : une
panne ne déconnecte jamais ; seuls un refus explicite du serveur ou
l'expiration du jeton de renouvellement ferment la session.

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

Où on en est et ce qui reste : [docs/SUITE.md](docs/SUITE.md).

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
