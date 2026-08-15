# MY HOME CI — Contexte Projet

> Derniere mise a jour : 15/08/2026. Ce fichier decrit l'etat **reel** du code,
> pas l'intention initiale. Le mettre a jour a chaque changement structurel.

## Description
MY HOME CI est une application mobile Flutter de mise en relation locative en
Cote d'Ivoire. Elle connecte proprietaires de logements et locataires potentiels
via une plateforme geolocalisee avec chat temps reel.

**Le loyer ne transite jamais par l'application.** Seuls deux services payants a
destination des proprietaires sont factures, par Mobile Money via GeniusPay :
- `pro` — Pack Pro Proprietaire, 15 000 FCFA / 30 jours (annonces illimitees,
  badge verifie, statistiques)
- `boost` — Mise en avant d'une annonce, 5 000 FCFA / 7 jours

## Un produit, trois briques
| Brique | Emplacement | Depot |
|---|---|---|
| Application mobile (ce depot) | `MY HOME CI/` | https://github.com/jasonemmanue/MY-HOME-CI.git |
| Back-office web | `C:\Users\hp\StudioProjects\My Home CI Admin` | https://github.com/jasonemmanue/MY-HOME-CI-ADMIN.git |
| Backend Firebase | `functions/`, `firestore.rules`, `storage.rules`, `firestore.indexes.json` (dans ce depot) | idem mobile |

Les trois partagent le **meme projet Firebase `my-home-ci`**. Toute modification
du schema de donnees impacte les trois : verifier `lib/models/`,
`src/lib/types.ts` cote admin, et `firestore.rules` en meme temps.

## Stack Technique
- **Frontend** : Flutter (SDK Dart ^3.10.3), Android + iOS
- **Backend** : Firebase — Auth, Firestore, Storage, Cloud Messaging, Cloud
  Functions (Node 22), Analytics, Crashlytics, App Check
- **Carte** : `google_maps_flutter` + `geolocator` + `geocoding`
- **Recherche geospatiale** : geohash maison (`lib/utils/geohash.dart`) —
  Firestore ne sait pas faire de requete radiale
- **State management** : Provider (4 providers)
- **Auth** : email/mot de passe, OTP SMS, Google Sign-In, Sign in with Apple,
  mode invite
- **Paiements** : GeniusPay (Wave, Orange Money, MTN Money, Moov Money)
- **CI/CD** : Codemagic (`codemagic.yaml`) — pas de GitHub Actions

## Structure reelle du projet
```
lib/
  main.dart                  # Firebase init, Crashlytics, App Check, persistance offline, FCM
  app.dart                   # MultiProvider, MaterialApp, table de routage, deep-links notif
  firebase_options.dart      # genere par flutterfire configure
  config/
    theme.dart               # lightTheme + darkTheme
    routes.dart              # 19 routes nommees
    constants.dart           # types de biens, equipements, quartiers, villes, formats FCFA
  models/
    property.dart  user_model.dart  message.dart  conversation.dart
    quarter.dart   report.dart      search_alert.dart  app_notification.dart
  providers/
    auth_provider.dart  favorites_provider.dart
    property_provider.dart  settings_provider.dart
  screens/
    splash/  onboarding/  auth/ (auth_screen + otp_screen)
    home/ (home_screen + home_tab)  map/  property_list/  property_detail/
    publish_property/  chat/ (liste + detail)  favorites/  notifications/
    owner_dashboard/  legal/
    profile/ (profile, edit_profile, alerts, verification)
  services/
    auth_service.dart      property_service.dart   chat_service.dart
    storage_service.dart   notification_service.dart  favorites_service.dart
    location_service.dart  alert_service.dart      report_service.dart
    user_service.dart      quarter_service.dart    analytics_service.dart
    payment_service.dart
  utils/
    geohash.dart             # encodage + voisins, pour le filtre de distance
  widgets/
    property_card.dart  filter_chip_bar.dart  search_bar_widget.dart
    quarter_info_card.dart
functions/
  index.js                   # 11 Cloud Functions v2
  geniuspay.js               # client HTTP GeniusPay + verification de signature
test/
  widget_test.dart           # tests unitaires geohash / mots-cles / regles de publication
```

## Backend Firebase

