# MY HOME CI — Reste à faire avant publication sur les stores

> Document de travail. **État constaté le 15/08/2026** sur la branche `ios`
> (identique à `main`). Remplace l'inventaire du 11/08/2026, entièrement obsolète.
> Référence fonctionnelle : `CAHIER_DES_CHARGES_MY_HOME_CI.docx` (v1.0 MVP).

---

## 0. État des lieux constaté

### Application mobile (`MY HOME CI`)

| Élément | État réel |
|---|---|
| Écrans | 20 écrans — UI **et** logique branchées |
| Modèles | 8 modèles avec `fromFirestore()` / `toFirestore()` |
| `lib/services/` | **13 services** réellement connectés à Firebase |
| `lib/providers/` | 4 providers (auth, favoris, annonces, réglages) |
| `lib/utils/` | `geohash.dart` — recherche par rayon |
| State management | Provider, câblé dans `app.dart` |
| Firebase | Core, Auth, Firestore, Storage, Messaging, Analytics, Crashlytics, App Check, Functions |
| Google Maps | `GoogleMap` réel + géolocalisation + filtre de distance par geohash |
| Fichiers de config Firebase | Présents et versionnés (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) |
| Persistance offline | Activée (cache 100 Mo) |
| Signature release Android | Lue depuis `android/key.properties` — **fichier absent en local** |
| Permissions Android | Complètes (internet, localisation, caméra, médias, notifications) |
| Clés `NSxxxUsageDescription` iOS | **Toutes présentes et rédigées** |
| Tests | 1 fichier de tests unitaires (geohash, mots-clés, règles de publication) |
| CI/CD | **Codemagic** — 4 workflows (build check, simulateur, TestFlight, AAB Android) |
| Mode sombre | Implémenté |
| Données mock | **Aucune** |

### Backend Firebase (`functions/` + règles)

| Élément | État réel |
|---|---|
| Cloud Functions | 11 fonctions v2 (paiements, déclencheurs, administration) |
| `firestore.rules` | 13 collections couvertes, rôle admin par custom claim |
| `storage.rules` | 4 espaces, limite 5 Mo, types MIME contrôlés |
| Index composites | 17, déclarés dans `firestore.indexes.json` |
| Paiements | GeniusPay — Wave, Orange Money, MTN, Moov + lien de paiement web (parcours iOS) |
| Émulateurs | Configurés (auth, functions, firestore, storage) |

### Back-office web (`My Home CI Admin`)

| Élément | État réel |
|---|---|
| Stack | Next.js 16 + React 19 + Tailwind 4 + Recharts |
| Firebase | **Connecté** — watchers temps réel + actions de modération |
| Auth admin | Réelle, custom claim `admin` vérifié |
| Données mock | **Aucune** |
| Déploiement | **Aucun** |

**Conclusion : la construction est faite. Ce qui reste est de la mise en service —
clés, signature, déploiement, tests de sécurité et démarches administratives.**

---

## A. Bloquants — rien ne peut être publié sans ça

- [ ] **`android/key.properties` + keystore de release.** En son absence, le build
      release retombe sur la clé de débogage : Google Play refuse l'AAB.
      Le keystore doit aussi être uploadé dans Codemagic sous le nom
      `my_home_ci_keystore` (référencé par `codemagic.yaml`).
- [ ] **Google Sign-In iOS.** `GoogleService-Info.plist` ne contient pas de
      `REVERSED_CLIENT_ID` : le fournisseur Google n'est pas activé dans la
      console Firebase, ou le plist n'a pas été retéléchargé après activation.
      Le schéma d'URL correspondant manque donc dans `Info.plist` (voir le
      commentaire « À COMPLÉTER »). Sans lui, la connexion Google ouvre Safari
      et n'en revient jamais.
      ⚠️ **Sign in with Apple est obligatoire dès que Google Sign-In est proposé**
      (guideline App Store 4.8) — l'implémentation existe, la capability doit
      être activée sur l'App ID.
- [ ] **Clés Google Maps.** Ni `MAPS_API_KEY` dans `android/local.properties`,
      ni `ios/Flutter/Keys.xcconfig`. Symptôme : carte grise, sans message
      d'erreur. Restreindre les clés par package name + SHA-1 (Android) et
      bundle ID (iOS), sinon la facture est imprévisible.
