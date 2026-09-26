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
| Démarrage cliente SANS réseau, jeton d'accès expiré | 0.3.0 | OK : `SERVER_UNREACHABLE` → session gardée, bandeau « Serveur injoignable » ; au retour, renouvelée |
| Coupure 2 min, console (Commandes) | 0.3.0 | OK : « Serveur injoignable », rechargement seul au retour (console `cb8f04c`) |

Tests : paquet 38, cliente 287, vendeur 302, console 483 — tous verts.

## Reste à faire, dans l'ordre

1. **Coupure de 40 min avec le 0.3.0** sur téléphone (fait avec l'ancien code
   seulement).
2. **Fichiers encore en plusieurs copies** (mesuré le 26/09, taux de
   ressemblance entre apps ; C = cliente, V = vendeur, A = console) :

   **a. Identiques dans les trois — à déplacer tels quels**
   - `features/splash/models/session_validator.dart` (100 %)
   - `features/splash/models/verify_token_error.dart` (98 %)
   - `features/auth/models/email_validation_error.dart` (95 %)
   - `core/services/network_recovery_service.dart` (94 %) — coquille vide :
     à SUPPRIMER au profit de `ServerReachability`, pas à déplacer.

   **b. Démarrage de session (fin du noyau)**
   - `features/splash/models/refresh_token_response.dart` (V/A 94 %, C 80 %)
   - `features/splash/controllers/loading_controller.dart` (V/A 72 %, C 57 %)
   - `core/services/loading_service.dart` (V/A 92 %)
   - `core/services/token_precheck_service.dart` (C seule, logique à
     rapprocher de celle des deux autres)

   **c. Identiques vendeur = console (la cliente diffère)**
   - parcours de connexion : `features/auth/models/**` (OTP, mot de passe
     oublié, vérification : ~15 fichiers à 100 %), `auth_error` (90 %),
     `auth_service` (93 %), `core/services/app_auth_service` (97 %)
   - gardes : `core/mixins/auth_guard.dart`, `core/widgets/app_auth_guard.dart`
     (100 %), `auth_debug_widget.dart` (100 %)
   - outils : `core/mixins/auto_retry_mixin.dart` (98 %, C 87 %),
     `core/services/lifecycle_service.dart` (98 %, C 50 %),
     `config/environment.dart` (93 %, C 72 %), `config/api_config.dart`,
     `config/snackbar_config.dart`, `config/getx_initial_binding.dart` (100 %)
   - écrans : `network_image_with_loader` (98 %), `build_sticky_header`
     (93 %), `account_security` (93 %),
     `products/utils/delta_html_converter.dart` (87 %)

   **d. Identiques cliente = vendeur** : `constants/greater_abidjan.dart`,
   `constants/review_config.dart` (100 %), `app_review_service` (98 %),
   `support_contact` (90 %), `app_config_service`, `terms_service` (79 %).

   **e. Identiques cliente = console** : `widgets/app_skeleton.dart` (100 %),
   `widgets/app_loader.dart` (90 %).

   **f. À laisser par app** (différents pour de bonnes raisons) :
   `main.dart`, `theme`, routes, menus, contrôleurs d'écrans,
   `notification_service`, `push_subscription_service`, traductions propres.
   La cliente garde volontairement son chargement sans fin (squelette +
   réessai) pendant une coupure.

   Ordre conseillé : a → b (finit le noyau) → c (parcours de connexion
   vendeur/console) → d/e (petits fichiers). Les apps utilisent le paquet par
   `ref:` : chaque lot = un commit du paquet + un `ref:` par app.

## Comment modifier le paquet

Voir `README.md` : modifier ici, `flutter analyze` + `flutter test`, pousser sur
`main`, puis dans chaque app passer `ref:` au nouveau commit et
`flutter pub upgrade ebenivoire_common`. Pour travailler sans pousser : un
`pubspec_overrides.yaml` dans l'app (ignoré par git). ⚠️ Lancer les tests des
trois apps l'un APRÈS l'autre : en parallèle, des tests dépassent leur délai.
