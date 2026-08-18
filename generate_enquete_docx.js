// Fiche d'enquete terrain My Home CI — support de collecte pour les equipes
// qui visitent les proprietaires avant le lancement.
//
// Le document sert de reference a la conception du formulaire : chaque
// question y est rattachee au champ que l'application attend, avec sa
// contrainte. Une donnee collectee hors contrainte est une donnee a
// recollecter — c'est-a-dire une seconde visite.
//
// Les listes fermees, les seuils et les limites de taille sont recopies du
// code (lib/config/constants.dart, lib/models/property.dart, storage.rules).
// Les modifier ici sans les modifier la-bas produit des fiches inexploitables.
//
//   node generate_enquete_docx.js

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

children.push(titre("My Home CI — Fiche d'enquete terrain"));
children.push(sousTitre(
  'Donnees a collecter aupres des proprietaires, en vue du lancement · ' +
  'Reference pour la conception du formulaire · Version du 17 aout 2026'
));

children.push(p(
  "Ce document ne se remplit pas : il decrit ce que le formulaire d'enquete doit " +
  "demander, et pourquoi. Chaque question y est rattachee au champ que " +
  "l'application attend, avec sa contrainte exacte."
));

children.push(p(
  "L'objectif est double. Constituer un vivier de proprietaires prets a publier des " +
  "le lancement — une place de marche vide ne convertit pas. Et recueillir, en une " +
  "seule visite, tout ce qu'il faut pour creer le compte et la premiere annonce sans " +
  "avoir a rappeler. Une donnee recueillie hors contrainte est une donnee a " +
  "recollecter, c'est-a-dire une seconde visite."
));

children.push(espace(120));
children.push(encadre(
  'A dire en ouverture de visite, avant toute question',
  "« Nous preparons le lancement d'une application qui met en relation directe " +
  "proprietaires et locataires, sans demarcheur. Le loyer ne passe jamais par " +
  "l'application. Je note vos coordonnees et les caracteristiques du logement pour " +
  "vous recontacter au lancement et publier votre annonce si vous le souhaitez. Vous " +
  "pouvez demander la suppression de ces informations a tout moment. » " +
  "Sans cet accord explicite, la collecte est illicite : l'ARTCI encadre le " +
  "traitement des donnees personnelles en Cote d'Ivoire, et un fichier constitue " +
  "sans consentement ne pourra pas etre exploite au lancement."
));

// ── Section A ─────────────────────────────────────────────────────────────

children.push(h1('Section A — Le proprietaire'));

children.push(p(
  "Ces informations creeront son compte. L'email est l'identifiant de connexion : " +
  "sans lui, aucun compte n'est possible. Le numero de telephone n'est pas verifie " +
  "par SMS, mais il sert de numero de paiement Mobile Money par defaut — d'ou la " +
  "question sur l'operateur."
));

children.push(tableau(
  ['Question', 'Format attendu', 'Pourquoi / contrainte'],
  [
    ['Nom complet', 'Texte, 3 caracteres minimum', "Affiche publiquement sur l'annonce. Prenom et nom, pas de surnom"],
    ['Adresse email', 'email@exemple.com', "Identifiant de connexion. Obligatoire. La faire relire par le proprietaire"],
    [
      'Numero de telephone',
      '10 chiffres, commencant par 0',
      "Deviendra le numero a debiter propose par defaut. Depuis 2021 tous les numeros ivoiriens font 10 chiffres et commencent par 0 : un numero a 8 chiffres est un ancien format, a faire preciser",
    ],
    [
      'Operateur Mobile Money habituel',
      'Wave / Orange Money / MTN Money / Moov Money',
      "Permet de preselectionner le bon operateur. Wave peut s'adosser a un numero de n'importe quel reseau : la question se pose meme quand le prefixe semble evident",
    ],
    ['Second numero (facultatif)', '10 chiffres', "Utile si le premier est celui d'un tiers ou d'un gestionnaire"],
    [
      'Qualite',
      'Proprietaire / Gestionnaire / Heritier / Autre',
      "Un gestionnaire n'a pas toujours le droit de publier : le noter evite un litige a la mise en ligne",
    ],
    [
      'Nombre de biens detenus ou geres',
      'Nombre entier',
      "Segmente l'offre : au-dela de trois biens, le Pack Pro a 15 000 F par mois devient l'argument principal",
    ],
    [
      "Dispose d'une piece d'identite",
      'Oui / Non',
      "Le badge « proprietaire verifie » l'exigera. Ne PAS photographier la piece sur le terrain — voir la derniere section",
    ],
    ['Langue de travail', 'Francais / Autre — preciser', "L'application est monolingue francais : reperer les cas ou un accompagnement sera necessaire"],
  ],
  [2400, 2300, 4500]
));

