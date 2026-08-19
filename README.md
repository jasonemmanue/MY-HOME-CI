# MY HOME CI

**Trouvez votre chez-vous en Cote d'Ivoire**

MY HOME CI est une application mobile de mise en relation locative dediee au marche ivoirien. Elle connecte directement les proprietaires de logements avec les personnes cherchant a louer, sans intermediaires ni frais caches.

## Fonctionnalites principales

- Recherche de logements avec filtres avances (type, prix, quartier, pieces)
- Carte interactive avec geolocalisation des biens
- Chat integre proprietaire-locataire (sans echanger de numero)
- Favoris et alertes personnalisees
- Informations sur les quartiers (commerces, ecoles, transports)
- Verification des proprietaires (badge verifie)
- Mode hors connexion pour les annonces vues recemment

## Stack technique

| Technologie | Usage |
|------------|-------|
| Flutter | Frontend cross-platform (Android + iOS) |
| Firebase Auth | Authentification (telephone OTP, email, Google) |
| Cloud Firestore | Base de donnees temps reel |
| Firebase Storage | Stockage photos/medias |
| Google Maps SDK | Carte interactive |
| Firebase Cloud Messaging | Notifications push |
| Provider | State management |

## Installation

```bash
# Cloner le depot
git clone https://github.com/jasonemmanue/MY-HOME-CI.git

# Installer les dependances
flutter pub get

# Lancer l'application
flutter run
```

Deux fichiers non versionnes sont attendus avant de pouvoir lancer l'application :
`android/local.properties` (`MAPS_API_KEY=...`, sinon la carte reste grise) et,
pour un build de production, `android/key.properties`. Voir [RELEASE.md](RELEASE.md).

## Publication

La signature, la construction et le deploiement sur Google Play sont decrits
dans [RELEASE.md](RELEASE.md).

## Phase actuelle

**Phase 1 — Maquettes UI** : Interfaces uniquement, donnees mock, aucune logique backend. En attente de validation client.

## Structure

```
lib/
  screens/     # Tous les ecrans de l'app
  widgets/     # Composants reutilisables
  models/      # Modeles de donnees
  config/      # Theme, routes, constantes
  services/    # (vide — logique a venir en Phase 2)
```

## Auteur

**Jason Emmanuel** — [@jasonemmanue](https://github.com/jasonemmanue)

## Licence

Projet prive — Tous droits reserves.