- [ ] **Secrets Cloud Functions.** 3 secrets GeniusPay
      (`GENIUSPAY_API_KEY`, `GENIUSPAY_SECRET_KEY`, `GENIUSPAY_WEBHOOK_SECRET`)
      et 2 secrets Gmail (`GMAIL_SENDER_EMAIL`, `GMAIL_APP_PASSWORD`) à
      renseigner avant déploiement. Créer le `functions/.env.example` que le
      `.gitignore` prévoit déjà mais qui n'existe pas.
- [ ] **Déploiement du backend** : `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`.
- [ ] **Déploiement du back-office** sur `admin.myhomeci.ci` — c'est l'URL
      codée en dur dans `WEB_PAY_BASE_URL` (`functions/index.js`). Sans elle,
      les liens de paiement envoyés par email ne mènent nulle part.
- [ ] **Premier administrateur** : appeler `bootstrapFirstAdmin` une fois, puis
      vérifier que la fonction se verrouille (elle ne doit pas pouvoir servir
      deux fois).
- [ ] Passage du projet Firebase au **plan Blaze** (obligatoire pour les Functions).

---

## B. Sécurité — à faire avant d'ouvrir la base à de vrais utilisateurs

- [ ] **Tests des règles Firestore** (`@firebase/rules-unit-testing`) —
      aujourd'hui **inexistants**. C'est le trou le plus risqué du projet :
      une règle non testée est une fuite de données. Couvrir au minimum :
      lecture d'une annonce `draft` par un tiers, écriture sur `properties`
      d'un autre propriétaire, lecture d'une conversation dont on n'est pas
      participant, écriture directe du champ `role` par un utilisateur.
