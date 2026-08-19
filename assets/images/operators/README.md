# Logos des operateurs Mobile Money

Un fichier PNG par operateur, nomme d'apres le champ `code` de
`MobileMoneyOperator` (lib/services/payment_service.dart) : le selecteur les
charge par ce nom, sans qu'aucun code n'ait a changer.

| Fichier | Operateur | Etat |
|---|---|---|
| `wave.png` | Wave | present |
| `orange_money.png` | Orange Money | present |
| `mtn_money.png` | MTN MoMo | present |
| `moov_money.png` | Moov Money | present |

## Provenance

Wave, Orange Money et MTN proviennent de la documentation API Marchand de
GeniusPay, le prestataire de paiement de la plateforme ; Moov Money a ete
fourni separement. C'est la source a privilegier : ce sont les
visuels que l'operateur fournit lui-meme a ses marchands pour signaler les
moyens de paiement acceptes.

Les fichiers d'origine sont des SVG contenant une image matricielle encodee en
base64, clippee en cercle. `flutter_svg` gere mal ce cas : l'image integree a
donc ete extraite et enregistree en PNG, puis mise au carre — `wave.svg`
etait au format 256x158, ce qui aurait donne une vignette plus petite que les
autres dans le selecteur. Le complement reprend la couleur de fond du logo,
echantillonnee dans un coin ; le laisser transparent aurait laisse deux bandes
claires visibles.

## Ajouter ou remplacer un logo

Deposer le PNG dans ce dossier sous le nom attendu — carre, cote minimum
200 px. Aucune autre modification n'est necessaire : le selecteur le detecte
au chargement.

Un fichier absent n'est pas une erreur : la tuile affiche alors l'initiale de
l'operateur sur sa couleur de marque (`brandColor` dans l'enumeration), et le
paiement reste parfaitement fonctionnel.

## Pourquoi ces fichiers ne peuvent pas etre approximes

Ce sont des marques deposees. Elles ne peuvent etre ni redessinees de memoire,
ni reprises d'une source approchante : un logo faux sur un ecran de paiement
est pire que pas de logo. Wikimedia Commons, par exemple, heberge un fichier
« WaveMoney » qui appartient a une societe birmane homonyme, sans aucun lien
avec le Wave ivoirien.
