// Dossier de fourniture My Home CI — ce que le client rassemble et remet a
// ses prestataires avant la publication sur les stores.
//
// Meme charte que generate_docx.js et les deux documents de budget. Le parti
// pris est celui d'un bon de commande : chaque lot dit qui produit quoi, dans
// quel format exact, et ce qui se passe si la contrainte n'est pas tenue —
// une specification approximative se paie en allers-retours.
//
//   node generate_prestataires_docx.js

const docx = require('docx');
const fs = require('fs');
const path = require('path');

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, WidthType, BorderStyle,
} = docx;

const PRIMARY = '2E7D5B';
const SECONDARY = 'F5A623';
const DARK = '1A1A2E';
const GRAY = '6B7280';
const LIGHT_BG = 'F0F4F2';
const ALERT_BG = 'FDF3E3';
const WHITE = 'FFFFFF';

// ── Helpers ────────────────────────────────────────────────────────────────

function titre(text) {
  return new Paragraph({
    spacing: { before: 0, after: 60 },
    children: [new TextRun({ text, bold: true, size: 40, color: PRIMARY, font: 'Calibri' })],
  });
}

function sousTitre(text) {
  return new Paragraph({
    spacing: { before: 0, after: 260 },
    children: [new TextRun({ text, size: 20, color: GRAY, font: 'Calibri' })],
  });
}

function h1(text) {
  return new Paragraph({
    spacing: { before: 300, after: 120 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: PRIMARY } },
    children: [new TextRun({ text, bold: true, size: 26, color: PRIMARY, font: 'Calibri' })],
  });
}

function h2(text) {
  return new Paragraph({
    spacing: { before: 200, after: 70 },
    children: [new TextRun({ text, bold: true, size: 21, color: DARK, font: 'Calibri' })],
  });
}

function p(text, opts = {}) {
  const {
    bold = false, italic = false, size = 19, color = DARK,
    alignment = AlignmentType.JUSTIFIED, before = 50, after = 50,
  } = opts;
  return new Paragraph({
    alignment,
    spacing: { before, after },
    children: [new TextRun({ text, bold, italic, size, color, font: 'Calibri' })],
  });
}

function puce(label, rest = '') {
  return new Paragraph({
    numbering: { reference: 'bullets', level: 0 },
    spacing: { before: 30, after: 30 },
    children: [
      new TextRun({ text: label, bold: true, size: 19, color: DARK, font: 'Calibri' }),
      new TextRun({ text: rest, size: 19, color: DARK, font: 'Calibri' }),
    ],
  });
}

function encadre(titreEncadre, texte) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: SECONDARY },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: SECONDARY },
      left: { style: BorderStyle.SINGLE, size: 12, color: SECONDARY },
      right: { style: BorderStyle.SINGLE, size: 2, color: SECONDARY },
      insideHorizontal: { style: BorderStyle.NONE },
      insideVertical: { style: BorderStyle.NONE },
    },
    rows: [new TableRow({
      children: [new TableCell({
        shading: { fill: ALERT_BG },
        margins: { top: 90, bottom: 90, left: 160, right: 160 },
        children: [
          new Paragraph({
            spacing: { after: 40 },
            children: [new TextRun({ text: titreEncadre, bold: true, size: 19, color: '8A5A00', font: 'Calibri' })],
          }),
          new Paragraph({
            alignment: AlignmentType.JUSTIFIED,
            children: [new TextRun({ text: texte, size: 18, color: DARK, font: 'Calibri' })],
          }),
        ],
      })],
    })],
  });
}

