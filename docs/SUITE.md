# Paquet commun : où on en est, ce qui reste

Mémoire du chantier « un seul exemplaire du code commun aux trois apps »
(app cliente `EbenIvoire`, app vendeur `EbenIvoire-Vendeur`, console
`EbenIvoire-Admin`). À lire avant de reprendre.

## Fait (septembre 2026)

| Version | Commit | Contenu |
|---|---|---|
| 0.1.0 | `7c355a5` | afficheur d'images/vidéos, Sentry, écran « mal configurée », traductions Material, responsive, outils de débogage |
| 0.2.0 | `cfbad21` | devise unique (`formatMoney`, milliers séparés « 16 000 FCFA »), jwt_utils, request_type, network_exceptions, device_identity, theme_mode_service, app_scroll_behavior, map_night_style |

Les trois apps épinglent un **numéro de commit** (`ref:` dans `pubspec.yaml`),
pas une étiquette : l'environnement de Claude ne peut pas pousser d'étiquettes.

Aligné en même temps dans les trois apps (hors paquet) : la reprise de session
pendant une panne du serveur. Règle : une panne ne déconnecte jamais, la
requête est retenue avec « serveur injoignable » (`HttpException` 503,
`REFRESH_UNAVAILABLE`) ; seuls un refus explicite ou l'expiration du jeton de
renouvellement ferment la session. Test `test/session_refresh_outage_test.dart`
dans chaque app.

## À vérifier sur téléphone

- Panne pendant l'utilisation : app ouverte, couper le Wi-Fi 1 à 2 min, le
  rétablir → « serveur injoignable » puis reprise, jamais l'écran de connexion.

## Reste à faire, dans l'ordre

1. **Noyau de connexion dans le paquet** (`api_service`, `session_manager`,
   `authentication_manager`, `storage_service`, `api_request_guard`).
   Environ 60 % du code est commun (une vingtaine de fonctions). Le reste est
   propre à chaque app : statut vendeur et conditions (vendeur), panier et
   profil (cliente), droits admin (console). Méthode proposée : une classe de
   base dans le paquet + des « crochets » que chaque app remplit
   (`onSessionExpired`, `onTokensRefreshed`, codes d'erreur qui déconnectent).
   À faire APRÈS la vérification sur téléphone ci-dessus. Environ une journée.
   Écarts encore présents dans les fonctions communes :
   - `_isAuthErrorCode` / codes qui déconnectent : listes différentes ;
   - `_verifyTokenSync` après renouvellement : cliente et console oui,
     vendeur non ;
   - `_handleUnauthorizedResponse` : la console ne ferme la session que sur un
     marqueur explicite d'expiration, les deux apps sur une liste de codes.
2. **Fichiers presque identiques** à réconcilier puis déplacer :
   `lifecycle_service` (vendeur ≈ console), `auto_retry_mixin` (vendeur ≈
   console), `network_recovery_service` (partie commune seulement),
   `storage_service` (vendeur ≈ console, la cliente diffère beaucoup),
   traductions communes (erreurs réseau, session).
3. **À laisser par app** (différents pour de bonnes raisons) :
   `notification_service`, `push_subscription_service`, `main.dart`, `theme`,
   routes, traductions propres.

## Comment modifier le paquet

Voir `README.md` : modifier ici, `flutter analyze` + `flutter test`, pousser sur
`main`, puis dans chaque app passer `ref:` au nouveau commit et
`flutter pub upgrade ebenivoire_common`.