// ── Section B ─────────────────────────────────────────────────────────────

children.push(h1('Section B — Le logement'));

children.push(p(
  "Une fiche par logement. Si le proprietaire en possede plusieurs, dupliquer cette " +
  "section : l'application traite chaque bien comme une annonce independante."
));

children.push(h2('Identification et prix'));
children.push(tableau(
  ['Question', 'Format attendu', 'Pourquoi / contrainte'],
  [
    [
      "Titre de l'annonce",
      'Texte, 5 caracteres minimum',
      "Exemple : « Studio meuble a Cocody Angre ». Le rediger sur place avec le proprietaire, pas apres coup",
    ],
    [
      'Type de bien',
      'Studio, Appartement, Villa, Chambre, Duplex, Terrain, Bureau ou Maison',
      "Liste fermee — aucune autre valeur n'existe dans l'application. Une case « Autre » produirait une donnee inexploitable",
    ],
    [
      'Description',
      'Texte libre, 20 caracteres minimum',
      "En dessous de 20 caracteres, la publication est refusee. Viser trois a quatre phrases : environnement, etat, voisinage",
    ],
    [
      'Loyer mensuel',
      'Nombre entier de francs CFA, strictement positif',
      'Sans centimes ni separateur. Un loyer a zero est refuse',
    ],
    [
      'Charges comprises',
      'Oui / Non — si non, lesquelles et combien',
      "L'application n'a pas de champ dedie : l'information doit entrer dans la description, sinon elle est perdue",
    ],
    [
      'Caution demandee',
      'Nombre de mois',
      'Meme remarque : a porter dans la description. C\'est le premier motif d\'abandon d\'un locataire',
    ],
    ['Disponible a partir du', 'Date', "Un bien disponible dans six mois n'est pas a publier au lancement"],
  ],
  [2300, 2600, 4300]
));

children.push(h2('Localisation'));

children.push(p(
  "C'est le point le plus souvent bacle, et le plus couteux a rattraper : sans " +
  "coordonnees, le logement n'apparait ni sur la carte ni dans les recherches par " +
  "rayon, qui sont l'argument central du produit."
));

children.push(tableau(
  ['Question', 'Format attendu', 'Pourquoi / contrainte'],
  [
    [
      'Coordonnees GPS',
      'Latitude et longitude, cinq decimales',
      'A relever DEVANT le logement, pas depuis le vehicule ni de memoire. Obligatoire pour publier',
    ],
    [
      'Quartier',
      'Cocody, Plateau, Marcory, Yopougon, Treichville, Adjame, Abobo, Koumassi, Port-Bouet, Bingerville — ou autre a preciser',
      "Obligatoire pour publier. Les dix premiers sont deja dans l'application ; tout autre devra y etre ajoute",
    ],
    [
      'Ville',
      'Abidjan, Bouake, Yamoussoukro, San-Pedro, Daloa, Korhogo, Man ou Gagnoa',
      'Liste fermee, comme le type de bien',
    ],
    [
      'Adresse ou point de repere',
      'Texte libre',
      "En Cote d'Ivoire l'adresse formelle est souvent absente : un point de repere (« derriere la pharmacie X ») vaut mieux qu'un numero de rue invente",
    ],
  ],
  [2300, 2900, 4000]
));

children.push(h2('Caracteristiques'));
children.push(tableau(
  ['Question', 'Format attendu', 'Remarque'],
  [
    ['Surface', 'Nombre, en metres carres', 'Estimee si non mesuree — le noter'],
    ['Nombre de pieces', 'Nombre entier', 'Hors cuisine et sanitaires, usage local'],
    ['Salles de bain', 'Nombre entier', ''],
    ['Etage', 'Nombre entier — 0 pour le rez-de-chaussee', ''],
    ['Meuble', 'Oui / Non', 'Determine une part importante du loyer'],
    [
      'Equipements presents',
      'Cases a cocher',
      "Liste exacte de l'application : Eau courante, Electricite, Climatisation, Internet/WiFi, Parking, Gardien, Piscine, Balcon, Cuisine equipee, Meuble",
    ],
  ],
  [2300, 2900, 4000]
));