function tableau(entetes, lignes, largeurs) {
  const cellule = (text, opts = {}) => {
    const { bold = false, fill = null, color = DARK } = opts;
    return new TableCell({
      shading: fill ? { fill } : undefined,
      margins: { top: 60, bottom: 60, left: 110, right: 110 },
      children: [new Paragraph({
        alignment: AlignmentType.LEFT,
        children: [new TextRun({ text, bold, size: 17, color, font: 'Calibri' })],
      })],
    });
  };

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: largeurs,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: 'D5DDD8' },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: 'D5DDD8' },
      left: { style: BorderStyle.NONE },
      right: { style: BorderStyle.NONE },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 1, color: 'E3E9E5' },
      insideVertical: { style: BorderStyle.NONE },
    },
    rows: [
      new TableRow({
        tableHeader: true,
        children: entetes.map((h) => cellule(h, { bold: true, fill: PRIMARY, color: WHITE })),
      }),
      ...lignes.map((r, ri) => new TableRow({
        children: r.map((c) => cellule(c, { fill: ri % 2 === 1 ? 'FAFBFA' : null })),
      })),
    ],
  });
}

function espace(h = 140) {
  return new Paragraph({ spacing: { before: h, after: 0 } });
}

// ══════════════════════════════════════════════════════════════════════════

const children = [];

children.push(titre('My Home CI — Dossier de fourniture'));
children.push(sousTitre(
  "Ce que vous rassemblez et remettez a vos prestataires avant la publication " +
  "sur Google Play et l'App Store · Version du 16 aout 2026"
));

children.push(p(
  "L'application et le back-office sont construits, testes et connectes a leur backend. " +
  "Ce qui manque pour publier n'est plus du developpement : ce sont des images, des textes, " +
  "des documents juridiques et des acces. Ce document liste ces elements un par un, avec le " +
  "format exact attendu, pour qu'ils soient commandes en une fois plutot qu'au fil des refus " +
  "des stores."
));

children.push(p(
  "Chaque lot est autonome : vous pouvez le transmettre tel quel au prestataire concerne. " +
  "Les dimensions et les poids ne sont pas indicatifs — ils viennent des exigences de Google " +
  "et d'Apple, ou des limites techniques deja posees dans le code. Un fichier hors format est " +
  "refuse au depot, pas a la revue : la perte de temps est immediate."
));

// ── Recapitulatif ─────────────────────────────────────────────────────────

children.push(h1('Recapitulatif des lots'));

children.push(tableau(
  ['Lot', 'Qui le produit', 'Contenu', 'Delai a prevoir'],
  [
    ['1. Icones et identite', 'Graphiste', '5 fichiers', '3 a 5 jours'],
    ['2. Captures des stores', 'Graphiste', '4 series de captures', '3 a 5 jours'],
    ['3. Textes des fiches', 'Redacteur', '8 textes calibres', '2 a 3 jours'],
    ['4. Contenu de demarrage', 'Photographe / vous', '10 quartiers, 8 a 12 annonces', '1 a 2 semaines'],
    ['5. Documents juridiques', 'Juriste', '5 documents', '1 a 3 semaines'],
    ['6. Comptes, cles et acces', 'Vous seul', '11 elements', 'compter les delais administratifs'],
  ],
  [2100, 1800, 3100, 2200]
));

children.push(espace());
children.push(encadre(
  'A lancer en premier, avant tout le reste',
  "Le lot 6 contient deux demarches a delai administratif incompressible : la verification " +
  "d'identite du compte Google Play prend plusieurs jours, la creation du compte Apple " +
  "Developer aussi. Elles ne dependent d'aucun autre lot. Les lancer aujourd'hui evite " +
  "d'attendre avec des visuels finis et nulle part ou les deposer."
));

// ── Lot 1 ─────────────────────────────────────────────────────────────────

children.push(h1('Lot 1 — Icones et identite visuelle'));

children.push(p(
  "Le logo existe deja et sert dans l'application : il n'est pas a refaire. Ce lot en produit " +
  "les declinaisons exigees par les deux stores et par le systeme Android, qui ont chacun " +
  "leurs contraintes propres."
));