**Projet** : `my-home-ci` — Functions en region `us-central1`, `maxInstances: 20`.

**Collections Firestore** (couvertes par `firestore.rules`) :
```
users/{uid}
  private/{docId}      favorites/{propertyId}   alerts/{alertId}
  notifications/{id}   tokens/{tokenId}
properties/{propertyId}
conversations/{convId}/messages/{messageId}
reports/{reportId}          verificationRequests/{userId}
transactions/{transactionId}   webPayments/{token}
quarters/{quarterId}           adminSettings/{docId}
```
Statuts d'annonce : `draft | pending | active | rented | archived | rejected`.
Roles utilisateur : `tenant | owner | admin` (admin porte aussi par un **custom
claim** `admin`, seul element sur lequel s'appuient les regles).

**Cloud Functions** (`functions/index.js`) :
- Paiement : `initiatePayment` (app), `initiatePaymentFromWeb` + `getWebPaymentStatus`
  (page web iOS), `geniusPayWebhook`, `sendActivationEmail`
- Declencheurs : `onMessageCreated`, `onPropertyStatusChanged`, `onVerificationDecided`
- Administration : `deleteAccount` (suppression en cascade), `setAdminRole`,
  `bootstrapFirstAdmin`

**Regle d'or paiement** : les montants vivent cote serveur (`PRODUCTS` dans
`index.js`). Ne jamais accepter un montant envoye par le client.

**Index** : 17 index composites dans `firestore.indexes.json`. Toute nouvelle
requete combinant `where` + `orderBy` en exige un — l'ajouter au fichier et
deployer, ne pas se contenter du lien propose dans la console.

## Etat d'avancement

**Fait** : les 20 ecrans, les 13 services, les regles Firestore et Storage, les
11 Cloud Functions, le back-office connecte, la conformite manifeste Android /
Info.plist iOS, les workflows Codemagic. **Il ne reste plus de donnees mock.**

**Reste a faire** : voir `ROADMAP_TECHNIQUE.md`, qui liste les points bloquants
(signature Android, Google Sign-In iOS, clefs Maps, deploiement du back-office,
tests des regles Firestore).

## Conventions
- Langue du code et des identifiants : anglais
- Langue de l'UI et des commentaires : francais
- **Commentaires et documentation ecrits sans accents** (contrainte d'encodage
  de la chaine d'outils Windows) — s'y tenir dans tous les fichiers du depot
- Couleur primaire : #2E7D5B (vert emeraude)
- Couleur secondaire : #F5A623 (orange dore)
- Police titres : Poppins — police corps : Inter (via `google_fonts`)
- Icones : Material Icons uniquement (le package `lucide_icons` n'est pas utilise)
- Coins arrondis : 12px par defaut
- Un commentaire explique **pourquoi**, jamais **quoi** : le code dit deja quoi

## Configuration locale requise (hors depot)
| Fichier | Role | Sans lui |
|---|---|---|
| `android/key.properties` | signature de release | l'AAB est signe avec la clef de debogage et Google Play le refuse |
| `android/local.properties` → `MAPS_API_KEY` | carte Android | carte grise, sans erreur |
| `ios/Flutter/Keys.xcconfig` → `MAPS_API_KEY_IOS` | carte iOS | idem |
| `functions/.env` | secrets GeniusPay (3) et Gmail (2) | les paiements et l'email d'activation echouent |

`google-services.json` et `GoogleService-Info.plist` sont, eux, versionnes.

## Commandes utiles
```bash
flutter pub get                              # Dependances
flutter run                                  # Lancer l'app
flutter analyze lib --no-fatal-infos         # Analyse statique (ce que fait la CI)
flutter test                                 # Tests unitaires
flutter build appbundle --release            # AAB Google Play (exige key.properties)
firebase deploy --only firestore:rules       # Regles Firestore
firebase deploy --only firestore:indexes     # Index
firebase deploy --only storage               # Regles Storage
firebase deploy --only functions             # Cloud Functions
firebase emulators:start                     # Auth 9099, Firestore 8080, Functions 5001, Storage 9199
```

Le build iOS se fait sur **Codemagic** (Xcode n'existe pas sous Windows) :
pousser sur `ios` declenche la verification de compilation et un build
simulateur ; pousser un tag `v*` declenche TestFlight et l'AAB Android.
