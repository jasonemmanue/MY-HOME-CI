# MY HOME CI — Inventaire technique : de la Phase 1 (UI mock) au déploiement stores

> Document de travail. État constaté le 11/08/2026 sur la branche `main`.
> Référence fonctionnelle : `CAHIER_DES_CHARGES_MY_HOME_CI.docx` (v1.0 MVP).

---

## 0. État des lieux constaté

### Application mobile (`MY HOME CI`)

| Élément | État réel |
|---|---|
| Écrans | 13 fichiers d'écran, 10 écrans MVP couverts — **UI complète** |
| Modèles | `Property`, `UserModel`, `Message`, `Conversation` — **données mock statiques uniquement** |
| `lib/services/` | **Vide** (0 fichier) |
| `lib/utils/` | **Vide** (0 fichier) |
| State management | **Aucun** — pas de `provider` dans `pubspec.yaml` |
| Dépendances Firebase | **Aucune** |
| Google Maps | **Aucune** — l'écran carte est un dégradé décoratif simulé |
| `google-services.json` / `GoogleService-Info.plist` | **Absents** |
| `firebase_options.dart`, `firebase.json`, `firestore.rules`, `functions/` | **Absents** |
| Images des annonces | **Aucune** — dégradés placeholder dans `property_card.dart` |
| Signature release Android | **Clés debug** (`signingConfig = signingConfigs.getByName("debug")`) |
| Permissions Android | **Aucune déclarée** (ni INTERNET en release, ni localisation, ni caméra) |
| Clés `NSxxxUsageDescription` iOS | **Absentes** |
| Tests | 1 fichier généré (`test/widget_test.dart`) |
| CI/CD | **Aucun** (`.github/workflows` inexistant) |
| Mode sombre | ✅ Implémenté (`AppTheme.darkTheme`) |

### Admin web (`My Home CI Admin`)

| Élément | État réel |
|---|---|
| Stack | Next.js 16 + Tailwind 4 + Recharts — 7 pages |
| Dépendances Firebase | **Aucune** |
| Auth admin | **Aucune** — le login est décoratif |
| Données | **Mock uniquement** |

**Conclusion : 100 % de la logique métier, du backend, de la sécurité et de la conformité stores reste à faire.** L'UI est le seul livrable acquis.

---

## LOT 0 — Fondations Firebase (bloquant pour tout le reste)

- [ ] Créer le projet Firebase `my-home-ci` (+ un projet `-dev` séparé pour ne pas polluer la prod)
- [ ] `flutterfire configure` → génère `lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`
- [ ] Ajouter `google-services.json` / `GoogleService-Info.plist` au `.gitignore` **et** documenter leur récupération (ou les committer si repo privé — à trancher)
- [ ] Ajouter au `pubspec.yaml` :
  ```yaml
  firebase_core, firebase_auth, cloud_firestore, firebase_storage,
  firebase_messaging, firebase_analytics, firebase_crashlytics,
  provider, google_maps_flutter, geolocator, geocoding,
  image_picker, flutter_image_compress, permission_handler,
  shared_preferences, share_plus, url_launcher, flutter_local_notifications,
  google_sign_in, sign_in_with_apple, photo_view, uuid
  ```