children.push(tableau(
  ['Element', 'Format exact', 'Contraintes'],
  [
    [
      'Icone adaptative Android — avant-plan',
      '432 x 432 px, PNG, fond transparent',
      "Le motif doit tenir dans un cercle centre de 264 px : Android rogne le reste selon la forme choisie par le constructeur",
    ],
    [
      'Icone adaptative Android — arriere-plan',
      '432 x 432 px, PNG, aplat plein',
      'Aucune transparence, aucun motif signifiant : ce calque bouge en parallaxe',
    ],
    [
      'Icone Google Play',
      '512 x 512 px, PNG 32 bits',
      'Sans transparence, sans coins arrondis, sans ombre portee — le store les applique lui-meme',
    ],
    [
      'Icone App Store',
      '1024 x 1024 px, PNG',
      'Sans canal alpha, sans coins arrondis, sans ombre. Un canal alpha residuel est un refus automatique au depot',
    ],
    [
      'Icone de notification Android',
      '96 x 96 px, PNG transparent',
      'Silhouette blanche uniquement : Android recolore l\'icone. Une icone couleur apparait en carre blanc',
    ],
  ],
  [2600, 2400, 4200]
));

children.push(espace());
children.push(p(
  "Le fichier source vectoriel du logo est a demander au prestataire dans tous les cas : sans " +
  "lui, chaque nouvelle taille exigee par une future version d'Android ou d'iOS repart d'un " +
  "agrandissement de pixels.",
  { italic: true, size: 18, color: GRAY }
));

// ── Lot 2 ─────────────────────────────────────────────────────────────────

children.push(h1('Lot 2 — Captures des fiches store'));

children.push(p(
  "Les captures brutes de l'application peuvent etre produites depuis un appareil de test : " +
  "elles servent de matiere premiere. Le travail du graphiste consiste a les mettre en scene — " +
  "cadre de telephone, titre court, fond aux couleurs de la marque — car une capture brute " +
  "convertit mal en telechargement."
));

children.push(h2('Google Play'));
children.push(tableau(
  ['Element', 'Format', 'Quantite'],
  [
    ['Image de mise en avant', '1024 x 500 px, JPEG ou PNG 24 bits, sans transparence', '1'],
    ['Captures telephone', '1080 x 1920 px recommande — cote min 320 px, max 3840 px, ratio max 2:1', '4 a 8'],
    ['Captures tablette 7 pouces', '1200 x 1920 px', '2 a 4'],
    ['Captures tablette 10 pouces', '1600 x 2560 px', '2 a 4'],
  ],
  [2900, 5200, 1100]
));

children.push(espace(120));
children.push(p(
  "Les captures tablette ne sont pas optionnelles : le cahier des charges declare l'application " +
  "compatible tablette, et Google refuse cette declaration sans visuels correspondants. Aucun " +
  "texte ne doit se trouver a moins de 100 px des bords de l'image de mise en avant, qui est " +
  "recadree differemment selon les surfaces du store.",
  { size: 18 }
));

children.push(h2('App Store'));
children.push(tableau(
  ['Taille de reference', 'Format', 'Quantite'],
  [
    ['iPhone 6,7 pouces', '1290 x 2796 px', '3 a 10 — obligatoire'],
    ['iPhone 6,5 pouces', '1242 x 2688 px', '3 a 10'],
    ['iPad Pro 12,9 pouces', '2048 x 2732 px', '3 a 10 — obligatoire si iPad'],
  ],
  [2900, 3000, 3300]
));

children.push(espace(120));
children.push(p(
  "Ecrans a mettre en avant, dans cet ordre : la carte avec les logements geolocalises, la " +
  "fiche detaillee d'un logement, la conversation avec un proprietaire, la recherche filtree, " +
  "et le tableau de bord proprietaire. Ce sont les cinq ecrans qui portent la promesse du " +
  "produit."
));

// ── Lot 3 ─────────────────────────────────────────────────────────────────

children.push(h1('Lot 3 — Textes des fiches store'));

children.push(p(
  "Les limites de caracteres sont strictes et comptees espaces compris. Un texte trop long est " +
  "tronque sans avertissement au milieu d'un mot."
));

