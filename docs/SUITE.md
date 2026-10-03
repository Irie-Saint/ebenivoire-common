# Paquet commun : où on en est, ce qui reste

Mémoire du chantier « un seul exemplaire du code commun aux trois apps »
(app cliente `EbenIvoire`, app vendeur `EbenIvoire-Vendeur`, console
`EbenIvoire-Admin`). À lire avant de reprendre.

## En local — 02/10/2026, achat sur commande

`lib/purchase_summary.dart` porte la promesse figée des lignes de commande
(quantité différée, délai, pluriels), sans skin visuel. Utilisé par les trois apps.
Analyse propre et trois tests réussis : compatibilité des anciens contrats,
promesse conservée et singulier du délai/quantité. Pas encore publié : la version
du paquet reste 0.13.8 et les apps de travail utilisent un override local.
Publier le paquet et remplacer les refs git des apps au Go de publication,
puis vérifier les apps successivement avant d'activer la capacité serveur.

## Fait (septembre 2026)

| Version | Commit | Contenu |
|---|---|---|
| 0.1.0 | `7c355a5` | afficheur d'images/vidéos, Sentry, écran « mal configurée », traductions Material, responsive, outils de débogage |
| 0.2.0 | `cfbad21` | devise unique (`formatMoney`, milliers séparés « 16 000 FCFA »), jwt_utils, request_type, network_exceptions, device_identity, theme_mode_service, app_scroll_behavior, map_night_style |
| 0.3.0 | `1fd9e1e` | **noyau de connexion** : `base_api_service`, `base_session_manager`, `base_authentication_manager`, `base_storage_service`, `api_request_guard`, `refresh_token_error`, `server_unreachable`, `server_reachability`, `session_messages` (FR/EN) |
| 0.4.0 | (ce commit) | démarrage de session : `session_validator`, `session_check`, `verify_token_error`, `email_validation_error` ; `refreshTokensOrThrow` (un seul renouvellement partagé) et `verifyStoredToken` dans la session commune |
| 0.5.0 | (ce commit) | lot c (1re partie) : parcours de connexion vendeur/console (`auth/…` : 15 modèles + `auth_error`), `account_security`, `auto_retry_mixin` |
| 0.6.0 | (ce commit) | lots d/e + `delta_html_converter` : `greater_abidjan`, `review_config` (cliente = vendeur), `delta_html_converter` (vendeur = console, version du vendeur) |
| 0.7.0 | (ce commit) | `app_lifecycle_service` (crochet `onAppResumed`) et `custom_snackbar` (couleurs par `configure`) pour le vendeur et la console ; la session s'abonne au cycle de vie même s'il est créé après elle |
| 0.8.0 | `432db07` | `brand_colors`, `app_skeleton`, `app_loader` (cliente, console), `support_contact` (support@ebenivoire.com partout), `base_app_config_service`, `platform_terms` + `base_terms_service`, `base_app_review_service` (cliente, vendeur) |
| 0.9.0 | `8db9bde` | `brand_name_loader` : chargement des photos = le nom « EbènIvoire » qui scintille (`BrandNameLoader`, `SkeletonPhoto`, `ShimmerBox`) ; la visionneuse plein écran l'affiche en blanc sur fond noir à la place du rond qui tourne |
| 0.9.1 | `f22d0b8` | visionneuse : le nom s'affiche dès l'ouverture (avant, écran noir jusqu'aux premiers octets reçus) |
| 0.10.0 | `d8b122f` | lot c, 2e partie (1/3) : garde racine `base_app_auth_guard` (vendeur, console) avec crochets ; la garde « mixin » `core/mixins/auth_guard.dart`, jamais utilisée, supprimée des deux apps |
| 0.11.0 | `4ba2995` | lot c, 2e partie (2/3) : `base_app_auth_service` (état de session lu par la garde ; l'ancienne vérification de démarrage, morte et dangereuse — elle effaçait la session en cas de panne —, retirée) et `base_auth_service` (connexion, codes, mots de passe ; journal sans corps ni détail d'erreur). Écran de débogage `/debug/auth`, accessible en production, supprimé des deux apps |
| 0.12.0 | (ce commit) | lot c, 2e partie (3/3, FIN) : `network_image_with_loader` (vendeur, console) et `defaultApiHeaders` ; `ApiConfig` des apps réduit aux 3 membres utilisés (≈150 lignes mortes retirées). `build_sticky_header` LAISSÉ par app (il dépend de 4 éléments de l'app) ; la console a reçu la protection du vendeur contre les titres longs (débordait de 741 px sur un téléphone étroit) |
| 0.12.1 | `bfc4b2c` | correctif : `OtpVerificationError` lit aussi les erreurs À PLAT du serveur (`message`, `error_code` au premier niveau) — seul `detail` était lu, d'où l'anglais « Verification failed » à l'écran ; `userMessage` ne renvoie plus jamais le repli anglais ni un message technique de validation |
| 0.12.2 | (ce commit) | correctif : `DeltaHtmlConverter` réécrit sur un vrai analyseur HTML (paquet `html`), comme l'éditeur riche d'AEECI — le gras d'un mot ne s'étend plus à tout le paragraphe, et l'enregistrement ne fabrique plus de `<h2></h2>` ni de `<li></li>` vides (chaque sauvegarde faisait grossir la description, les CGU et les politiques) ; nouvelle dépendance `html` |
| 0.13.0 | (ce commit) | texte riche sur **flutter_quill**, comme AEECI : `RichTextEditor` (barre complète, image avec largeur en %, séparation, tableau modifiable, liens filtrés, élément inconnu conservé tel quel), `RichHtmlView` (lecteur commun, tableaux via `flutter_html_table`), convertisseur `rich_text_html` et ses tests ; `FlutterQuillLocalizations.delegate` ajouté aux délégués communs (obligatoire pour Quill) ; `html` borné sous 0.15.7 (casse `flutter_html` 3.0.0). Les apps migrent une par une ; `delta_html_converter` et `parchment` partiront en 0.13.1 |
| 0.13.1 | (ce commit) | fin de la migration : `delta_html_converter` (Parchment) et son test retirés, `parchment` n'est plus une dépendance ; les trois apps sont sur `RichTextEditor` / `RichHtmlView` (vendeur `7fc7952`, console `598f18b`, cliente `510f39b`) |
| 0.13.2 | (ce commit) | revue : le HTML nettoyé renvoyé par le serveur (même contenu, écrit autrement) ne recharge plus le document de l'éditeur (curseur et annulation gardés) ; feuilles image et tableau limitées en largeur sur tablette et ordinateur |
| 0.13.3 | (ce commit) | `net.HttpException` porte le corps de l'erreur (`payload`, `field`) et `noAnswer` ; `isNoServerAnswer(e)` sépare « le serveur n'a pas répondu » d'un refus (409, 404…). Un refus affiché « Pas de connexion » trompait (dossier vendeur : numéro de pièce déjà pris) |
| 0.13.4 | (ce commit) | messages d'erreur réseau lisibles : « Pas de connexion… » (`core.error.no_connection`), « Une erreur est survenue » au lieu de « Server error » ; un 503/504 garde le message du serveur ou dit « serveur injoignable », plus de préfixe anglais « Service unavailable: » affiché |
| 0.13.5 | (ce commit) | `userMessageOf(e, fallback:)` (`error_messages.dart`) : le message à montrer pour une erreur — celui du serveur pour un refus, « Pas de connexion » sans réponse, sinon celui de l'écran ; jamais le texte brut de l'exception. `isNoServerAnswer` resserré (délai ou `noAnswer` seulement). ⚠️ Ne plus détecter une coupure par `e.toString().contains('No internet')` : le texte est traduit depuis 0.13.4 |
| 0.13.6 | (ce commit) | `errorTextOf(e)` : le texte d'une erreur quelconque pour un écran (refus / coupure comme `userMessageOf`, `Exception('…')` sans préfixe, `message` d'une erreur typée, jamais le texte d'un bug). Remplace `e.toString().replaceFirst('Exception: ', '')`, qui affichait « HttpException: … (Status: 409) » |
| 0.13.7 | (ce commit) | `RichTextEditor` accepte les menus image, lien et tableau fournis par chaque app : le vendeur peut utiliser ses feuilles du kit sans copier l'éditeur ; les menus Material restent le comportement par défaut des autres apps. Le lien renvoyé par un menu reste filtré par la liste blanche commune. |
| 0.13.8 | (ce commit) | Les sept méthodes JSON de `BaseApiService` déclarent leur vrai résultat `Map<String, dynamic>` (`statusCode`, `body`) : l'analyse Dart repère une lecture erronée comme `response.statusCode`, qui faisait afficher une erreur après un envoi de document réussi. |

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

   ✅ **a et b FAITS (0.4.0, 26/09)** : les trois modèles sont dans le paquet ;
   `NetworkRecoveryService` supprimé (jamais appelé) ; `LoadingService`,
   `SplashService`, `VerifyTokenResponse`, `RefreshTokenRequest/Response`
   supprimés : les écrans de démarrage passent par la session commune.
   Corrigé en chemin : un 502/503 de la passerelle au démarrage (redéploiement)
   effaçait la session (le validateur ne gardait que la coupure réseau) ; la
   console écrivait le jeton et les nouveaux jetons dans le journal ; deux
   renouvellements simultanés au démarrage de la cliente. Démarrage vérifié sur
   téléphone dans les 3 apps (jeton expiré → renouvelé, session gardée).

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

   ✅ **c, 1re partie FAITE (0.5.0, 26/09)** : 15 modèles du parcours de
   connexion, `auth_error` (version console = union : codes admin, code par
   e-mail des super admins, « trop de tentatives »), `account_security`
   (union), `auto_retry_mixin` (version vendeur, la plus stricte). Le vendeur a
   reçu les textes FR/EN qui lui manquaient (`RATE_LIMITED`,
   `SESSION_REVOKED`, `WRONG_CURRENT_PASSWORD` : avant, message générique).
   ⚠️ Pas déplaçables tels quels (ils dépendent du code de l'app — il faudra
   des crochets) : `auth_service`, `app_auth_service`, `auth_guard`,
   `app_auth_guard`, `auth_debug_widget`, `api_config`, `network_image_with_loader`,
   `build_sticky_header`. Laissés par app : `environment` (configuration propre
   à chaque app), `getx_initial_binding` (classe vide). `delta_html_converter` : FAIT en 0.6.0 (version
   du vendeur ; la console perdait la largeur des images dans les CGU).

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

   ✅ **0.8.0 (27/09)** : lots d/e terminés. `support_contact` aligné sur
   support@ebenivoire.com (décision du user). `app_review_service`,
   `app_config_service`, `terms_service` avec crochets ; `app_skeleton`,
   `app_loader` tels quels (même palette). Modèle des CGU unique
   (`PlatformTerms`, version du vendeur : `isUpdate`, dates UTC lues
   correctement ; `CustomerTerms`/`VendorTerms` = alias).
   ⚠️ Trou serveur noté : `POST /api/profile/me/terms/accept` (cliente)
   ignore la version lue — contrairement au vendeur, il peut enregistrer une
   version que le client n'a jamais vue. → CORRIGÉ le 27/09 (serveur
   `afd76d8`, cliente `092c5bc`).

   ✅ **0.9.0 (27/09)** : chargement des photos avec le nom de la marque
   (`brand_name_loader`), idée du user. Règles : le nom est un MOTIF (affiché
   à toute taille, même illisible) ; ⚠️ jamais sous un `AppShimmer` (le reflet
   le repeint en aplat) — dans un squelette, reflet sur les barres
   (`ShimmerBox`) et zone photo en `SkeletonPhoto`. FAIT dans les 3 apps
   (27/09) : cliente `f66af30`+`aef4f5c`, vendeur `6c631eb`, console
   `fe7dbab`, chacune avec un test garde-fou « jamais sous un reflet ».
   ⚠️ Le `placeholder` d'un `CachedNetworkImage` n'hérite PAS de sa taille :
   l'entourer d'un `SizedBox(width, height)` ; pour `Image.network`,
   `frameBuilder` (pas `loadingBuilder`, qui ne part qu'aux premiers octets).

   ✅ **0.7.0 (27/09)** : `lifecycle_service` et `snackbar_config` déplacés avec
   crochets. Corrigé : le cycle de vie n'était jamais créé dans la console, et
   créé APRÈS la session chez le vendeur — dans les deux cas, pas de
   revérification du jeton au retour au premier plan.

   ✅ **d et e examinés (0.6.0, 26/09)** : `greater_abidjan` et `review_config`
   déplacés (seuls les commentaires différaient). Restent par app :
   `support_contact` (adresse de secours différente : support@ebenivoire.com
   côté cliente, support@asameb.com côté vendeur — choix métier, le serveur
   la remplace dès qu'il répond ; seule la cliente lit le délai de réponse),
   `app_review_service`, `app_config_service`, `terms_service`, `app_skeleton`,
   `app_loader` (ils dépendent du thème ou des services de l'app : crochets
   nécessaires).

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
