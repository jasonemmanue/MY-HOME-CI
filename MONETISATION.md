# Modele economique

Ce document decrit ce qui est facture, a qui, et ou la regle est appliquee.

> **Principe non negociable** : tout ce qui touche a l'argent est calcule et
> decompte **cote serveur**. Un montant transmis par l'application serait
> modifiable, et l'utilisateur fixerait le prix qu'il paie. Un compteur stocke
> sur l'appareil repartirait de zero a la reinstallation.

---

## 1. Publication d'annonces

### La regle

Chaque proprietaire dispose de **4 operations gratuites**. Une operation est
une **publication** ou une **remise en ligne** d'annonce expiree.

Au-dela, chaque operation coute **5 % du prix de l'annonce**, avec un
**minimum de 500 FCFA**. Le plancher n'est pas cosmetique : sans lui, une
annonce affichee a 0 franc — ou a un prix symbolique — serait publiable
gratuitement sans fin.

### La fenetre de 30 jours

L'unite facturee n'est pas le geste mais la **fenetre de visibilite**. Une
annonce publiee reste en ligne **30 jours**, et son proprietaire la modifie
autant qu'il veut pendant cette periode, sans frais.

Passe ce delai, l'annonce est archivee automatiquement et disparait des
recherches. La remettre en ligne consomme une nouvelle operation.

| Geste | Consomme une operation ? |
|---|---|
| Creer un brouillon, le retoucher | Non |
| Soumettre a la moderation (publication) | **Oui** |
| Modifier une annonce pendant sa fenetre | Non |
| Republier une annonce expiree | **Oui** |
| Moderation, boost, compteur de vues | Non |

### Pack Pro

Le Pack Pro (15 000 FCFA / 30 jours) **exonere de tout** : publications et
mises a jour illimitees. C'est ce que sa description promet deja.

Le drapeau `isPro` ne suffit pas a l'evaluer : le pack expire, et aucun
processus ne remet le drapeau a `false`. `readQuota` verifie donc `proUntil`.

## 2. Publicite video

Une video diffusee dans l'application, **1 000 FCFA pour 3 jours**. Gratuite
pour les abonnes Pack Pro.

Une publicite naît en `draft`. Son passage en `active` et sa date d'expiration
sont poses par le serveur — jamais par le client, qui s'offrirait sinon la
diffusion.

## 3. Autres produits

| Produit | Montant | Duree |
|---|---|---|
| `pro` — Pack Pro | 15 000 FCFA | 30 jours |
| `boost` — mise en avant | 5 000 FCFA | 7 jours |
| `ad_video` — publicite video | 1 000 FCFA | 3 jours |
| `publication` — au-dela du quota | 5 % du prix, min. 500 FCFA | 30 jours |

Les trois premiers ont un montant catalogue dans `PRODUCTS`. Le quatrieme est
**calcule** a partir du prix lu dans Firestore : il n'a pas sa place dans le
catalogue, et son montant n'est jamais recu du client.

---

## Ou vit chaque regle

| Element | Emplacement | Pourquoi la |
|---|---|---|
| Montants et durees | `functions/index.js`, `PRODUCTS` | Un tarif client serait modifiable |
| Decompte du quota | `onPropertyWritten` | Un compteur client repartirait de zero |
| Ouverture de la fenetre | `onPropertyWritten` | Le client ne peut pas ecrire `visibleUntil` |
| Expiration des annonces | `expireVisibleProperties`, toutes les 24 h | Sans balayage, la duree n'aurait aucune portee |
| Expiration des publicites | `expireAdvertisements`, toutes les 6 h | Idem |
| Octroi apres paiement | `grantProduct`, depuis le webhook | Accorder a l'initiation permettrait d'abandonner le paiement |
| Interdiction d'ecriture | `firestore.rules` | Derniere barriere si une fonction est contournee |

### Collections en ecriture serveur exclusive

- `publicationQuotas/{uid}` — lecture par le titulaire, ecriture `if false`.
  Un proprietaire capable de remettre son compteur a zero publierait
  gratuitement sans fin.
- `transactions/{reference}` — ecriture `if false`.
- Champs proteges sur `properties` : `visibleUntil`, `boostedUntil`, `views`.
- Champs proteges sur `advertisements` : `status`, `visibleUntil`.

---

## Ce que voit le proprietaire

Le bandeau `PublicationQuotaBanner` annonce la regle **avant** la saisie, et
non au moment de valider : decouvrir des frais apres avoir renseigne une
annonce entiere est la meilleure facon de perdre un proprietaire.

Il affiche, selon le cas : les operations gratuites restantes, le montant
exact du pour l'annonce en cours, ou la couverture par le Pack Pro. Toutes ces
valeurs viennent de `getPublicationQuota` — les recalculer dans l'application
creerait une seconde source de verite, et l'ecart se decouvrirait devant
l'ecran de paiement.

---

## Points ouverts

- **Logos des operateurs** : Orange Money et MTN existent en domaine public
  sur Wikimedia Commons ; Moov n'y figure qu'en CC BY-SA sous la marque Flooz,
  et le fichier « Wave » disponible appartient a une societe birmane homonyme.
  Les quatre fichiers officiels sont attendus dans
  `assets/images/operators/` ; le selecteur affiche d'ici la un repli aux
  couleurs de la marque.
- **Migration** : les annonces publiees avant l'introduction de
  `visibleUntil` n'ont pas de fenetre. Elles seront traitees comme expirees a
  leur prochaine ecriture, ce qui consommera une operation. Un script de
  reprise leur attribuant une fenetre initiale reste a ecrire.