children.push(tableau(
  ['Texte', 'Limite', 'Remarque'],
  [
    ['Titre Google Play', '30 caracteres', '« My Home CI » en occupe 11, il reste de la place pour un qualificatif'],
    ['Description courte Google Play', '80 caracteres', "C'est la seule phrase visible dans les resultats de recherche"],
    ['Description longue Google Play', '4 000 caracteres', 'Indexee par le moteur du store : y placer « location Abidjan », « logement Cote d\'Ivoire »'],
    ['Nom App Store', '30 caracteres', 'Doit correspondre au nom affiche sur l\'appareil'],
    ['Sous-titre App Store', '30 caracteres', "Affiche sous le nom, ne repete pas le nom"],
    ['Mots-cles App Store', '100 caracteres', 'Separes par des virgules sans espace ; les espaces perdus sont des mots-cles perdus'],
    ['Description App Store', '4 000 caracteres', "Non indexee, contrairement a Google Play : elle sert a convaincre, pas a referencer"],
    ['Nouveautes de la version', '4 000 caracteres', 'Obligatoire des la premiere mise a jour'],
  ],
  [2700, 1500, 5000]
));

children.push(espace());
children.push(encadre(
  'Le point le plus sensible de la revue Apple',
  "L'application propose deux services payants aux proprietaires. Sur iOS, ils sont regles par " +
  "Mobile Money dans le navigateur, hors achat integre. C'est le point de la ligne directrice " +
  "3.1.1 qui declenche le plus de refus. L'argumentaire doit etre redige a l'avance et joint " +
  "aux notes de revue : le loyer ne transite jamais par l'application, et les deux services " +
  "factures s'adressent a des professionnels de l'immobilier, non a des consommateurs."
));

// ── Lot 4 ─────────────────────────────────────────────────────────────────

children.push(h1('Lot 4 — Contenu de demarrage'));

children.push(p(
  "La base est aujourd'hui vide. Une place de marche vide ne convertit pas : le premier " +
  "visiteur qui ouvre l'application sur un ecran sans annonce ne revient pas. Ce lot est le " +
  "plus long a produire et le plus determinant commercialement."
));

children.push(h2('Photos de quartiers — 10 fichiers'));
children.push(p(
  "Un visuel par quartier, en 1600 x 900 px (16:9), JPEG. Les dix quartiers deja cables dans " +
  "l'application sont : Cocody, Plateau, Marcory, Yopougon, Treichville, Adjame, Abobo, " +
  "Koumassi, Port-Bouet et Bingerville. Une vue reconnaissable du quartier vaut mieux qu'une " +
  "image d'illustration generique — c'est le repere qui declenche le clic."
));

children.push(h2('Annonces de demarrage — 8 a 12 logements'));
children.push(p('Pour chaque logement, le dossier doit contenir :'));
children.push(puce('5 a 8 photos ', "en JPEG, 1280 x 960 px minimum, ratio 4:3, moins de 5 Mo par fichier. Cette limite de 5 Mo est imposee par les regles de securite du stockage : un fichier plus lourd est rejete par le serveur."));
children.push(puce('Le type de bien ', "parmi : Studio, Appartement, Villa, Chambre, Duplex, Terrain, Bureau, Maison."));
children.push(puce('Le loyer mensuel ', "en francs CFA, nombre entier strictement positif."));
children.push(puce('Le quartier et la ville, ', "et l'adresse ou un point sur la carte : sans coordonnees, le logement n'apparait ni sur la carte ni dans les recherches par rayon."));
children.push(puce('Une description ', "d'au moins 20 caracteres — en dessous, la publication est refusee par l'application."));
children.push(puce('Les equipements ', "parmi la liste proposee : eau courante, electricite, climatisation, internet, parking, gardien, et les suivants."));
children.push(puce("L'autorisation ecrite du proprietaire ", "pour la diffusion des photos et de l'adresse. Sans elle, la plateforme s'expose a une reclamation des la mise en ligne."));