- [ ] Appliquer le plugin Google Services dans `android/settings.gradle.kts` + `android/app/build.gradle.kts`
- [ ] Initialiser Firebase dans `main.dart` (`await Firebase.initializeApp`)
- [ ] Activer la persistance Firestore offline (exigence CDC « mode hors connexion »)
- [ ] Choisir la région Firestore (**`europe-west1`** recommandé — meilleure latence CI qu'`us-central1`)
- [ ] Passer au plan **Blaze** (obligatoire pour Cloud Functions et Storage au-delà du quota)

---

## LOT 1 — Modèle de données & schéma Firestore

### Corrections indispensables des modèles existants

- [ ] `Property` : **ajouter `latitude` / `longitude`** — absents aujourd'hui, la carte est impossible sans eux
- [ ] `Property` : remplacer `isActive: bool` par `status: enum` → `draft | pending | active | rented | archived | rejected` (le CDC exige 4 statuts + validation admin)
- [ ] `Property` : ajouter `updatedAt`, `boostedUntil`, `favoritesCount`, `messagesCount`, `searchKeywords[]`
- [ ] Tous les modèles : ajouter `fromFirestore()` / `toFirestore()` — **aucun n'en a**
- [ ] Supprimer les `static mockXxx` des modèles une fois la migration faite (ou les déplacer dans `test/fixtures/`)
- [ ] `UserModel` : ajouter `role`, `fcmTokens[]`, `verificationStatus`, `suspendedUntil`, `lastSeenAt`
- [ ] `Conversation` : ajouter `participants[]` (pour les règles de sécurité), `lastMessageSenderId`, `unreadCount` **par utilisateur** (map, pas int global)
- [ ] `Message` : ajouter `type` (text/image), `imageUrl`, `readAt`, `senderId`

### Collections Firestore à créer

```
users/{uid}
  └── favorites/{propertyId}
  └── alerts/{alertId}
  └── notifications/{notifId}
properties/{propertyId}
  └── views/{viewId}          (ou compteur agrégé)
conversations/{convId}
  └── messages/{messageId}
reports/{reportId}            (signalements — UC-L13)
quarters/{quarterId}          (infos quartier — écran 6)
adminSettings/global
verificationRequests/{uid}    (badge vérifié — UC-P10)
```

- [ ] Définir et documenter les index composites (ex. `status + quarter + price`, `status + createdAt`, `participants + lastMessageTime`)
- [ ] Script de seed pour peupler la base de dev avec des annonces réalistes

---

## LOT 2 — Authentification

L'écran `auth_screen.dart` (644 lignes) est intégralement décoratif.

- [ ] `AuthService` : inscription email/mot de passe, connexion, déconnexion, mot de passe oublié
- [ ] **OTP SMS** (Firebase Phone Auth) — exigé par le CDC §4.2 ; nécessite d'activer Phone Auth + configurer reCAPTCHA Android et APNs iOS
- [ ] **Google Sign-In** (SHA-1/SHA-256 debug + release à enregistrer dans Firebase)
- [ ] **Sign in with Apple** — ⚠️ **obligatoire sur iOS dès lors que Google Sign-In est proposé** (App Store Guideline 4.8). Sinon rejet garanti.
- [ ] **Mode invité** : navigation sans compte + garde d'accès sur chat / favoris / alertes (le CDC insiste : bannière « Parcourir en tant que visiteur »)
- [ ] Différenciation de rôle locataire / propriétaire à l'inscription + création du document `users/{uid}`
- [ ] Vérification d'email
- [ ] Flux de vérification d'identité propriétaire (upload pièce → `verificationRequests` → validation admin → badge)
- [ ] Persistance de session + `AuthGate` (redirection splash → onboarding → auth → home selon l'état)
- [ ] Rate-limiting anti-brute-force (App Check + Cloud Function de comptage)
- [ ] Activer **Firebase App Check** (Play Integrity / DeviceCheck) — protège Firestore et Storage de l'abus

---

## LOT 3 — Annonces : publication, gestion, photos

- [ ] `PropertyService` : CRUD complet (create, update, archive, delete, markAsRented)
- [ ] Brancher le formulaire 6 étapes de `publish_property_screen.dart` (905 lignes d'UI) sur Firestore
- [ ] **Sauvegarde en brouillon** (exigence CDC §4.9) — persistance locale + Firestore
- [ ] Mode **édition** d'une annonce existante (le formulaire ne gère aujourd'hui que la création)
- [ ] `StorageService` : upload multi-photos avec compression (< 300 Ko/photo — contrainte réseau 3G du CDC), génération de miniatures, suppression en cascade
- [ ] `image_picker` + permissions caméra/galerie + gestion du refus de permission
- [ ] Réordonnancement des photos, choix de la photo de couverture
- [ ] Sélection de la position sur carte à l'étape 2 (aujourd'hui : placeholder ligne 291)
- [ ] Validation serveur des champs (Cloud Function ou règles Firestore)
- [ ] Quota **3 annonces gratuites/mois** (compteur mensuel côté serveur) — si la monétisation est incluse au lancement
- [ ] Compteur de vues (incrément déduplicé, pas un `+1` naïf sur chaque build)

---

## LOT 4 — Carte interactive & géolocalisation

L'écran carte est actuellement un **dégradé de couleurs**, pas une carte.

- [ ] Créer un projet Google Cloud + activer **Maps SDK Android**, **Maps SDK iOS**, **Places API**, **Geocoding API**
- [ ] Restreindre les clés API par package name + SHA-1 (Android) et bundle ID (iOS) — sinon facture imprévisible
- [ ] Injecter les clés via `--dart-define` / fichiers de config non versionnés
- [ ] Remplacer `map_screen.dart` par un vrai `GoogleMap` avec marqueurs personnalisés
- [ ] **Clustering** de marqueurs (exigence CDC §4.4)
- [ ] Géolocalisation utilisateur temps réel + bouton de recentrage + gestion « permission refusée »
- [ ] Filtre de distance fonctionnel (500 m / 1 / 3 / 5 / 10 km) → requête géospatiale (geohash, `geoflutterfire_plus` ou équivalent — Firestore ne fait pas de requête radiale nativement)
- [ ] Preview card cliquable depuis un marqueur → fiche détail
- [ ] Mini-carte dans la fiche détail (écran 6)
- [ ] Style de carte cohérent avec la charte (Map ID / JSON style, mode clair + sombre)

---

## LOT 5 — Recherche, filtres, tri, pagination

- [ ] Recherche texte avec auto-complétion — ⚠️ Firestore ne fait pas de recherche plein texte : prévoir soit un champ `searchKeywords[]` + `array-contains`, soit **Algolia/Typesense** (coût à arbitrer)
- [ ] Filtres avancés persistants : type, fourchette de loyer, pièces, meublé, quartier
- [ ] Tri : prix ↑/↓, plus récent, plus proche (le tri « plus proche » ligne 44 est aujourd'hui un no-op)
- [ ] **Pagination infinie** (`startAfterDocument` + `limit`) — exigence CDC §4.5
- [ ] États vides / chargement / erreur / retry sur tous les écrans de liste
- [ ] Section « Près de vous » réellement géolocalisée sur l'accueil
- [ ] Filtre par quartier depuis « Quartiers populaires » (TODO ligne 276 de `home_tab.dart`)

---

## LOT 6 — Messagerie temps réel

- [ ] `ChatService` : création/récupération de conversation à partir d'un couple (annonce, locataire)
- [ ] Streams Firestore temps réel pour conversations et messages
- [ ] Envoi de **photos** dans le chat (Storage + message typé)
- [ ] Accusés de lecture (vu / non vu) et indicateur « en train d'écrire… » (exigence CDC §4.7)
- [ ] Compteur de non-lus par utilisateur + badge sur la bottom bar
- [ ] Pagination de l'historique (ne pas charger 5 000 messages)
- [ ] Blocage / signalement d'un utilisateur
- [ ] Modération : les conversations doivent être lisibles par l'admin (impact direct sur les règles Firestore)

---

## LOT 7 — Favoris, alertes, signalements, partage

- [ ] Favoris persistés (`users/{uid}/favorites`) + synchronisation multi-appareils
- [ ] Favoris en mode invité (local, puis migration à l'inscription)
- [ ] Alertes de recherche : sauvegarde des critères + Cloud Function de matching sur nouvelle annonce
- [ ] Signalement d'annonce (UC-L13) → collection `reports` → dashboard admin
- [ ] Partage réseaux sociaux (UC-L08) via `share_plus` + **Firebase Dynamic Links ou App Links/Universal Links** ⚠️ Dynamic Links est déprécié (arrêt annoncé) → partir directement sur App Links / Universal Links
- [ ] Comparateur d'annonces côte à côte (UC-L12)

---

## LOT 8 — Notifications push (FCM)

- [ ] Intégration `firebase_messaging` + `flutter_local_notifications` (foreground)
- [ ] Enregistrement / rotation / nettoyage des tokens FCM par utilisateur
- [ ] **APNs** : clé d'authentification Apple + configuration dans Firebase (indispensable pour iOS)
- [ ] Permission notifications (Android 13+ `POST_NOTIFICATIONS`, iOS)
- [ ] Cloud Functions déclencheuses : nouveau message, nouvelle annonce correspondant à une alerte, annonce validée/rejetée, message admin global
- [ ] Deep-linking depuis la notification vers le bon écran
- [ ] Écran de préférences de notifications (écran 10) réellement branché

---

## LOT 9 — Profil & paramètres

- [ ] Chargement du profil réel (aujourd'hui : `UserModel.mockCurrentUser`)
- [ ] Édition du profil + upload de la photo
- [ ] Persistance du choix de thème clair/sombre/système
- [ ] Pages CGU et Politique de confidentialité (contenu à rédiger — voir LOT 15)
- [ ] Déconnexion fonctionnelle
- [ ] **Suppression de compte en 1 clic dans l'app** — ⚠️ **obligatoire Apple (5.1.1(v)) et Google Play**. Doit supprimer/anonymiser réellement les données (Cloud Function en cascade : annonces, messages, photos Storage, favoris)

---

## LOT 10 — Sécurité backend

- [ ] **`firestore.rules`** : lecture publique des annonces `active` uniquement ; écriture d'une annonce réservée à son propriétaire ; messages lisibles seulement par les participants ; rôle admin via custom claim
- [ ] **`storage.rules`** : upload limité au propriétaire, taille max, types MIME autorisés
- [ ] **Tests des règles** (`@firebase/rules-unit-testing`) — non négociable, une règle non testée est une fuite de données
- [ ] Custom claims admin (Cloud Function d'attribution)
- [ ] Cloud Functions : modération (filtrage automatique), compteurs agrégés, purge, matching d'alertes, suppression de compte
- [ ] App Check activé et **enforced** sur Firestore + Storage
- [ ] Aucune clé API en dur dans le dépôt

---

## LOT 11 — Dashboard admin (Next.js) → Firebase

- [ ] Ajouter `firebase` + `firebase-admin` au projet admin
- [ ] Authentification admin réelle + vérification du custom claim (le login actuel est décoratif)
- [ ] Brancher les 7 pages sur Firestore : dashboard, annonces, utilisateurs, conversations, signalements, paramètres
- [ ] Actions de modération : valider / rejeter / mettre en avant / supprimer une annonce
- [ ] Vérifier / suspendre / supprimer un utilisateur, attribuer le badge vérifié
- [ ] Envoi de notifications push globales (UC-A06)
- [ ] Analytics réels (Firebase Analytics / BigQuery export)
- [ ] Déploiement : Firebase Hosting ou Vercel + domaine + restriction d'accès

---

## LOT 12 — Performance, offline, robustesse

- [ ] Persistance offline Firestore + cache d'images (`cached_network_image` est déjà présent mais inutilisé)
- [ ] Objectif CDC : **< 2 s de chargement** sur 3G → mesurer, compresser les images, lazy-load
- [ ] Gestion de la perte de connexion (bannière, retry)
- [ ] **Firebase Crashlytics** + `FlutterError.onError`
- [ ] Firebase Analytics : événements clés (recherche, vue annonce, contact propriétaire, publication)
- [ ] Firebase Performance Monitoring
- [ ] Support **tablette** (le CDC l'exige explicitement) — vérifier tous les layouts en 600 dp+ et en paysage
- [ ] Accessibilité : contrastes, tailles de police dynamiques, labels sémantiques

---

## LOT 13 — Conformité Android / Google Play

- [ ] `AndroidManifest.xml` : `android:label` → **« My Home CI »** (actuellement `my_home_ci`)
- [ ] Déclarer les permissions : `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`
- [ ] Clé Google Maps dans le manifest
- [ ] **Keystore de release** + `key.properties` (hors dépôt) + `signingConfig` release (aujourd'hui : **clés debug — build non publiable**)
- [ ] Retirer les `// TODO` générés dans `build.gradle.kts`
- [ ] `minSdk` explicite (21+ pour Firebase, 23 recommandé), `targetSdk` conforme à l'exigence Play en vigueur
- [ ] ProGuard / R8 + règles de conservation Firebase
- [ ] Build **App Bundle (.aab)** signé
- [ ] Compte Google Play Developer (**25 $ unique**) + **vérification d'identité obligatoire** (délai possible de plusieurs jours à prévoir)
- [ ] Fiche Play Store : titre, description courte/longue, icône 512×512, feature graphic 1024×500, 2 à 8 captures téléphone + tablette
- [ ] Formulaire **Data Safety** (collecte de localisation, photos, messages, identifiants → à déclarer honnêtement)
- [ ] Déclarations : contenu, public cible 18+, publicité, politique de confidentialité (URL publique obligatoire)
- [ ] Test interne → fermé → ouvert avant production

## LOT 14 — Conformité iOS / App Store

- [ ] ⚠️ **Un Mac est indispensable** pour builder, signer et soumettre (ou un service CI macOS type Codemagic)
- [ ] Compte Apple Developer (**99 $/an**)
- [ ] Bundle ID, certificats, profils de provisioning
- [ ] `Info.plist` : `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` (**toutes absentes — crash garanti au premier accès**)
- [ ] `CFBundleDisplayName` → « My Home CI » (actuellement « My Home Ci »), `CFBundleName` cohérent
- [ ] Capability Push Notifications + APNs
- [ ] **Sign in with Apple** (cf. LOT 2)
- [ ] **Suppression de compte in-app** (cf. LOT 9)
- [ ] Privacy Nutrition Labels + `PrivacyInfo.xcprivacy` (manifeste de confidentialité, exigé pour l'app et ses SDK tiers)
- [ ] Icônes toutes tailles, captures iPhone 6.7"/6.5" + iPad
- [ ] Compte de test fourni au review Apple (sinon rejet automatique)
- [ ] TestFlight avant soumission

---

## LOT 15 — Juridique & légal

- [ ] **Politique de confidentialité** hébergée sur une URL publique (obligatoire Play + Apple)
- [ ] **CGU / CGV** avec clause de non-responsabilité sur les annonces (la plateforme n'est pas agent immobilier)
- [ ] Mentions légales, contact support
- [ ] Conformité protection des données (CDC §5.2) — l'ARTCI encadre les données personnelles en Côte d'Ivoire ; déclaration à vérifier avec un juriste local
- [ ] Consentement explicite à la géolocalisation
- [ ] Mécanisme de signalement de contenu (déjà prévu — LOT 7)
- [ ] Conditions de modération et de suspension de compte

---

## LOT 16 — Tests, QA & CI/CD

- [ ] Tests unitaires : modèles (sérialisation), services (avec `fake_cloud_firestore`)
- [ ] Tests des règles Firestore (LOT 10)
- [ ] Tests de widgets sur les écrans critiques
- [ ] Tests d'intégration du parcours principal : recherche → détail → contact → chat
- [ ] Le `test/widget_test.dart` généré est probablement cassé → à corriger ou supprimer
- [ ] GitHub Actions : `flutter analyze`, `flutter test`, build APK/AAB, éventuellement build iOS sur runner macOS
- [ ] Distribution des builds de test (Firebase App Distribution)
- [ ] Recette fonctionnelle sur appareils réels bas de gamme + réseau 3G bridé (cible marché ivoirien)

---

## LOT 17 — Lancement

- [ ] Environnements dev / prod séparés (projets Firebase + flavors Flutter)
- [ ] Versioning et changelog
- [ ] Seed des premières annonces réelles (une marketplace vide ne convertit pas)
- [ ] Beta fermée (CDC : 2 semaines)
- [ ] Monitoring post-lancement : Crashlytics, alertes de quota Firebase, budget Google Maps
- [ ] Plan de support utilisateur

---

## Décisions à trancher avant de démarrer

1. **Recherche texte** : `array-contains` sur mots-clés (gratuit, limité) ou Algolia/Typesense (puissant, coût récurrent) ?
2. **Monétisation au lancement** : le CDC exclut Pack Pro et AdMob du MVP — confirme-t-on que le lancement est 100 % gratuit sans publicité ? (Cela simplifie fortement la conformité stores.)
3. **iOS** : accès à un Mac, ou budget pour un CI macOS ?
4. **Modération** : validation manuelle de chaque annonce avant publication, ou publication immédiate + modération a posteriori ? (Impacte les règles Firestore et le workflow admin.)
5. **Vérification propriétaire** : quelles pièces, quel process, qui les traite ?
6. **Fichiers de config Firebase** : versionnés (repo privé) ou distribués hors dépôt ?

---

## Ordre d'exécution recommandé

```
LOT 0 → LOT 1 → LOT 2 → LOT 3 → LOT 5 → LOT 6 → LOT 4 → LOT 7
      → LOT 8 → LOT 9 → LOT 10 → LOT 12 → LOT 11
      → LOT 13/14 → LOT 15 → LOT 16 → LOT 17
```

Les LOTs 13, 14 et 15 (conformité et légal) ont des **délais administratifs incompressibles**
(vérification d'identité Google Play, compte Apple, rédaction juridique) : les lancer **en parallèle**
dès le début du LOT 3, pas à la fin.