children.push(h2('Photographies'));
children.push(p(
  "Au moins une photo est exigee pour publier ; en viser cinq a huit. Format JPEG, " +
  "1280 x 960 pixels minimum, moins de 5 Mo par fichier — cette limite est imposee " +
  "par le serveur, un fichier plus lourd est refuse a l'envoi. Prendre dans l'ordre : " +
  "la facade, le sejour, chaque chambre, la cuisine, la salle de bain, la vue " +
  "exterieure. De jour, sans flash, telephone tenu a l'horizontale."
));

children.push(espace(100));
children.push(p(
  "Demander l'autorisation ecrite de diffuser les photos et l'adresse. Sans elle, la " +
  'plateforme s\'expose a une reclamation des la mise en ligne.',
  { bold: true, size: 18 }
));

// ── Section C ─────────────────────────────────────────────────────────────

children.push(h1('Section C — Qualification commerciale'));

children.push(p(
  "Ces reponses n'alimentent aucun champ de l'application : elles servent a savoir " +
  "qui rappeler en premier au lancement, et a verifier que le produit repond a un " +
  'besoin reel plutot qu\'a un besoin suppose.'
));

children.push(tableau(
  ['Question', 'Reponses proposees', "Ce qu'on en fait"],
  [
    [
      'Possede un smartphone',
      'Android / iPhone / Non',
      "Sans smartphone, le proprietaire ne peut pas publier lui-meme : il faudra une saisie assistee. Une reponse honnete ici change le plan de lancement",
    ],
    [
      'Utilise deja Mobile Money',
      'Oui, regulierement / Oui, rarement / Non',
      "Un proprietaire qui n'a jamais paye par Mobile Money ne souscrira pas au Pack Pro sans accompagnement",
    ],
    [
      "Comment loue-t-il aujourd'hui",
      'Demarcheur / Bouche-a-oreille / Facebook ou WhatsApp / Agence / Pancarte',
      'Designe le concurrent reel. La reponse la plus utile de toute la fiche',
    ],
    [
      'Combien lui coute une location aujourd\'hui',
      'Montant ou pourcentage',
      'Point de comparaison direct avec les 15 000 F par mois du Pack Pro',
    ],
    [
      'Delai moyen pour louer un bien',
      'En semaines',
      "La promesse du produit est de le reduire : sans mesure d'aujourd'hui, elle est invendable",
    ],
    [
      'Interet pour le Pack Pro a 15 000 F par mois',
      'Oui / Peut-etre / Non — et pourquoi',
      'Le « pourquoi » compte plus que la reponse. Le noter mot pour mot',
    ],
    [
      "Accepte d'etre recontacte au lancement",
      'Oui / Non',
      "Sans un oui, la fiche ne peut pas etre exploitee. C'est le consentement : il doit etre explicite",
    ],
    [
      'Accepte la publication de son annonce',
      'Oui / Non / A revoir',
      "Distinct du precedent : accepter un appel n'est pas accepter une publication",
    ],
  ],
  [2500, 2700, 4000]
));

// ── Section D ─────────────────────────────────────────────────────────────

children.push(h1("Section D — Renseigne par l'enqueteur"));

children.push(puce("Nom de l'enqueteur ", 'et date de la visite.'));
children.push(puce("Duree de l'entretien ", '— en dessous de dix minutes, une fiche est rarement exploitable.'));
children.push(puce('Qualite du contact ', ': chaleureux, neutre ou reticent. Oriente la relance.'));
children.push(puce('Le proprietaire etait-il present ', "ou l'information vient-elle d'un tiers ? Une fiche renseignee par un voisin est a verifier avant tout usage."));
children.push(puce('Fiche complete ', ': oui / non — si non, ce qui manque et pourquoi.'));
children.push(puce('Photos prises ', ': nombre, et avec quel appareil, pour les retrouver.'));

// ── Contraintes bloquantes ────────────────────────────────────────────────

children.push(h1('Les six conditions sans lesquelles rien ne se publie'));