children.push(espace(120));
children.push(p(
  "Ces annonces peuvent etre saisies directement depuis l'application par un compte " +
  "proprietaire, puis validees depuis le back-office. Aucun import de masse n'est necessaire " +
  "a ce volume.",
  { italic: true, size: 18, color: GRAY }
));

// ── Lot 5 ─────────────────────────────────────────────────────────────────

children.push(h1('Lot 5 — Documents juridiques'));

children.push(p(
  "Les textes existent deja dans l'application, mais les deux stores exigent qu'ils soient " +
  "aussi accessibles a une adresse web publique, consultable sans compte. Ils doivent etre " +
  "relus par un juriste connaissant le droit ivoirien."
));

children.push(tableau(
  ['Document', 'Exige par', 'Points a couvrir imperativement'],
  [
    [
      'Politique de confidentialite',
      'Google Play, App Store',
      "Donnees collectees (localisation, photos, messages, identifiants), duree de conservation, sous-traitants (Google Firebase, GeniusPay), droit d'acces et de suppression, contact",
    ],
    [
      "Conditions generales d'utilisation",
      'Les deux stores',
      "Clause de non-responsabilite : la plateforme met en relation, elle n'est pas agent immobilier et ne garantit pas les annonces",
    ],
    [
      'Conditions generales de vente',
      'Pratique commerciale',
      'Les deux produits payants (Pack Pro 15 000 F / 30 jours, mise en avant 5 000 F / 7 jours) et la politique de remboursement',
    ],
    [
      'Mentions legales',
      'Droit ivoirien',
      'Editeur, hebergeur, contact support, numero de registre du commerce',
    ],
    [
      'Declaration ARTCI',
      'Droit ivoirien',
      "L'ARTCI encadre le traitement des donnees personnelles en Cote d'Ivoire : la declaration est a valider avec un juriste local",
    ],
  ],
  [2400, 1900, 4900]
));

children.push(espace(120));
children.push(p(
  "Ces documents doivent etre publies sur le domaine du projet avant la soumission : les " +
  "formulaires des deux stores demandent une adresse web qui repond, pas un fichier joint.",
  { size: 18 }
));

// ── Lot 6 ─────────────────────────────────────────────────────────────────

children.push(h1('Lot 6 — Comptes, cles et acces'));

children.push(p(
  "Ce lot ne se delegue pas : il engage financierement et juridiquement le titulaire du " +
  "projet. Un prestataire qui cree ces comptes a son nom devient proprietaire de " +
  "l'application aux yeux des stores."
));

children.push(tableau(
  ['Element', 'Cout', 'Consequence en son absence'],
  [
    ['Compte Google Play Developer', '25 $ une fois', "Aucune publication Android. La verification d'identite prend plusieurs jours"],
    ['Compte Apple Developer', '99 $ par an', "Aucune publication iOS. Un oubli de renouvellement retire l'application du store"],
    ['Cle Google Maps Android', 'a l\'usage', 'Carte vide, sans message d\'erreur. A restreindre par nom de paquet et empreinte SHA-1'],
    ['Cle Google Maps iOS', 'a l\'usage', "Idem cote iOS. A restreindre par identifiant de l'application"],
    ['Keystore de signature Android', 'gratuit', "Google Play refuse l'archive. Le keystore perdu ne se remplace pas : plus aucune mise a jour possible"],
    ['Cle d\'authentification APNs', 'gratuit', 'Aucune notification push sur iOS'],
    ['Cle API App Store Connect', 'gratuit', "La chaine de publication automatisee echoue. A nommer exactement « My Home CI ASC »"],
    ['Fournisseur Google active sur Firebase', 'gratuit', "La connexion Google iOS ouvre le navigateur et n'en revient jamais"],
    ['Domaine myhomeci.ci', '30 000 a 35 000 F par an', 'Les documents juridiques et les liens de paiement par email n\'ont nulle part ou vivre'],
    ['Sous-domaine admin.myhomeci.ci', 'inclus', "Le back-office n'est pas joignable ; les liens de paiement iOS ne menent nulle part"],
    ['Compte de test pour la revue Apple', 'gratuit', "Refus automatique : Apple doit pouvoir se connecter et parcourir l'application"],
  ],
  [3000, 1700, 4500]
));

