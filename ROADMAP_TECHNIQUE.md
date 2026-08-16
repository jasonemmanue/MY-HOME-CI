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
| Conteneurisation | `Dockerfile` multi-étapes validé — image 303 Mo, sain sous `docker run` |
| Déploiement | **Aucun hébergement** — l'image existe, le domaine non |

**Conclusion : la construction est faite. Ce qui reste est de la mise en service —
clés, signature, déploiement, tests de sécurité et démarches administratives.**

---

## A. Bloquants — rien ne peut être publié sans ça

> **Point du 16/08/2026** — recette sur appareil réel (Samsung SM A256E,
> Android 16) et back-office exécuté en conteneur Docker. Quatre défauts
> corrigés, le backend est passé en service. Détail au bas du document.

- [x] ~~**Déploiement du backend**~~ — `firestore.rules`, `storage.rules`, les
      **18** index composites et les **11** Cloud Functions sont déployés sur
      `my-home-ci`. Les cinq secrets (3 GeniusPay, 2 Gmail) sont dans Secret
      Manager. `functions/.env.example` documente désormais la répartition
      entre `.env`, Secret Manager et `.secret.local`.
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
- [x] ~~**Secrets Cloud Functions.**~~ Les cinq sont posés dans Secret Manager.
      ⚠️ Ils ne doivent **jamais** figurer aussi dans `functions/.env` : Cloud
      Run rejette alors le déploiement (« Secret environment variable overlaps
      non secret environment variable »). Voir `functions/.env.example`.
- [ ] **Déploiement du back-office** sur `admin.myhomeci.ci` — c'est l'URL
      codée en dur dans `WEB_PAY_BASE_URL` (`functions/index.js`). Sans elle,
      les liens de paiement envoyés par email ne mènent nulle part.
- [x] ~~**Premier administrateur**~~ — créé le 16/08/2026 :
      `admin@myhomeci.ci`, uid `PJJDC5IvIzZdwHxLQ2H9a6qnE1I2`, custom claim
      `admin` vérifié sur un jeton réémis après l'appel.
      ⚠️ **Reste à vérifier** : que `bootstrapFirstAdmin` refuse bien un second
      appel. Le code la verrouille (elle cherche un admin existant et lève
      `permission-denied`), mais l'exécution n'a pas pu être rejouée.
      À confirmer, puis retirer la fonction du déploiement — elle n'a plus
      d'usage, et une porte d'amorçage qui reste ouverte est une porte.
- [x] ~~Passage du projet Firebase au **plan Blaze**~~ — effectif, les 11
      fonctions v2 sont en service.
- [ ] **Seed des données** : la base est vide. L'accueil affiche « Aucune
      annonce publiée » et la rangée « Quartiers populaires » retombe sur la
      liste statique de `AppConstants`. Peupler `quarters/` puis quelques
      annonces réelles.

---

## B. Sécurité — à faire avant d'ouvrir la base à de vrais utilisateurs

- [x] ~~**Tests des règles Firestore**~~ — `firestore-tests/`, **63 tests** au
      vert contre l'émulateur (`npm test`). Couvrent la consultation sans
      compte, l'étanchéité des annonces non publiées, l'écriture sur les
      annonces d'autrui, l'escalade de privilèges sur les cinq champs protégés,
      les coordonnées privées, les conversations, l'argent, la modération, les
      notifications et le refus par défaut.
      **Une faille a été trouvée et fermée au passage** : la règle sur les
      compteurs restreignait les *champs* modifiables sans contraindre leur
      *valeur*. N'importe quel visiteur pouvait remettre à zéro les vues d'un
      concurrent ou s'attribuer un million de vues et de favoris — le tri par
      popularité s'en serait trouvé faussé. Les incréments sont désormais
      limités à ±1, un champ à la fois, et `favoritesCount` ne peut plus passer
      sous zéro.