children.push(p(
  "L'application refuse la publication d'une annonce a laquelle il manque l'un de ces " +
  'elements. Une fiche qui n\'en couvre pas les six est une fiche a completer, donc ' +
  'une seconde visite. A verifier avant de quitter le logement.'
));

children.push(tableau(
  ['Condition', 'Seuil exact'],
  [
    ['Un titre', '5 caracteres minimum'],
    ['Une description', '20 caracteres minimum'],
    ['Un loyer', 'Nombre entier strictement positif'],
    ['Des coordonnees GPS', 'Latitude et longitude, relevees sur place'],
    ['Au moins une photo', 'Une suffit techniquement, cinq a huit sont attendues'],
    ['Un quartier', 'Non vide'],
  ],
  [4200, 5000]
));

// ── Minimisation ──────────────────────────────────────────────────────────

children.push(h1("Ce qu'il ne faut surtout pas collecter"));

children.push(p(
  "Collecter moins protege l'equipe autant que les personnes visitees. Ces elements " +
  "sont a refuser meme lorsqu'ils sont proposes spontanement :"
));

children.push(puce("La piece d'identite, ", "ni photographiee ni recopiee. La verification d'identite se fait plus tard, dans l'application, par un canal prevu pour cela. Une photo de piece dans la galerie d'un telephone de terrain est une fuite qui attend son heure."));
children.push(puce('Les coordonnees bancaires ', "ou un numero de compte. L'application ne les demande jamais : le loyer ne transite pas par la plateforme, et les deux services payants se reglent par Mobile Money."));
children.push(puce('Les donnees des locataires actuels ', "— noms, numeros, montants verses. Ils n'ont donne aucun consentement et ne sont pas partie a l'echange."));
children.push(puce('Les titres de propriete ', 'ou tout document notarie. Hors sujet a ce stade, et lourd de responsabilite en cas de perte.'));

children.push(espace(120));
children.push(encadre(
  'Conservation des fiches',
  'Les fiches papier contiennent des donnees personnelles : elles se rangent, ne ' +
  'circulent pas, et sont detruites une fois saisies. La version numerique doit vivre ' +
  'dans un espace a acces restreint, pas dans une conversation de groupe. Decider des ' +
  'maintenant qui repond a une demande de suppression, et sous quel delai — c\'est une ' +
  'obligation, pas une politesse.'
));

// ── Conseils de terrain ───────────────────────────────────────────────────

children.push(h1('Conseils de terrain'));

children.push(puce('Le GPS met du temps a se fixer. ', "Ouvrir l'application de cartographie a l'arrivee et la laisser tourner pendant l'entretien : la position sera stable au moment de la relever."));
children.push(puce('Sans reseau, la position fonctionne quand meme. ', 'Le GPS ne depend pas de la connexion : une fiche se remplit entierement hors ligne.'));
children.push(puce("Faire relire l'email au proprietaire. ", "C'est l'identifiant de connexion : une lettre fausse et le compte est inutilisable, sans moyen simple de s'en apercevoir."));
children.push(puce('Noter le loyer en chiffres, jamais en toutes lettres. ', '« Cent cinquante mille » se transcrit mal a la saisie.'));
children.push(puce("Une fiche incomplete vaut mieux qu'une fiche inventee. ", "Un champ vide se rappelle ; une valeur approximative se decouvre au lancement, quand un locataire se deplace pour rien."));

children.push(espace(160));
children.push(p(
  'Document etabli le 17 aout 2026. Les listes fermees, les seuils et les limites de ' +
  'taille cites proviennent du code de l\'application — respectivement ' +
  'lib/config/constants.dart, lib/models/property.dart et storage.rules. Ils ' +
  'changeront si le produit change : verifier la coherence avant d\'imprimer une ' +
  'nouvelle serie de fiches.',
  { italic: true, size: 17, color: GRAY }
));

// ══════════════════════════════════════════════════════════════════════════

const doc = new Document({
  creator: 'My Home CI',
  title: "Fiche d'enquete terrain - My Home CI",
  description: 'Donnees a collecter aupres des proprietaires avant le lancement',
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

const output = path.join(__dirname, 'FICHE_ENQUETE_TERRAIN_MY_HOME_CI.docx');
Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(output, buffer);
  console.log('Document genere : ' + output);
  console.log('Taille : ' + Math.round(buffer.length / 1024) + ' Ko');
});