children.push(espace());
children.push(encadre(
  'Le keystore est le seul element irremplacable',
  "Tout le reste se recree. Le keystore de signature Android, non : il identifie l'application " +
  "aupres de Google Play pour toute sa vie. Perdu, il oblige a publier une application " +
  "differente, sans les utilisateurs ni les avis de la premiere. Le sauvegarder a deux endroits " +
  "distincts, avec ses mots de passe, des sa creation."
));

// ── Contraintes communes ──────────────────────────────────────────────────

children.push(h1('Charte a respecter'));

children.push(p(
  "Tout visuel produit doit s'aligner sur l'identite deja appliquee dans l'application, sans " +
  "quoi la fiche du store et le produit paraissent venir de deux marques differentes."
));

children.push(tableau(
  ['Element', 'Valeur'],
  [
    ['Couleur primaire', 'Vert emeraude #2E7D5B'],
    ['Couleur secondaire', 'Orange dore #F5A623'],
    ['Police des titres', 'Poppins'],
    ['Police du texte courant', 'Inter'],
    ['Rayon des coins', '12 pixels'],
    ['Langue de toute l\'interface', 'Francais'],
    ['Themes', 'Clair et sombre — les captures peuvent exploiter les deux'],
  ],
  [3200, 6000]
));

children.push(h2('Nommage des fichiers'));
children.push(p(
  "Un nom de fichier explicite evite un aller-retour par lot. Format demande : " +
  "lot_element_dimensions.extension — par exemple icone_play_512x512.png, " +
  "capture_iphone67_carte_1290x2796.png, quartier_cocody_1600x900.jpg. Livraison en un " +
  "seul dossier compresse par lot."
));

// ── Hors perimetre ────────────────────────────────────────────────────────

children.push(h1("Ce qui n'est pas demande"));

children.push(p(
  "Pour eviter de payer un travail deja fait :"
));
children.push(puce("Les maquettes d'ecrans. ", "Les vingt ecrans de l'application sont construits et valides ; il n'y a pas de refonte prevue."));
children.push(puce('Le logo. ', "Il existe, il est integre, il sert deja dans l'ecran d'accueil et l'ecran de connexion. Seules ses declinaisons aux formats des stores sont a produire."));
children.push(puce('Un site web vitrine. ', "Seules deux adresses publiques sont necessaires : les documents juridiques et le back-office. Une page unique suffit pour les premiers."));
children.push(puce('La traduction. ', "L'application est monolingue francais, par choix, et le decoupage par langue est desactive dans la configuration de publication."));

children.push(espace(160));
children.push(p(
  "Document etabli le 16 aout 2026, apres recette de l'application sur appareil reel et mise " +
  "en service du backend. Les contraintes techniques citees proviennent des exigences " +
  "publiees par Google et Apple a cette date et des regles de securite deployees sur le " +
  "projet. L'etat d'avancement detaille figure dans ROADMAP_TECHNIQUE.md.",
  { italic: true, size: 17, color: GRAY }
));

// ══════════════════════════════════════════════════════════════════════════

const doc = new Document({
  creator: 'My Home CI',
  title: 'Dossier de fourniture - My Home CI',
  description: "Elements a rassembler et a remettre aux prestataires avant publication",
  numbering: {
    config: [{
      reference: 'bullets',
      levels: [{
        level: 0,
        format: docx.LevelFormat.BULLET,
        text: '—',
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 460, hanging: 280 } } },
      }],
    }],
  },
  sections: [{
    properties: { page: { margin: { top: 900, bottom: 800, left: 1000, right: 1000 } } },
    children,
  }],
});

const output = path.join(__dirname, 'DOSSIER_FOURNITURE_MY_HOME_CI.docx');
Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(output, buffer);
  console.log('Document genere : ' + output);
  console.log('Taille : ' + Math.round(buffer.length / 1024) + ' Ko');
});