- [ ] Tests des `storage.rules` (upload dans le dossier d'un autre utilisateur).
      Le banc `firestore-tests/` accueille ce cas sans modification :
      `initializeTestEnvironment` accepte une clé `storage` à côté de
      `firestore`.
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

> Tout ce que ce bloc réclame en images, textes, documents juridiques et accès
> est spécifié lot par lot, avec les formats exacts, dans
> **`DOSSIER_FOURNITURE_MY_HOME_CI.docx`** (généré par
> `node generate_prestataires_docx.js`). C'est le document à transmettre aux
> prestataires.

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

## Recette du 16/08/2026 — défauts trouvés et corrigés

Compilation Android sur appareil réel (SM A256E, Android 16, arm64) et
back-office exécuté en conteneur Docker (`myhomeci-admin:local`, Node 22
Alpine, sortie `standalone`, 303 Mo, utilisateur non privilégié).

| # | Défaut | Cause | Correctif |
|---|---|---|---|
| 1 | L'application **plantait au lancement**, écran blanc puis fermeture | `namespace` renommé en `com.myhomeci.app` sans déplacer `MainActivity.kt`, resté en `com.myhomeci.my_home_ci`. Le manifeste résout `.MainActivity` contre le namespace → `ClassNotFoundException`. Le build, lui, réussissait | Fichier déplacé dans `com/myhomeci/app/`, ancien paquet supprimé |
| 2 | `PERMISSION_DENIED` sur `properties` et `quarters` — aucune annonce visible | Les règles du dépôt n'avaient jamais été déployées | `firebase deploy --only firestore:rules,storage` |
| 3 | `FAILED_PRECONDITION` sur `quarters` — repli permanent sur la liste statique | Index composite `(isPopular, sortOrder)` absent de `firestore.indexes.json` | Index ajouté puis déployé (18 au total) |
| 4 | Débordement de 4,9 px sur la barre de filtres ; « Creer un compte » tronqué en « Creer un comp » | Deux boutons à largeur intrinsèque + `Spacer` en 360 dp ; retrait de 16 dp par défaut des `Tab` | Barre rendue défilante horizontalement ; `labelPadding` ramené à 8 dp |
| 5 | `npm run lint` en échec (3 erreurs `react-hooks/set-state-in-effect`) | `setState` synchrones en corps d'effet dans `annonces` et `conversations` | États dérivés. Corrige au passage une course : une réponse lente écrasait les messages de la conversation entre-temps sélectionnée |

Vérifié après correction : 29 tests unitaires au vert, `flutter analyze` sans
erreur ni avertissement, `tsc --noEmit` et `npm run lint` propres, les cinq
onglets parcourus sans exception, `getWebPaymentStatus` répond
`{"success":false,"error":"Lien invalide"}` sur un jeton inconnu.

**Non corrigé, faute de clé** : `MAPS_API_KEY` absente de
`android/local.properties` — l'onglet Carte s'affiche vide, seul le logo Google
apparaît. Toute la logique (rayon, géolocalisation, compteur) fonctionne.

### Seconde passe, même jour — sécurité et mise en service

| Travail | Résultat |
|---|---|
| Premier administrateur | `admin@myhomeci.ci` créé, custom claim `admin` vérifié sur un jeton réémis |
| Banc de test des règles | `firestore-tests/` — 63 tests, 11 suites, exécutés contre l'émulateur |
| Faille des compteurs | Trouvée par les tests, fermée, redéployée : incréments limités à ±1, un champ à la fois |
| Dossier de fourniture | `DOSSIER_FOURNITURE_MY_HOME_CI.docx` — 6 lots, formats exacts, à remettre aux prestataires |

## Décisions restant à trancher

1. **Projet Firebase de développement séparé** — oui ou non ? (impacte le coût
   et le risque de polluer la base de production)
2. **Vérification propriétaire** : quelles pièces exactement, qui les traite,
   sous quel délai ?
3. **SMS OTP** : le coût par SMS en Côte d'Ivoire est le principal poste
   variable. Le maintient-on comme méthode d'inscription principale, ou
   bascule-t-on l'inscription par défaut sur email + Google ?
