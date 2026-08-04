# MY HOME CI — Contexte Projet

## Description
MY HOME CI est une application mobile Flutter de mise en relation locative en Cote d'Ivoire. Elle connecte proprietaires de logements et locataires potentiels via une plateforme geolocalise avec chat integre. Aucun paiement n'est gere par l'application.

## Stack Technique
- **Frontend** : Flutter 3.x (Android + iOS)
- **Backend** : Firebase (Auth, Firestore, Storage, Cloud Messaging, Functions)
- **Carte** : Google Maps SDK Flutter
- **State Management** : Provider
- **Architecture** : Feature-first (screens/ + models/ + services/ + widgets/)
- **Chat** : Firebase Firestore (temps reel)
- **Notifications** : Firebase Cloud Messaging (FCM)

## Structure du projet
```
lib/
  main.dart
  app.dart
  config/
    theme.dart
    routes.dart
    constants.dart
  models/
    property.dart
    user_model.dart
    message.dart
    conversation.dart
  screens/
    splash/
    onboarding/
    auth/
    home/
    map/
    property_list/
    property_detail/
    chat/
    owner_dashboard/
    publish_property/
    favorites/
    profile/
  widgets/
    property_card.dart
    filter_chip_bar.dart
    search_bar.dart
    bottom_nav_bar.dart
    quarter_info_card.dart
  services/        (vide pour l'instant — logique a venir)
  utils/
```

## Phase actuelle
**Phase 1 — Interfaces UI uniquement** : Toutes les interfaces sont codees avec des donnees mock. Aucune logique backend n'est connectee. Le but est la validation visuelle par le client.

## Conventions
- Langue du code : anglais
- Langue de l'UI : francais
- Couleur primaire : #2E7D5B (vert emeraude)
- Couleur secondaire : #F5A623 (orange dore)
- Police titres : Poppins
- Police corps : Inter
- Icones : Lucide (via lucide_icons package) ou Material Icons
- Coins arrondis : 12px par defaut
- Pas de logique metier dans cette phase
- Donnees mock uniquement

## Depot GitHub
https://github.com/jasonemmanue/MY-HOME-CI.git

## Commandes utiles
```bash
flutter run                    # Lancer l'app
flutter build apk              # Build Android
flutter build ios               # Build iOS
flutter pub get                 # Installer les dependances
```