- [ ] Tests des `storage.rules` (upload dans le dossier d'un autre utilisateur).
- [ ] **App Check en mode enforced** sur Firestore, Storage et Functions.
      L'activation est déjà codée côté app (`main.dart`), il reste à enregistrer
      les empreintes Play Integrity / DeviceCheck et à basculer l'enforcement.
- [ ] Vérifier qu'aucune clé n'est en dur dans les deux dépôts.
- [ ] Rejouer manuellement le webhook GeniusPay avec une signature invalide et
      avec une signature rejouée (protection anti-replay).

---

## C. Fonctionnel — écarts restants avec le cahier des charges

- [ ] **Clustering des marqueurs sur la carte** (CDC §4.4) — seul écart
      fonctionnel constaté. Au-delà de quelques dizaines d'annonces, la carte
      d'Abidjan devient illisible.
- [ ] Envoi de **notifications push globales depuis le back-office** (UC-A06).
- [ ] `assetlinks.json` (Android) et `apple-app-site-association` (iOS) à publier
      sur `myhomeci.ci` : sans eux, les App Links / Universal Links déclarés dans
      le manifeste ne s'ouvrent pas automatiquement dans l'application.
- [ ] Remplacer `AppConstants.placeholderImage`
      (`https://via.placeholder.com/…`, service externe régulièrement hors
      service) par un asset local.
- [ ] Seed des premiers quartiers (`quarters/`) et de quelques annonces réelles :
      une marketplace vide ne convertit pas.

Pour mémoire, sont **déjà en place** et n'ont pas besoin d'être refaits :
pagination `startAfter`, brouillons, comparateur d'annonces, partage,
indicateur de frappe, compteurs de non-lus, blocage et signalement,
suppression de compte in-app, alertes de recherche, compression d'images,
mode invité.

---

## D. Qualité, tests et CI

- [ ] Étendre `test/` : sérialisation des 8 modèles, services avec
      `fake_cloud_firestore` et `firebase_auth_mocks` (déjà dans le `pubspec`,
      pas encore utilisés).
- [ ] Test d'intégration du parcours principal : recherche → détail → contact → chat.
- [ ] Aucune CI sur le back-office (`.github/workflows` absent des deux dépôts) —
      au minimum `npm run lint` + `npm run build` sur push.
- [ ] Recette sur appareil réel bas de gamme, réseau 3G bridé (cible ivoirienne).
      Objectif CDC : **< 2 s de chargement**.
- [ ] Vérifier les mises en page en 600 dp+ et en paysage (tablette exigée par le CDC).
- [ ] Firebase App Distribution pour les testeurs internes.

---

## E. Conformité stores

### Google Play
- [ ] Compte Google Play Developer (**25 $ une fois**) + **vérification d'identité**
      — délai administratif de plusieurs jours, à lancer **maintenant**.
- [ ] Fiche : titre, descriptions, icône 512×512, feature graphic 1024×500,
      2 à 8 captures téléphone **et** tablette.
- [ ] Formulaire **Data Safety** : localisation, photos, messages, identifiants.
- [ ] Déclarations : contenu, public cible, publicité, URL publique de politique
      de confidentialité.
- [ ] Piste de test interne → fermée → ouverte avant production.

### App Store
- [ ] Compte Apple Developer (**99 $/an**).
- [ ] Dans App Store Connect : créer l'App ID `com.myhomeci.app` avec les
      capabilities **Push Notifications, Sign in with Apple, Associated Domains**
      — `codemagic.yaml` échoue à la signature sans elles.
- [ ] Clé API App Store Connect nommée exactement **« My Home CI ASC »** dans Codemagic.
- [ ] Variables Codemagic (groupe `myhomeci`) : `MAPS_API_KEY_IOS`,
      `MAPS_API_KEY_ANDROID`, `APP_STORE_APPLE_ID`.
- [ ] Clé d'authentification **APNs** déposée dans Firebase (sinon aucune push iOS).
- [ ] Privacy Nutrition Labels + `PrivacyInfo.xcprivacy`.
- [ ] Icônes toutes tailles, captures iPhone 6.7"/6.5" + iPad.
- [ ] **Compte de test fourni au review Apple** — son absence est un rejet automatique.
- [ ] TestFlight avant soumission (tag `v1.0.0` → workflow `ios-testflight`).
- [ ] ⚠️ Vérifier que le parcours de paiement web `/pay/[token]` est bien décrit
      au reviewer : un paiement de service numérique hors achat in-app est le
      point le plus sensible de la soumission (guideline 3.1.1). L'argumentaire
      doit être prêt.

---

## F. Juridique

- [ ] **Politique de confidentialité** et **CGU** hébergées sur une URL publique
      (obligatoire Play et Apple). Le contenu existe dans l'application
      (`legal_screen.dart`) — il doit aussi être accessible sur le web.
- [ ] Clause de non-responsabilité sur les annonces : la plateforme n'est pas
      agent immobilier.
- [ ] Mentions légales, contact support.
- [ ] Protection des données (CDC §5.2) — l'ARTCI encadre les données
      personnelles en Côte d'Ivoire : déclaration à valider avec un juriste local.
- [ ] Conditions générales de vente des deux produits payants (Pack Pro, boost)
      et politique de remboursement.

---

## G. Exploitation

- [ ] Séparer un projet Firebase **dev** du projet de production (aujourd'hui un
      seul : `my-home-ci`).
- [ ] Alertes de budget Firebase et Google Maps (voir le document de budget).
- [ ] Monitoring post-lancement : Crashlytics, quotas Firestore, coût des SMS OTP.
- [ ] Plan de support utilisateur.
- [ ] Versioning et changelog.

---

## Ordre d'exécution recommandé

```
A (bloquants)  →  B (sécurité)  →  D (tests)  →  C (écarts fonctionnels)
                                                 →  E/F (stores et juridique)  →  G
```

**E et F ont des délais administratifs incompressibles** (vérification
d'identité Google Play, création du compte Apple, rédaction juridique) :
les lancer **en parallèle du bloc A**, pas à la fin.

---

## Décisions déjà tranchées

| Question | Décision constatée dans le code |
|---|---|
| Recherche texte | `searchKeywords[]` + `array-contains` (pas d'Algolia) |
| Monétisation au lancement | **Incluse** — Pack Pro 15 000 FCFA/30 j, boost 5 000 FCFA/7 j, Mobile Money via GeniusPay. Pas de publicité |
| Paiement sur iOS | Page web externe `/pay/[token]`, lien à usage unique valable 24 h |
| iOS sans Mac | Codemagic (`mac_mini_m2`) |
| Config Firebase | Versionnée dans le dépôt |
| Modération | Publication après validation admin (`pending` → `active`) |
| Région Functions | `us-central1` |

## Décisions restant à trancher

1. **Projet Firebase de développement séparé** — oui ou non ? (impacte le coût
   et le risque de polluer la base de production)
2. **Vérification propriétaire** : quelles pièces exactement, qui les traite,
   sous quel délai ?
3. **SMS OTP** : le coût par SMS en Côte d'Ivoire est le principal poste
   variable. Le maintient-on comme méthode d'inscription principale, ou
   bascule-t-on l'inscription par défaut sur email + Google ?
