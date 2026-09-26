# Paquet commun : où on en est, ce qui reste

Mémoire du chantier « un seul exemplaire du code commun aux trois apps »
(app cliente `EbenIvoire`, app vendeur `EbenIvoire-Vendeur`, console
`EbenIvoire-Admin`). À lire avant de reprendre.

## Fait (septembre 2026)

| Version | Commit | Contenu |
|---|---|---|
| 0.1.0 | `7c355a5` | afficheur d'images/vidéos, Sentry, écran « mal configurée », traductions Material, responsive, outils de débogage |
| 0.2.0 | `cfbad21` | devise unique (`formatMoney`, milliers séparés « 16 000 FCFA »), jwt_utils, request_type, network_exceptions, device_identity, theme_mode_service, app_scroll_behavior, map_night_style |
| 0.3.0 | `1fd9e1e` | **noyau de connexion** : `base_api_service`, `base_session_manager`, `base_authentication_manager`, `base_storage_service`, `api_request_guard`, `refresh_token_error`, `server_unreachable`, `server_reachability`, `session_messages` (FR/EN) |

Les trois apps épinglent un **numéro de commit** (`ref:` dans `pubspec.yaml`),
pas une étiquette : l'environnement de Claude ne peut pas pousser d'étiquettes.
Branchement du 0.3.0 (sur `dev`) : cliente `8d3b758` + `7ea7f26`, vendeur
`f5d5767` + `bf63985`, console `de13e8d`.

### Noyau de connexion (0.3.0) : ce qui a été décidé

Chaque app garde ses classes au même chemin (`lib/core/services/…`,
`lib/core/guards/api_request_guard.dart`) : elles **héritent** du paquet et
remplissent des crochets. Les imports et les tests des apps n'ont pas bougé.

Règle de session : une panne du serveur ou du réseau ne déconnecte jamais ;
la requête est retenue avec « serveur injoignable » (`HttpException` 503,
`REFRESH_UNAVAILABLE`). Seuls un refus explicite du serveur ou l'expiration
du jeton de renouvellement ferment la session.

Écarts tranchés :
- **Codes qui déconnectent** : liste commune (`INVALID_REFRESH_TOKEN`,
  `USER_NOT_FOUND`, `USER_INACTIVE`, `ACCOUNT_INACTIVE`, `ACCOUNT_SUSPENDED`)
  + `extraSessionEndingCodes` par app (`CUSTOMER_*` ; `VENDOR_INACTIVE`,
  `VENDOR_LOGIN_RESTRICTED` ; `ADMIN_DEACTIVATED`).
- **401** : ne ferme plus la session seul. On renouvelle et c'est la réponse
  qui décide (refus → fermée, panne → 503 gardée). Trou fermé : un 401 suivi
  d'une panne au renouvellement déconnectait (cliente, console).
- **`_verifyTokenSync`** après renouvellement : partout.
- **Console** : plus de fermeture sur le texte « refresh token » ; la double
  vérification des super admins (`ADMIN_CODE_REQUIRED`) est dans l'écran de
  connexion, inchangée (le 403 des requêtes de connexion passe tel quel).
- **« Connecté ? »** = session renouvelable (règle de la console), plus
  seulement jeton d'accès valide.
- **Garde de requêtes** : une panne lève 503 ; la cliente n'envoie plus la
  requête sans jeton comme un invité.
- **Serveur joignable ?** (`ServerReachability`) : faux sur une panne, vrai à
  la première réponse ; sondé (`GET /` toutes les 10 s) tant qu'il ne répond
  pas. Le vendeur s'en sert dans `VendorErrorState` : « Serveur injoignable »
  pendant la panne, rechargement tout seul au retour.

Corrigés en chemin (trouvés au test sur téléphone) :
- cliente : une panne **au démarrage** effaçait la session
  (`TokenPreCheckService`) ;
- cliente : la session doit créer `ApiService` au démarrage (les services
  des écrans le cherchent aussitôt).

### Vérifié sur téléphone (Xiaomi, 26/09)

| Cas | Code | Résultat |
|---|---|---|
| Coupure 2 min, cliente | ancien | OK : 503 en boucle, jamais la connexion, reprise |
| Coupure 2 min, vendeur | ancien | OK côté session ; écran « erreur inattendue » sans rechargement |
| Coupure 40 min (jeton d'accès expiré pendant la coupure), cliente + vendeur | ancien | OK : renouvellement `SERVER_UNREACHABLE` → session gardée, reprise au retour |
| Coupure 2 min, cliente | 0.3.0 | OK : 31 × 503, 0 fermeture, 0 × 401, panier rechargé seul |
| Coupure 2 min, vendeur | 0.3.0 | OK : « Serveur injoignable », rechargement seul 3 s après le retour du réseau |
| Démarrage vendeur, jeton d'accès expiré | 0.3.0 | OK : renouvelé au lancement, session gardée |

Tests : paquet 38, cliente 287, vendeur 302, console 483 — tous verts.

## Reste à faire, dans l'ordre

1. **Vérifier sur téléphone** : console (pas testée sur appareil) ; démarrage
   de la cliente SANS réseau avec un jeton d'accès expiré (corrigé et testé en
   automatique, pas encore sur appareil) ; coupure de 40 min avec le 0.3.0.
2. **Fichiers presque identiques** à réconcilier puis déplacer :
   `lifecycle_service` (vendeur ≈ console), `auto_retry_mixin` (vendeur ≈
   console), `network_recovery_service` (coquille vide chez le vendeur : le
   remplacer par `ServerReachability`), démarrage de session
   (`session_validator`, `loading_controller`, `RefreshTokenResponse` :
   dupliqués dans les trois apps), traductions communes (erreurs réseau).
3. **Console** : brancher `ServerReachability` dans son état d'erreur, comme
   le vendeur (« serveur injoignable » + rechargement tout seul).
4. **À laisser par app** (différents pour de bonnes raisons) :
   `notification_service`, `push_subscription_service`, `main.dart`, `theme`,
   routes, traductions propres. La cliente garde volontairement son
   chargement sans fin (squelette + réessai) pendant une coupure.

## Comment modifier le paquet

Voir `README.md` : modifier ici, `flutter analyze` + `flutter test`, pousser sur
`main`, puis dans chaque app passer `ref:` au nouveau commit et
`flutter pub upgrade ebenivoire_common`. Pour travailler sans pousser : un
`pubspec_overrides.yaml` dans l'app (ignoré par git). ⚠️ Lancer les tests des
trois apps l'un APRÈS l'autre : en parallèle, des tests dépassent leur délai.
