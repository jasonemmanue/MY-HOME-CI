# Logos des operateurs Mobile Money

Deposer ici les quatre logos officiels, en PNG a fond transparent, cote
minimum 256 px :

    wave.png
    orange_money.png
    mtn_money.png
    moov_money.png

Les noms de fichiers correspondent au champ `code` de `MobileMoneyOperator`
(lib/services/payment_service.dart) : le selecteur les charge par ce nom, sans
qu'aucun code n'ait a changer.

Tant qu'un fichier est absent, le selecteur affiche l'initiale de l'operateur
sur sa couleur de marque. Aucune erreur n'est levee.

## Pourquoi ils ne sont pas deja la

Ce sont des marques deposees. Elles ne peuvent etre ni redessinees de memoire,
ni reprises d'une source approximative : un logo faux sur un ecran de paiement
est pire que pas de logo.

Recherche faite sur Wikimedia Commons :

| Operateur | Etat |
|---|---|
| Orange Money | `Logo Orange Money.svg`, domaine public — reutilisable |
| MTN | `MTN Logo.svg`, domaine public — reutilisable |
| Moov | n'existe qu'en CC BY-SA, sous la marque *Flooz* — attribution et partage a l'identique obligatoires |
| Wave | le fichier `WaveMoney.png` appartient a une societe birmane homonyme, sans lien avec le Wave ivoirien |

En tant que marchand accepte par ces operateurs, vous disposez de leurs kits
de marque officiels : c'est la source a privilegier pour les quatre.
