# CAHIER DES CHARGES — MY HOME CI

## Application Mobile Immobiliere

**Plateforme de mise en relation locative en Cote d'Ivoire**

---

| | |
|---|---|
| **Type** | Application mobile (Utilitaire / Plateforme collaborative) |
| **Secteur** | Immobilier — Cote d'Ivoire |
| **Cibles** | Android & iOS — Smartphone & Tablette |
| **Langues** | Francais |
| **Monetisation** | Freemium (annonces sponsorisees) + Publicite |

---

| | |
|---|---|
| **Version du document** | 1.0 MVP |
| **Date de redaction** | 4 aout 2026 |
| **Statut** | En cours de validation |
| **Confidentialite** | Confidentiel |

---

## Table des matieres

1. [Introduction et Definitions](#1-introduction-et-definitions)
2. [Modele Economique](#2-modele-economique)
3. [User Stories et Cas d'Utilisation](#3-user-stories-et-cas-dutilisation)
4. [Specifications UX — Ecrans et Fonctionnalites](#4-specifications-ux--ecrans-et-fonctionnalites)
5. [Contraintes Metier et Logistiques](#5-contraintes-metier-et-logistiques)
6. [Cahier des Charges MVP](#6-cahier-des-charges-mvp)
7. [Budget Infrastructure et Outils](#7-budget-infrastructure-et-outils)
8. [Plateforme, Coeur de Metier et Originalite](#8-plateforme-coeur-de-metier-et-originalite)
9. [Planning Previsionnel](#9-planning-previsionnel)
10. [Captures d'ecran de l'application](#10-captures-decran-de-lapplication)
11. [Conclusion](#11-conclusion)
12. [Annexe A — Recapitulatif du formulaire initial](#annexe-a--recapitulatif-du-formulaire-initial)

---

## 1. Introduction et Definitions

### 1.1 Presentation generale du projet

> MY HOME CI est une application mobile dediee au marche locatif ivoirien. Elle connecte directement les proprietaires de logements avec les personnes cherchant a louer, en eliminant les intermediaires et en offrant une experience moderne, geolocalise et securisee.

### 1.1.1 Scenario initial

Le marche immobilier en Cote d'Ivoire souffre d'un manque criant de digitalisation dans le segment locatif. Les chercheurs de logements dependent encore largement du bouche-a-oreille, des pancartes "A Louer" et des agences physiques qui prelevent des frais importants. Les proprietaires, de leur cote, peinent a trouver des locataires fiables sans passer par ces intermediaires couteux. MY HOME CI vise a combler ce vide en proposant une plateforme numerique gratuite, intuitive et centree sur la mise en relation directe.

### 1.1.2 Objet de l'application

L'application a pour objet principal de :

- Permettre aux proprietaires de publier et gerer leurs annonces de logements a louer
- Permettre aux chercheurs de logements de rechercher, filtrer et visualiser les offres sur une carte interactive
- Faciliter la communication directe entre proprietaires et locataires potentiels via un chat integre
- Offrir une experience de recherche enrichie grace a la geolocalisation, aux filtres avances et aux alertes personnalisees
- Fournir des informations contextuelles sur les quartiers (commodites, transports, securite)

**Important :** MY HOME CI ne gere aucun paiement ni transaction financiere. La plateforme se concentre exclusivement sur la mise en relation.

### 1.1.3 Evolutions envisagees

1. **Phase 1 (MVP)** : Recherche de logements, carte interactive, chat proprietaire-locataire, profils, favoris
2. **Phase 2** : Systeme d'avis et notations, visite virtuelle 360deg, alertes intelligentes
3. **Phase 3** : Extension geographique a d'autres villes ivoiriennes puis Afrique de l'Ouest
4. **Phase 4** : Intelligence artificielle pour recommandations personnalisees, estimation de loyer
5. **Phase 5** : Module colocation, integration services demenagement, assurance habitation

### 1.2 Definition des utilisateurs et de leurs roles

| Role | Profil | Acces & Droits principaux |
|------|--------|--------------------------|
| **Locataire (Visiteur)** | Toute personne 18+ cherchant un logement en Cote d'Ivoire | Consultation d'annonces, geolocalisation, messagerie, favoris, partage reseaux sociaux, alertes |
| **Proprietaire** | Proprietaire individuel ou agence immobiliere | Creation de compte, publication d'annonces, gestion de biens, reception de messages, statistiques basiques |
| **Administrateur** | Equipe interne MY HOME CI | Moderation, gestion des utilisateurs, analytics, signalements |

> **Precision importante :** Les locataires peuvent utiliser l'application sans inscription prealable pour consulter les annonces. L'inscription est requise uniquement pour envoyer des messages, sauvegarder des favoris et creer des alertes. La creation de compte proprietaire necessite une verification d'identite.

### 1.3 Definitions metier

- **Logement** : Bien immobilier mis en location sur la plateforme (appartement, studio, villa, chambre, duplex, terrain, local commercial)
- **Annonce** : Fiche descriptive d'un logement creee par un proprietaire, contenant photos, description, loyer, localisation, caracteristiques
- **Proprietaire** : Personne physique ou morale ayant cree un compte professionnel et publie au moins une annonce
- **Locataire** : Utilisateur de l'application cherchant un logement a louer
- **Favori** : Annonce sauvegardee par un locataire pour consultation ulterieure
- **Alerte** : Notification automatique envoyee a un locataire lorsqu'un nouveau logement correspond a ses criteres de recherche
- **Badge verifie** : Marqueur attribue aux proprietaires ayant fourni des pieces d'identite valides
- **Quartier** : Zone geographique autour d'un logement avec ses informations contextuelles (commerces, ecoles, transports)
- **MVP** : Minimum Viable Product — version minimale fonctionnelle deployable pour tester le marche

---

## 2. Modele Economique

### 2.1 Types de monetisation

MY HOME CI repose sur un modele economique **freemium** combine a la **publicite in-app**. Aucune commission sur transaction n'est prelevee (pas de paiement integre).

### 2.1.1 Grille tarifaire

| Service | Description | Tarif estime |
|---------|------------|--------------|
| Publication annonce (gratuit) | 3 annonces standard offertes par mois | Gratuit |
| Annonce Boost | Mise en avant dans les resultats pendant 7 jours | 3 000 — 10 000 XOF/sem. |
| Pack Pro Proprietaire | Annonces illimitees + badge verifie + statistiques detaillees | 15 000 XOF/mois |
| Publicite display (bannieres) | Affichage de publicites tierces dans l'app | CPM / CPC negocie |

### 2.1.2 Modele publicitaire

- **Formats publicitaires :** Bannieres en bas d'ecran, publicites natives integrees au fil d'annonces
- **Ciblage :** Geographique (villes CI), demographique (18+), comportemental (recherches dans l'app)
- **Regle d'affichage :** Maximum 1 publicite toutes les 6 annonces consultees
- **Mode gratuit :** Les utilisateurs gratuits voient les publicites. Le Pack Pro les masque pour les proprietaires

### 2.1.3 Economie gratuite et freemium

| Fonctionnalite | Gratuit | Pro |
|----------------|---------|-----|
| Consultation d'annonces | Oui | Oui |
| Geolocalisation / Carte | Oui | Oui |
| Messagerie proprietaire-locataire | Oui | Oui |
| 3 annonces/mois (proprietaire) | Oui | Oui |
| Annonces illimitees | - | Oui |
| Annonces Boost | - | Oui |
| Statistiques detaillees (vues, contacts) | - | Oui |
| Sans publicites | - | Oui |
| Badge proprietaire verifie | - | Oui |
| Alertes illimitees (locataire) | - | Oui |

### 2.1.4 Projection financiere — Base 10 000+ utilisateurs

| Source de revenu | Hypothese | Revenu/mois (XOF) | Revenu/an (XOF) |
|-----------------|-----------|-------------------|-----------------|
| Pack Pro proprietaires (5%) | 500 x 15 000 | 7 500 000 | 90 000 000 |
| Annonces Boost | 300 x 5 000 | 1 500 000 | 18 000 000 |
| Publicite display (CPM) | Estime | 500 000 | 6 000 000 |
| **TOTAL ESTIME** | | **9 500 000** | **114 000 000** |

### 2.2 Analyse concurrentielle

| Concurrent | Forces | Faiblesses face a MY HOME CI |
|-----------|--------|------------------------------|
| Jumia House CI | Presence panafricaine, notoriete | Interface peu mobile-first, pas de chat integre |
| CoinAfrique | Marketplace generale populaire | Pas specialise immobilier, pas de carte |
| Groupes Facebook | Grande audience, gratuit | Pas de filtres, pas de geolocalisation, arnaque frequente |
| Agences physiques | Confiance, visites physiques | Frais eleves (1-2 mois de caution), pas digital |
| **MY HOME CI** | Mobile-first, carte interactive, chat direct, gratuit, verifie | A construire |

---

## 3. User Stories et Cas d'Utilisation

### 3.1 Cas d'utilisation — Locataire (Visiteur)

| ID | En tant que locataire, je peux... | Relation |
|----|-----------------------------------|----------|
| UC-L01 | Consulter la liste des logements disponibles | - |
| UC-L02 | Filtrer les logements par loyer, localisation, type, nombre de pieces | *include* UC-L01 |
| UC-L03 | Visualiser les logements sur une carte interactive | *include* UC-L01 |
| UC-L04 | Consulter la fiche detaillee d'un logement | *extend* UC-L01 |
| UC-L05 | Voir les photos d'un logement en plein ecran | *include* UC-L04 |
| UC-L06 | Contacter un proprietaire par messagerie | *extend* UC-L04 |
| UC-L07 | Ajouter un logement a mes favoris | *extend* UC-L04 |
| UC-L08 | Partager une annonce sur les reseaux sociaux | *extend* UC-L04 |
| UC-L09 | Creer une alerte pour de nouveaux logements correspondant a mes criteres | *extend* UC-L02 |
| UC-L10 | Recevoir des notifications push (nouvelles annonces, messages) | - |
| UC-L11 | Consulter les informations du quartier (commerces, transports) | *extend* UC-L04 |
| UC-L12 | Comparer plusieurs logements cote a cote | *extend* UC-L07 |
| UC-L13 | Signaler une annonce frauduleuse | *extend* UC-L04 |

### 3.2 Cas d'utilisation — Proprietaire

| ID | En tant que proprietaire, je peux... | Relation |
|----|--------------------------------------|----------|
| UC-P01 | Creer un compte / Me connecter | - |
| UC-P02 | Publier une annonce de logement | *include* UC-P01 |
| UC-P03 | Ajouter des photos a mon annonce | *include* UC-P02 |
| UC-P04 | Geolocaliser mon bien sur la carte | *include* UC-P02 |
| UC-P05 | Modifier / Supprimer / Archiver une annonce | *extend* UC-P02 |
| UC-P06 | Recevoir et repondre aux messages des locataires | *extend* UC-P01 |
| UC-P07 | Consulter les statistiques de mes annonces (vues, contacts) | *extend* UC-P01 |
| UC-P08 | Marquer un logement comme "Loue" | *extend* UC-P05 |
| UC-P09 | Recevoir des notifications push (messages, demandes) | - |
| UC-P10 | Faire verifier mon profil (badge verifie) | *extend* UC-P01 |

### 3.3 Cas d'utilisation — Administrateur

| ID | En tant qu'administrateur, je peux... |
|----|--------------------------------------|
| UC-A01 | Gerer les comptes utilisateurs (suspension, validation) |
| UC-A02 | Moderer les annonces (signalements, suppression) |
| UC-A03 | Parametrer les publicites et campagnes |
| UC-A04 | Consulter les analytics (trafic, conversions, revenus) |
| UC-A05 | Gerer les packs Pro et abonnements |
| UC-A06 | Envoyer des notifications push globales |
| UC-A07 | Verifier les profils proprietaires (badge) |

---

## 4. Specifications UX — Ecrans et Fonctionnalites

L'application est structuree en **10 ecrans principaux** pour le MVP.

### 4.1 Ecran 1 — Splash Screen & Onboarding

- Logo anime MY HOME CI avec slogan "Trouvez votre chez-vous"
- 3 pages d'onboarding illustrees :
  1. "Explorez des milliers de logements pres de chez vous"
  2. "Contactez directement les proprietaires"
  3. "Sauvegardez vos favoris et recevez des alertes"
- Bouton "Commencer" / "Passer"
- Affiche une seule fois au premier lancement

### 4.2 Ecran 2 — Authentification

- Connexion par telephone (OTP SMS) ou email/mot de passe
- Connexion sociale (Google)
- Differenciation des roles : "Je cherche un logement" / "Je suis proprietaire"
- Les locataires peuvent passer l'inscription (mode invité) pour consulter les annonces
- Formulaire de creation de compte proprietaire avec verification

### 4.3 Ecran 3 — Page d'accueil

- Barre de recherche prominente avec auto-completion (ville, quartier, type de bien)
- Chips de filtres rapides : Studio, Appartement, Villa, Chambre, Bureau
- Section "Pres de vous" avec logements geolocalises (si permission GPS accordee)
- Section "Annonces recentes" avec carrousel horizontal
- Section "Quartiers populaires" avec vignettes (Cocody, Plateau, Marcory, Yopougon...)
- Navigation bottom bar : Accueil | Carte | Favoris | Messages | Profil

### 4.4 Ecran 4 — Carte Interactive

- Carte Google Maps integree avec marqueurs de logements
- Clustering de marqueurs pour les zones denses
- Fiche resume cliquable (preview card) depuis la carte : photo, titre, prix
- Geolocalisation de l'utilisateur en temps reel
- Filtre de distance (rayon : 500m, 1km, 3km, 5km, 10km)
- Filtre par type de bien et gamme de prix directement sur la carte
- Bouton de recentrage sur position actuelle

### 4.5 Ecran 5 — Liste des logements

- Affichage en grille (2 colonnes) ou en liste (au choix utilisateur)
- Chaque carte : photo principale, titre, loyer/mois, localisation, badge verifie, nombre de pieces
- Tri : prix croissant/decroissant, plus recent, plus proche
- Filtres avances accessibles via un drawer :
  - Type de bien (studio, appartement, villa, chambre, duplex, terrain, bureau)
  - Fourchette de loyer (slider min/max)
  - Nombre de pieces (1, 2, 3, 4+)
  - Meuble / Non meuble
  - Quartier / Commune
  - Disponibilite immediate
- Pagination infinie (lazy loading)

### 4.6 Ecran 6 — Fiche detail logement

- Galerie photos horizontale scrollable avec indicateur de position
- Mode plein ecran pour les photos (pinch to zoom)
- Titre, loyer mensuel en XOF, localisation
- Description complete du bien
- Caracteristiques en grille : surface, pieces, salle de bain, etage, parking, balcon, cuisine equipee
- Equipements : eau courante, electricite, climatisation, internet, gardien, piscine...
- Mini-carte avec position du logement
- Section "Decouvrir le quartier" : commerces, ecoles, pharmacies, transports a proximite
- Bouton principal "Contacter le proprietaire" (ouvre le chat)
- Boutons secondaires : Favoris (coeur), Partager, Signaler
- Profil resume du proprietaire (nom, badge verifie, nombre d'annonces, note)

### 4.7 Ecran 7 — Messagerie / Chat

- Liste des conversations recentes avec apercu du dernier message
- Badge de messages non lus
- Interface de chat style WhatsApp :
  - Envoi de textes
  - Envoi de photos
  - Horodatage des messages
  - Indicateur de lecture (vu / non vu)
  - Indicateur "en train d'ecrire..."
- Preview du logement concerne en haut de la conversation
- Bouton d'appel telephonique direct (si le proprietaire a active cette option)
- Notifications push en temps reel

### 4.8 Ecran 8 — Espace Proprietaire (Tableau de bord)

- Resume : nombre d'annonces actives, vues totales, messages recus
- Liste de mes annonces avec statut (active, en attente, louee, archivee)
- Bouton "Publier une nouvelle annonce"
- Statistiques par annonce : nombre de vues, nombre de contacts, taux de conversion
- Gestion rapide : modifier, archiver, marquer comme "loue"

### 4.9 Ecran 9 — Publier / Modifier une annonce

- Formulaire multi-etapes :
  1. **Type de bien** : selection du type (studio, appartement, villa, etc.)
  2. **Localisation** : adresse textuelle + positionnement sur la carte (glisser le pin)
  3. **Details** : surface, nombre de pieces, etage, meuble/non meuble
  4. **Equipements** : checkboxes (eau, electricite, clim, internet, parking, etc.)
  5. **Photos** : ajout de 1 a 10 photos (appareil photo ou galerie)
  6. **Loyer & conditions** : montant mensuel, caution, conditions particulieres
  7. **Apercu et publication** : resume avant validation
- Sauvegarde en brouillon possible
- Modification d'une annonce existante

### 4.10 Ecran 10 — Profil / Parametres

- Photo de profil et informations personnelles
- Mes favoris (raccourci)
- Mes alertes de recherche (gestion)
- Parametres :
  - Notifications : activees/desactivees par categorie
  - Mode clair / sombre
  - A propos de MY HOME CI
  - Conditions d'utilisation et politique de confidentialite
  - Aide et support
- Deconnexion
- Suppression du compte

### 4.11 Design et charte graphique

| Element | Specification |
|---------|--------------|
| **Inspiration visuelle** | Airbnb + LeBonCoin : moderne, epure, chaleureux |
| **Couleur primaire** | Vert emeraude (#2E7D5B) — evoque la confiance, le foyer, la Cote d'Ivoire |
| **Couleur secondaire** | Orange dore (#F5A623) — chaleur, energie, accueil |
| **Couleur de fond** | Blanc (#FFFFFF) et Gris tres clair (#F5F5F5) |
| **Police** | Poppins (titres), Inter (corps de texte) |
| **Icones** | Lucide Icons, style outline coherent |
| **Effets visuels** | Ombres douces, coins arrondis (12px), transitions fluides |
| **Images** | Photos de logements HD, placeholders elegants |
| **Modes** | Clair et Sombre obligatoires |

---

## 5. Contraintes Metier et Logistiques

### 5.1 Contraintes techniques

| Contrainte | Description | Priorite |
|-----------|------------|----------|
| Plateformes | Android ET iOS obligatoires, Smartphone ET Tablette | Critique |
| Framework | Flutter (cross-platform) | Critique |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Messaging, Functions) | Critique |
| Performances | Fluide, < 2s de chargement, peu energivore | Critique |
| Mode hors connexion | Consultation des annonces recemment vues sans internet | Haute |
| Securite | HTTPS, chiffrement des donnees, anti-injection | Critique |
| Langue | Francais | Critique |
| Notifications push | Firebase Cloud Messaging | Haute |
| Analytics | Firebase Analytics (base) | Haute |
| Backups | Sauvegardes automatiques quotidiennes | Critique |
| Scalabilite | Infrastructure prevue pour 500k+ utilisateurs | Haute |

### 5.2 Contraintes de securite

- Chiffrement TLS/HTTPS pour toutes les communications
- Regles de securite Firestore strictes (lecture/ecriture par role)
- Limitation du nombre de tentatives de connexion (anti-brute force)
- Conformite aux reglementations locales de protection des donnees
- Authentification securisee (Firebase Auth + OTP)
- Moderation des contenus publies (signalement + revue admin)
- Validation des photos (pas de contenu inapproprie)

### 5.3 Fonctionnalites specifiques requises

| Fonctionnalite | Description | Statut |
|----------------|------------|--------|
| Geolocalisation | GPS pour localiser l'utilisateur et les biens | **Requis** |
| Creation de compte | Proprietaires uniquement (locataires en option) | **Requis** |
| Notifications push | Nouveaux biens, messages, alertes | **Requis** |
| Mode hors connexion | Cache des annonces recentes | **Requis** |
| Chat / Messagerie | Temps reel entre locataire et proprietaire | **Requis** |
| Partage reseaux sociaux | WhatsApp, Facebook, X, lien direct | **Requis** |
| Favoris | Sauvegarde d'annonces | **Requis** |
| Filtres avances | Multi-criteres (prix, type, quartier, pieces) | **Requis** |
| Carte interactive | Google Maps avec marqueurs | **Requis** |
| Alertes personnalisees | Notification quand un nouveau bien match les criteres | **Requis** |

### 5.4 Objectifs qualitatifs et quantitatifs

#### Objectifs qualitatifs

Le service doit etre fiable, fluide, facile a utiliser et optimise pour les reseaux 3G/4G ivoiriens. L'experience utilisateur doit inspirer confiance grace a la verification des proprietaires et la moderation des annonces.

#### Objectifs quantitatifs

| Indicateur | Cible |
|-----------|-------|
| Volume de trafic vise | Plus de 100 000 sessions/mois |
| Telechargements vises | 500 000 en 2 ans |
| Nombre d'annonces actives | 10 000+ a 1 an |
| Utilisateurs long terme | 1 million d'abonnes |
| Cible geographique initiale | Abidjan et grandes villes CI (18+) |
| Temps de chargement moyen | < 2 secondes |
| Disponibilite | 99.5% uptime |

---

## 6. Cahier des Charges MVP

### 6.1 Perimetre du MVP — Minimum Viable Product

> Le MVP doit permettre de valider l'adequation produit-marche en Cote d'Ivoire avec un ensemble de fonctionnalites de base operationnelles.

> **Principe :** Lancer rapidement, apprendre des utilisateurs, iterer. Le MVP n'inclut pas toutes les fonctionnalites envisagees mais permet une utilisation complete du cycle principal (chercher un logement -> contacter le proprietaire).

### 6.1.1 Fonctionnalites incluses dans le MVP

1. **Splash & Onboarding** : premiere impression soignee
2. **Authentification** : inscription/connexion proprietaire, mode invite locataire
3. **Page d'accueil** avec recherche, filtres rapides, sections recommandees
4. **Carte interactive** avec geolocalisation et marqueurs
5. **Liste des logements** avec filtres avances et tri
6. **Fiche detail** complete avec photos, description, caracteristiques, quartier
7. **Messagerie** temps reel proprietaire-locataire
8. **Espace proprietaire** : publication et gestion d'annonces
9. **Favoris** : sauvegarde d'annonces
10. **Profil & Parametres** : gestion du compte, mode sombre/clair

### 6.1.2 Fonctionnalites exclues du MVP (Phase 2+)

- Systeme d'avis et notations des proprietaires
- Visite virtuelle 360 degres
- Alertes intelligentes avec IA
- Comparaison cote a cote de logements
- Module colocation (recherche de colocataires)
- Estimation automatique de loyer
- Extension hors Abidjan
- Statistiques avancees proprietaires
- Pack Pro / Monetisation

### 6.1.3 Recapitulatif technique du MVP

| Element | Specification |
|---------|--------------|
| Type de solution | Application mobile cross-platform (Flutter) |
| Plateformes | Android ET iOS |
| Supports | Smartphone ET Tablette |
| Backend | Firebase (Spark gratuit au demarrage) |
| Hebergement | Firebase Hosting + Cloud Functions |
| Nombre d'ecrans MVP | 10 ecrans principaux |
| Langue | Francais |
| Paiement MVP | Non inclus (aucun paiement) |
| Analytiques | Firebase Analytics (base) |
| Statistiques initiales | Aucune (depart de zero) |

---

## 7. Budget Infrastructure et Outils

### 7.1 Hypotheses budgetaires

Le budget presente couvre les outils, licences, services cloud et infrastructures necessaires au developpement et au lancement du MVP. Les couts sont presentes en **XOF** (Franc CFA BCEAO) et en **USD** pour faciliter la comparaison.

> **Note :** Le budget developpement humain (salaires, freelances) est **non inclus** dans ce tableau. Ce tableau couvre uniquement les **outils et services a souscrire**.

### 7.2 Budget Developpement et Outils

| Categorie | Outil / Service | Cout/mois (USD) | Cout/an (XOF) | Priorite |
|-----------|----------------|-----------------|---------------|----------|
| **Backend Cloud** | Firebase (Spark gratuit -> Blaze) | $0-100 | 0 - 720 000 | Critique |
| | Domaine (.ci ou .com) | $15/an | 9 000 | Critique |
| **Cartographie** | Google Maps Platform (SDK mobile) | $0-200* | 0 - 1 440 000 | Critique |
| | (*Credit gratuit $200/mois Google) | Gratuit | - | - |
| **Notifications** | Firebase Cloud Messaging (FCM) | Gratuit | 0 | Critique |
| **Analytics** | Firebase Analytics | Gratuit | 0 | Haute |
| **Messagerie** | Firebase Firestore (chat temps reel) | $0-50 | 0 - 360 000 | Critique |
| **Stockage medias** | Firebase Storage | $5-50 | 36 000 - 360 000 | Critique |
| **Publicite** | Google AdMob (regie pub in-app) | Gratuit | Revenus | Haute |
| **Publication stores** | Google Play Developer Account | $25 (unique) | 18 000 | Critique |
| | Apple Developer Program | $99/an | 712 800 | Critique |
| **Monitoring** | Firebase Crashlytics | Gratuit | 0 | Haute |
| | Sentry (crash reporting avance) | Gratuit-$26 | 0 - 187 000 | Haute |
| **CI/CD** | GitHub Actions | $0-49 | 0 - 352 800 | Haute |
| **Design** | Figma (outil de maquettes) | $0-15 | 0 - 108 000 | Haute |
| **Gestion projet** | Notion / Linear | $0-10 | 0 - 72 000 | Haute |

### 7.3 Recapitulatif budgetaire annuel

| Poste | Detail | Cout annuel estime (XOF) |
|-------|--------|--------------------------|
| Infrastructure cloud | Firebase (Spark -> Blaze) | 0 — 720 000 |
| Cartographie | Google Maps (credit gratuit) | Gratuit |
| Stockage medias | Firebase Storage | 36 000 — 360 000 |
| Publication App Stores | Google Play + Apple | 730 800 |
| Monitoring & CI | Crashlytics + GitHub Actions | 0 — 540 000 |
| Design & Outils | Figma + Notion | 0 — 180 000 |
| **TOTAL ESTIME (fourchette basse)** | *Config economique* | **~ 766 800 XOF/an** |
| **TOTAL ESTIME (fourchette haute)** | *Config complete* | **~ 2 530 800 XOF/an** |

> **Recommandation :** Partir avec la **fourchette basse** (outils gratuits et freemium) pour le MVP. Firebase offre une formule Spark (gratuite) tres genereuse pour le lancement. Migrer vers le plan Blaze (pay-as-you-go) uniquement en cas de croissance.

### 7.4 Budget previsionnel de developpement (estimation prestataire)

| Phase | Description | Fourchette estimee (XOF) |
|-------|------------|--------------------------|
| Design UX/UI | Maquettes Figma, prototypes, charte graphique | 300 000 — 1 500 000 |
| Developpement MVP | 10 ecrans, Firebase, carte, chat | 2 000 000 — 10 000 000 |
| Tests et QA | Tests fonctionnels, performance, securite | 200 000 — 800 000 |
| Deploiement Stores | Publication + suivi App Stores | 100 000 — 400 000 |
| Maintenance (an 1) | Corrections de bugs, mises a jour | 300 000 — 1 500 000 |
| **TOTAL DEVELOPPEMENT** | | **2 900 000 — 14 200 000 XOF** |

---

## 8. Plateforme, Coeur de Metier et Originalite

### 8.1 Coeur de metier

MY HOME CI est une **plateforme de mise en relation locative mobile-first** dediee au marche ivoirien. Elle connecte proprietaires et chercheurs de logements dans un ecosysteme simple, transparent et gratuit, sans intermediaires ni frais de commission.

### 8.2 Originalite et differenciation

- **Zero intermediaire** : Mise en relation directe proprietaire-locataire, aucun frais cache
- **Mobile-first Africa** : Concue pour les contraintes reseau africaines (3G, optimisation bande passante, images compressees)
- **Carte interactive locale** : Navigation visuelle des logements par quartier, specifiquement adaptee aux communes d'Abidjan et villes ivoiriennes
- **Chat integre securise** : Communication directe sans echanger de numeros de telephone
- **Verification proprietaire** : Badge "Verifie" pour rassurer les locataires et reduire les arnaques
- **Informations quartier** : Donnees contextuelles (commerces, ecoles, transports) pour aider a la decision
- **Pas d'inscription obligatoire** : Les locataires consultent librement, l'inscription sert a debloquer les fonctionnalites sociales
- **Gratuit et accessible** : Modele freemium ou la consultation et la mise en relation restent toujours gratuites
- **Mode hors connexion** : Consultation des annonces vues recemment sans internet

### 8.3 Inspirations et modeles de reference

| Reference | Ce qu'on en retient |
|-----------|-------------------|
| Airbnb | Photos immersives, fiche logement detaillee, UX de recherche |
| LeBonCoin | Simplicite, rapidite, filtres efficaces |
| Jumia House | Adaptation marche africain, categories locales |
| WhatsApp | Messagerie fluide et familiere |
| Google Maps | Navigation carte, fiches de lieux |

---

## 9. Planning Previsionnel

| Phase | Duree estimee | Livrables |
|-------|--------------|-----------|
| **Phase 0 — Cadrage** | 1 semaine | Cahier des charges valide, charte graphique |
| **Phase 1 — Design UI** | 2 semaines | Maquettes Flutter (interfaces sans logique) |
| **Phase 2 — Validation client** | 1 semaine | Screenshots valides, ajustements UI |
| **Phase 3 — Developpement MVP** | 6-8 semaines | App fonctionnelle avec Firebase |
| **Phase 4 — Tests & QA** | 2 semaines | Tests fonctionnels, corrections |
| **Phase 5 — Deploiement** | 1 semaine | Publication Google Play + App Store |
| **Phase 6 — Lancement beta** | 2 semaines | Beta test avec utilisateurs reels |

---

## 10. Captures d'ecran de l'application

> **Cette section sera completee apres validation des interfaces par le client.**
> Les captures d'ecran seront prises depuis un appareil Android et insérées ci-dessous.

### 10.1 Ecran Splash & Onboarding

*[Capture d'ecran a inserer]*

### 10.2 Ecran d'authentification

*[Capture d'ecran a inserer]*

### 10.3 Page d'accueil

*[Capture d'ecran a inserer]*

### 10.4 Carte interactive

*[Capture d'ecran a inserer]*

### 10.5 Liste des logements

*[Capture d'ecran a inserer]*

### 10.6 Fiche detail logement

*[Capture d'ecran a inserer]*

### 10.7 Messagerie / Chat

*[Capture d'ecran a inserer]*

### 10.8 Espace Proprietaire

*[Capture d'ecran a inserer]*

### 10.9 Publier une annonce

*[Capture d'ecran a inserer]*

### 10.10 Profil & Parametres

*[Capture d'ecran a inserer]*

---

## 11. Conclusion

Le present cahier des charges definit les bases solides pour le developpement de MY HOME CI, plateforme de mise en relation locative mobile dediee a la Cote d'Ivoire.

Les points cles a retenir sont :

- Application mobile Android & iOS, cross-platform Flutter (smartphone + tablette)
- Cible : toute personne 18 ans et plus en Cote d'Ivoire cherchant ou proposant un logement a louer
- **Aucun paiement integre** — plateforme de mise en relation pure
- Modele economique freemium + publicite
- MVP : 10 ecrans fonctionnels, geolocalisation, chat integre, mode clair/sombre
- Infrastructure Firebase (gratuite au demarrage), evolutive
- Budget outils estime entre **766 800 et 2 530 800 XOF/an**
- Budget developpement estime entre **2 900 000 et 14 200 000 XOF**

Ce document est un **document vivant** qui evoluera en fonction des retours du prestataire technique, des validations du commanditaire et des apprentissages issus du terrain.

### Prochaines etapes :

1. Validation du cahier des charges par toutes les parties
2. Finalisation des maquettes UI (interfaces Flutter)
3. Validation des captures d'ecran par le client
4. Developpement du MVP (integration Firebase)
5. Tests utilisateurs et lancement beta

---

## Annexe A — Recapitulatif du formulaire initial

| Champ | Valeur renseignee |
|-------|------------------|
| Nom du projet | MY HOME CI |
| Services/produits | Mise en relation locative (immobilier) |
| Axes de developpement | Recherche logements, carte, messagerie, favoris, alertes |
| Concurrent principal | Jumia House CI, CoinAfrique, Groupes Facebook |
| Solution actuelle | Application mobile Flutter |
| Plateformes | Android et iOS |
| Hebergement | Firebase (Spark puis Blaze) |
| Maintenance | Assuree par le developpeur |
| Nombre d'ecrans MVP | 10 ecrans |
| Type de monetisation | Freemium + Publicite |
| Paiements a integrer | **Aucun** (mise en relation uniquement) |
| Objectifs qualitatifs | Fiable, fluide, facile a utiliser, peu energivore |
| Objectifs quantitatifs | 500 000 telechargements en 2 ans |
| Cibles | Toutes personnes 18+, Cote d'Ivoire |
| OS cibles | Android ET iOS |
| Langue | Francais |
| Fonctionnalites requises | Geolocalisation, Login (proprietaires), Notifications push, Mode hors ligne, Chat, Partage social, Favoris, Alertes, Carte |
| Note login | Inscription obligatoire pour proprietaires, optionnelle pour locataires |
| Inspiration visuelle | Airbnb (immersif) + LeBonCoin (simple, rapide) |
| Elements graphiques | Style moderne, epure, couleurs nature (vert/orange) |
