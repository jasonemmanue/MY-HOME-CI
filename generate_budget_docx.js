// Generateur du document de budget d'exploitation My Home CI.
//
// Reprend la charte et les helpers de generate_docx.js pour que les deux
// documents remis au client aient la meme identite visuelle.
//
//   node generate_budget_docx.js

const docx = require('docx');
const fs = require('fs');
const path = require('path');

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, WidthType, BorderStyle, ImageRun, Footer, PageNumber,
} = docx;

// ── Charte ────────────────────────────────────────────────────────────────
const PRIMARY = '2E7D5B';
const SECONDARY = 'F5A623';
const DARK = '1A1A2E';
const GRAY = '6B7280';
const LIGHT_BG = 'F0F4F2';
const ALERT_BG = 'FDF3E3';
const WHITE = 'FFFFFF';

// ── Taux de conversion ────────────────────────────────────────────────────
// Le franc CFA est arrime a l'euro, pas au dollar : le taux USD/XOF flotte.
// 600 est une valeur prudente arrondie, volontairement au-dessus du taux
// constate, pour ne pas sous-estimer le budget.
const USD = 600;

function fcfa(usd) {
  return Math.round(usd * USD).toLocaleString('fr-FR').replace(/ | /g, ' ');
}

// ── Helpers ───────────────────────────────────────────────────────────────

function emptyPara(spacing = 100) {
  return new Paragraph({ spacing: { before: spacing, after: spacing } });
}

function rule(color = PRIMARY) {
  return new Paragraph({
    spacing: { before: 200, after: 200 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color } },
  });
}

function h1(text) {
  return new Paragraph({
    spacing: { before: 360, after: 200 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: PRIMARY } },
    children: [new TextRun({ text, bold: true, size: 32, color: PRIMARY, font: 'Calibri' })],
  });
}

function h2(text) {
  return new Paragraph({
    spacing: { before: 280, after: 140 },
    children: [new TextRun({ text, bold: true, size: 26, color: '1B5E3B', font: 'Calibri' })],
  });
}

function p(text, opts = {}) {
  const {
    bold = false, italic = false, size = 21, color = DARK,
    alignment = AlignmentType.JUSTIFIED, spacing = {},
  } = opts;
  return new Paragraph({
    alignment,
    spacing: { before: 60, after: 60, ...spacing },
    children: [new TextRun({ text, bold, italic, size, color, font: 'Calibri' })],
  });
}

function bullet(text, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level },
    spacing: { before: 40, after: 40 },
    children: [new TextRun({ text, size: 21, color: DARK, font: 'Calibri' })],
  });
}

function bulletKV(label, rest, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level },
    spacing: { before: 40, after: 40 },
    children: [
      new TextRun({ text: label, bold: true, size: 21, color: DARK, font: 'Calibri' }),
      new TextRun({ text: rest, size: 21, color: DARK, font: 'Calibri' }),
    ],
  });
}

/** Encadre d'attention (fond ambre). */
function callout(title, text) {
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
    rows: [
      new TableRow({
        children: [
          new TableCell({
            shading: { fill: ALERT_BG },
            margins: { top: 120, bottom: 120, left: 180, right: 180 },
            children: [
              new Paragraph({
                spacing: { after: 60 },
                children: [new TextRun({ text: title, bold: true, size: 21, color: '8A5A00', font: 'Calibri' })],
              }),
              new Paragraph({
                children: [new TextRun({ text, size: 20, color: DARK, font: 'Calibri' })],
              }),
            ],
          }),
        ],
      }),
    ],
  });
}

/**
 * Tableau standard.
 * `rows` : tableau de tableaux de chaines. Une cellule prefixee de '**' est
 * mise en gras (utilise pour les lignes de total).
 */
function table(headers, rows, widths) {
  const cell = (text, opts = {}) => {
    const { bold = false, fill = null, align = AlignmentType.LEFT, color = DARK } = opts;
    return new TableCell({
      shading: fill ? { fill } : undefined,
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      children: [
        new Paragraph({
          alignment: align,
          children: [new TextRun({ text, bold, size: 19, color, font: 'Calibri' })],
        }),
      ],
    });
  };

  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) =>
      cell(h, {
        bold: true,
        fill: PRIMARY,
        color: WHITE,
        align: i === 0 ? AlignmentType.LEFT : AlignmentType.RIGHT,
      })
    ),
  });

  const bodyRows = rows.map((r, ri) => {
    const isTotal = r[0].startsWith('**');
    return new TableRow({
      children: r.map((c, i) =>
        cell(c.replace(/^\*\*/, ''), {
          bold: isTotal,
          fill: isTotal ? LIGHT_BG : (ri % 2 === 1 ? 'FAFBFA' : null),
          align: i === 0 ? AlignmentType.LEFT : AlignmentType.RIGHT,
        })
      ),
    });
  });

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: widths,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: 'D5DDD8' },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: 'D5DDD8' },
      left: { style: BorderStyle.SINGLE, size: 2, color: 'D5DDD8' },
      right: { style: BorderStyle.SINGLE, size: 2, color: 'D5DDD8' },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 1, color: 'E4EAE6' },
      insideVertical: { style: BorderStyle.SINGLE, size: 1, color: 'E4EAE6' },
    },
    rows: [headerRow, ...bodyRows],
  });
}

// ── Logo ──────────────────────────────────────────────────────────────────
const logoPath = path.join(__dirname, 'assets', 'images', 'logo.png');
let logoParagraph = emptyPara(200);
if (fs.existsSync(logoPath)) {
  logoParagraph = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 200 },
    children: [
      new ImageRun({
        data: fs.readFileSync(logoPath),
        transformation: { width: 120, height: 120 },
        // Sans `type`, docx nomme le media « .undefined » et Word affiche une
        // image cassee a la place du logo.
        type: 'png',
      }),
    ],
  });
  console.log('Logo charge depuis ' + logoPath);
} else {
  console.log('Logo introuvable — la couverture sera generee sans logo.');
}

// ══════════════════════════════════════════════════════════════════════════
//  CONTENU
// ══════════════════════════════════════════════════════════════════════════

const children = [];

// ── Couverture ────────────────────────────────────────────────────────────
children.push(
  emptyPara(300),
  rule(PRIMARY),
  rule(SECONDARY),
  emptyPara(200),
  logoParagraph,
  new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: "BUDGET D'EXPLOITATION", bold: true, size: 46, color: PRIMARY, font: 'Calibri' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { after: 60 },
    children: [new TextRun({ text: 'HÉBERGEMENT, STORES ET SERVICES CLOUD', bold: true, size: 26, color: SECONDARY, font: 'Calibri' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { after: 200 },
    children: [new TextRun({ text: 'My Home CI', bold: true, size: 50, color: PRIMARY, font: 'Calibri' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { after: 400 },
    children: [new TextRun({ text: "Coûts récurrents à court, moyen et long terme", italic: true, size: 23, color: GRAY, font: 'Calibri' })],
  }),
  rule(SECONDARY),
  emptyPara(200),
  p('Version 1.0 — 15 août 2026', { alignment: AlignmentType.CENTER, color: GRAY, size: 20 }),
  p('Périmètre : application mobile Android et iOS, back-office web, site web, backend Firebase', { alignment: AlignmentType.CENTER, color: GRAY, size: 20 }),
  emptyPara(200),
  rule(PRIMARY),
);

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 1. Résumé exécutif ────────────────────────────────────────────────────
children.push(h1('1. Résumé exécutif'));

children.push(p(
  "Ce document chiffre le coût de fonctionnement de la plateforme My Home CI une fois publiée. " +
  "Il ne couvre pas le développement, déjà réalisé, mais uniquement les dépenses récurrentes : " +
  "comptes développeurs, hébergement, base de données, stockage des photos, notifications, SMS et intégration continue."
));

children.push(h2('Les trois horizons retenus'));
children.push(table(
  ['Horizon', 'Utilisateurs visés', 'Coût mensuel (USD)', 'Coût mensuel (FCFA)'],
  [
    ['Court terme — mois 1 à 3 (lancement, bêta fermée)', '< 500 inscrits', '8 $', fcfa(8) + ' F'],
    ['Moyen terme — mois 4 à 12 (croissance)', '2 000 à 5 000 inscrits', '31 $', fcfa(31) + ' F'],
    ['Long terme — année 2 (régime établi)', '20 000 inscrits', '190 $', fcfa(190) + ' F'],
    ['**Long terme optimisé (miniatures + SMS maîtrisés)', '20 000 inscrits', '97 $', fcfa(97) + ' F'],
  ],
  [4200, 2000, 1400, 1600]
));

children.push(emptyPara(120));
children.push(h2('Totaux annuels'));
children.push(table(
  ['Période', 'Détail', 'Total (USD)', 'Total (FCFA)'],
  [
    ['Année 1', 'Prépaiement Firebase 30 $ + 3 mois à 8 $ + 9 mois à 31 $ + Google Play 25 $ + Apple 99 $', '457 $', fcfa(457) + ' F'],
    ['Année 2', '12 mois à 190 $ + Apple 99 $', '2 379 $', fcfa(2379) + ' F'],
    ['**Année 2 optimisée', '12 mois à 97 $ + Apple 99 $', '1 263 $', fcfa(1263) + ' F'],
  ],
  [1600, 4400, 1500, 1700]
));

children.push(emptyPara(120));
children.push(callout(
  'Seuil de rentabilité',
  "Au tarif du Pack Pro Propriétaire (15 000 FCFA / 30 jours), il suffit de 8 abonnements vendus par mois " +
  "pour couvrir l'intégralité des coûts d'infrastructure en année 2 — ou 23 mises en avant d'annonce à 5 000 FCFA. " +
  "L'infrastructure n'est donc pas un frein économique : le vrai enjeu est l'acquisition d'utilisateurs."
));

children.push(emptyPara(120));
children.push(h2('Ce qu\'il faut retenir'));
children.push(bulletKV('Le coût est marginal au lancement. ', "Les quotas gratuits de Firebase couvrent largement les premiers mois ; les 300 $ de crédits absorbent la totalité de la phase de bêta."));
children.push(bulletKV('Deux postes seulement font la facture à long terme : ', "le téléchargement des photos d'annonces depuis Firebase Storage, et les SMS de vérification (OTP). À eux deux, ils représentent près de 70 % de la dépense en année 2."));
children.push(bulletKV('Ces deux postes sont maîtrisables. ', "Générer des miniatures et privilégier l'inscription par email ou Google divise la facture par deux (190 $ → 97 $ par mois)."));
children.push(bulletKV('Seul Apple est un abonnement obligatoire et incompressible : ', "99 $ par an, à renouveler sous peine de retrait de l'application de l'App Store."));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 2. Hypothèses ─────────────────────────────────────────────────────────
children.push(h1('2. Hypothèses et méthode'));

children.push(h2('Conversion monétaire'));
children.push(p(
  "Tous les fournisseurs facturent en dollars américains. Le franc CFA étant arrimé à l'euro et non au dollar, " +
  "le taux USD/XOF fluctue. Un taux prudent de 1 USD = 600 FCFA est retenu dans tout le document, " +
  "volontairement au-dessus du taux habituellement constaté afin de ne pas sous-estimer le budget."
));

children.push(h2('Hypothèses de charge'));
children.push(table(
  ['Paramètre', 'Mois 1-3', 'Mois 4-12', 'Année 2'],
  [
    ['Utilisateurs inscrits', '500', '5 000', '20 000'],
    ['Utilisateurs actifs par jour', '80', '800', '4 000'],
    ['Annonces publiées (cumul)', '100', '500', '3 000'],
    ['Nouvelles inscriptions par mois', '150', '300', '1 500'],
    ['Photos par annonce', '6', '6', '6'],
    ['Poids moyen d\'une photo après compression', '250 Ko', '250 Ko', '250 Ko'],
    ['Lectures Firestore par session', '40', '40', '40'],
    ['Données téléchargées par utilisateur actif et par jour', '3 Mo', '3 Mo', '4 Mo'],
  ],
  [4000, 1700, 1700, 1800]
));

children.push(emptyPara(120));
children.push(h2('Périmètre'));
children.push(bulletKV('Inclus : ', "comptes développeurs Google Play et Apple, plan Firebase Blaze, hébergement du back-office et du site web, nom de domaine, Google Maps Platform, intégration continue, envoi d'emails transactionnels."));
children.push(bulletKV('Exclus : ', "développement et maintenance applicative, marketing et acquisition, matériel, salaires, fiscalité, et les commissions GeniusPay qui sont un coût variable adossé au chiffre d'affaires (traité au chapitre 9)."));

children.push(emptyPara(120));
children.push(callout(
  'Fiabilité des tarifs',
  "Les tarifs unitaires cités sont ceux publiés par les fournisseurs à la date de rédaction. " +
  "Google, Apple et Railway les révisent régulièrement — Google Maps Platform a par exemple remplacé son " +
  "crédit mensuel de 200 $ par des quotas gratuits par type d'appel. Il est prudent de les revérifier au moment " +
  "de l'engagement, et de prévoir une marge de 15 % sur les projections de long terme."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 3. Stores ─────────────────────────────────────────────────────────────
children.push(h1('3. Comptes développeurs — Google Play et App Store'));

children.push(p(
  "Ces deux comptes sont le préalable absolu à toute publication. Ils ont été identifiés comme déjà pris en charge, " +
  "mais figurent ici pour la complétude du budget et surtout pour signaler une différence de nature entre les deux."
));

children.push(table(
  ['Poste', 'Nature', 'Montant (USD)', 'Montant (FCFA)'],
  [
    ['Google Play Developer', 'Paiement unique, à vie', '25 $', fcfa(25) + ' F'],
    ['Apple Developer Program', 'Abonnement annuel', '99 $ / an', fcfa(99) + ' F / an'],
    ['**Total année 1', '', '124 $', fcfa(124) + ' F'],
    ['**Total années suivantes', '', '99 $', fcfa(99) + ' F'],
  ],
  [3600, 2800, 1500, 1900]
));

children.push(emptyPara(120));
children.push(callout(
  "L'abonnement Apple n'est pas un coût unique",
  "Le compte Apple Developer se renouvelle tous les ans. Un non-renouvellement entraîne le retrait automatique " +
  "de l'application de l'App Store, et sa réinstallation ultérieure impose de repasser la revue complète. " +
  "Cette échéance doit être inscrite au calendrier avec une alerte à 30 jours."
));

children.push(emptyPara(100));
children.push(p(
  "À noter également : l'ouverture du compte Google Play impose une vérification d'identité dont le délai " +
  "peut atteindre plusieurs jours, et le compte Apple exige la création préalable de l'App ID avec les capacités " +
  "Push Notifications, Sign in with Apple et Associated Domains. Ces démarches sont administratives, pas techniques : " +
  "elles doivent être lancées en avance."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 4. Firebase ───────────────────────────────────────────────────────────
children.push(h1('4. Firebase — le cœur du budget'));

children.push(p(
  "Firebase héberge la base de données, les photos, l'authentification, les notifications et la logique serveur. " +
  "Le passage au plan Blaze (paiement à l'usage) est obligatoire dès lors que l'application utilise des Cloud Functions, " +
  "ce qui est le cas ici pour les paiements et les notifications automatiques."
));

children.push(h2('4.1 Amorçage : prépaiement et crédits'));
children.push(p(
  "Le démarrage repose sur un prépaiement initial d'environ 30 $ (18 000 FCFA) qui active le compte de facturation " +
  "et donne accès à 300 $ de crédits Google Cloud, utilisables sur 90 jours. Sur la base des projections ci-dessous, " +
  "ces crédits couvrent intégralement les trois premiers mois d'exploitation, et une partie du quatrième : " +
  "la dépense réelle sur la phase de lancement est donc nulle."
));
children.push(callout(
  'Point de vigilance',
  "Les crédits expirent au bout de 90 jours, qu'ils soient consommés ou non. Le compteur démarre à l'activation " +
  "du compte de facturation, pas à la publication de l'application : il ne faut donc activer Blaze qu'au moment " +
  "où le déploiement en production est réellement imminent, sous peine de brûler les crédits pendant les tests."
));

children.push(emptyPara(120));
children.push(h2('4.2 Ce qui reste gratuit, quelle que soit la charge'));
children.push(p(
  "Le plan Blaze conserve les quotas gratuits du plan Spark. La facturation ne commence qu'au-delà. " +
  "Ces quotas sont considérables au regard de la taille visée."
));
children.push(table(
  ['Service', 'Quota gratuit permanent', 'Tarif au-delà'],
  [
    ['Firestore — lectures', '50 000 par jour', '0,06 $ / 100 000'],
    ['Firestore — écritures', '20 000 par jour', '0,18 $ / 100 000'],
    ['Firestore — stockage', '1 Gio', '0,18 $ / Gio / mois'],
    ['Storage — données stockées', '5 Go', '0,026 $ / Go / mois'],
    ['Storage — données téléchargées', '1 Go par jour', '0,12 $ / Go'],
    ['Cloud Functions — appels', '2 millions par mois', '0,40 $ / million'],
    ['Cloud Messaging (notifications push)', 'Illimité', 'Gratuit'],
    ['Authentification email, Google, Apple', '50 000 utilisateurs actifs / mois', 'Gratuit en pratique'],
    ['Analytics et Crashlytics', 'Illimité', 'Gratuit'],
    ['Authentification par SMS (OTP)', '10 SMS par jour', 'Facturé au SMS, selon le pays'],
  ],
  [3300, 3200, 3300]
));

children.push(emptyPara(120));
children.push(h2('4.3 Projection détaillée par phase'));

children.push(p('Mois 1 à 3 — lancement', { bold: true, spacing: { before: 160 } }));
children.push(p(
  "Avec 80 utilisateurs actifs par jour, la consommation reste très en deçà de tous les quotas gratuits : " +
  "3 200 lectures Firestore par jour sur 50 000 autorisées, 150 Mo de photos stockées sur 5 Go. " +
  "Seuls les SMS de vérification sortent du gratuit, et à ce volume ils restent négligeables. " +
  "Coût réel : 0 $, absorbé par les crédits."
));

children.push(p('Mois 4 à 12 — croissance', { bold: true, spacing: { before: 160 } }));
children.push(table(
  ['Poste Firebase', 'Consommation estimée', 'Au-delà du gratuit', 'Coût / mois'],
  [
    ['Firestore — lectures', '32 000 / jour', 'Non', '0 $'],
    ['Firestore — écritures', '3 000 / jour', 'Non', '0 $'],
    ['Storage — stockage des photos', '0,75 Go', 'Non', '0 $'],
    ['Storage — téléchargement', '2,4 Go / jour', 'Oui — 42 Go / mois', '5 $'],
    ['Cloud Functions', '~300 000 appels / mois', 'Non', '0 $'],
    ['Notifications push', 'Illimité', 'Non', '0 $'],
    ['SMS de vérification (OTP)', '~360 SMS / mois', 'Oui', '18 $'],
    ['**Total Firebase', '', '', '23 $ (' + fcfa(23) + ' F)'],
  ],
  [3200, 2600, 2200, 1800]
));

children.push(p('Année 2 — régime établi', { bold: true, spacing: { before: 200 } }));
children.push(table(
  ['Poste Firebase', 'Consommation estimée', 'Au-delà du gratuit', 'Coût / mois'],
  [
    ['Firestore — lectures', '4,8 M / mois', 'Oui — 3,3 M', '2 $'],
    ['Firestore — écritures', '450 000 / mois', 'Non', '0 $'],
    ['Firestore — stockage', '3 Gio', 'Oui — 2 Gio', '0,4 $'],
    ['Storage — stockage des photos', '4,5 Go', 'Non', '0 $'],
    ['Storage — téléchargement', '16 Go / jour', 'Oui — 450 Go / mois', '54 $'],
    ['Cloud Functions', '~4 M appels / mois', 'Oui — 2 M', '1 $'],
    ['SMS de vérification (OTP)', '~1 500 SMS / mois', 'Oui', '75 $'],
    ['**Total Firebase', '', '', '132 $ (' + fcfa(132) + ' F)'],
  ],
  [3200, 2600, 2200, 1800]
));

children.push(emptyPara(120));
children.push(callout(
  'Les deux seuls postes qui comptent',
  "Le téléchargement des photos (54 $) et les SMS de vérification (75 $) représentent 98 % de la facture Firebase " +
  "en année 2. Tout le reste — base de données, notifications, logique serveur, statistiques — coûte moins de 4 $ par mois. " +
  "Le chapitre 10 détaille comment diviser ces deux postes par deux ou trois."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 5. Hébergement ────────────────────────────────────────────────────────
children.push(h1('5. Hébergement du back-office et du site web'));

children.push(p(
  "Deux éléments doivent être hébergés en dehors de l'application mobile : le back-office d'administration " +
  "(Next.js) et le site web public. Le back-office remplit un rôle supplémentaire et non négociable : " +
  "il héberge la page de paiement utilisée sur iOS, dont l'adresse est déjà inscrite dans le code du backend " +
  "(admin.myhomeci.ci). Sans hébergement en ligne, les liens de paiement envoyés par email ne mènent nulle part."
));

children.push(h2('5.1 Railway — solution retenue'));
children.push(table(
  ['Formule', 'Contenu', 'Prix', 'Recommandation'],
  [
    ['Hobby', "5 $ de consommation incluse, mise en veille possible", '5 $ / mois', 'Mois 1 à 12'],
    ['Pro', "20 $ de consommation incluse, pas de mise en veille, meilleures performances", '20 $ / mois', 'À partir de l\'année 2'],
  ],
  [1800, 4600, 1600, 2000]
));

children.push(emptyPara(100));
children.push(p(
  "La formule Hobby suffit largement pendant la première année : le back-office n'est utilisé que par " +
  "l'équipe d'administration, et le site web public consomme peu. Le passage à Pro se justifie quand la page " +
  "de paiement devient critique — une mise en veille du service au moment où un propriétaire clique sur son " +
  "lien de paiement se traduit par un abandon."
));

children.push(h2('5.2 Alternative à considérer'));
children.push(p(
  "Firebase Hosting est déjà inclus dans le projet Firebase existant et offre 10 Go de stockage et " +
  "360 Mo de transfert par jour gratuitement. Héberger le back-office et le site web sur Firebase Hosting " +
  "plutôt que sur Railway ramènerait ce poste à zéro, tout en simplifiant l'administration (un seul fournisseur, " +
  "une seule facture, un seul domaine à configurer). Cela suppose de publier le back-office en version statique, " +
  "ce que son architecture actuelle permet puisque toutes les données sont chargées côté navigateur."
));
children.push(callout(
  'Économie potentielle',
  "Basculer l'hébergement sur Firebase Hosting représente une économie de 60 $ la première année et " +
  "240 $ par an ensuite (144 000 FCFA par an), sans perte de fonctionnalité. " +
  "À arbitrer selon la préférence pour un fournisseur unique ou pour la souplesse de Railway."
));

children.push(emptyPara(120));
children.push(h2('5.3 Nom de domaine'));
children.push(p(
  "Le domaine myhomeci.ci est nécessaire à trois titres : l'adresse du site public, le sous-domaine " +
  "admin.myhomeci.ci de la page de paiement, et la vérification des liens profonds qui permettent d'ouvrir " +
  "directement une annonce partagée dans l'application. Un domaine en .ci se situe autour de 30 000 à " +
  "35 000 FCFA par an selon le bureau d'enregistrement, soit environ 3 $ par mois amortis. " +
  "Les certificats de sécurité HTTPS sont fournis gratuitement par Railway comme par Firebase Hosting."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 6. Maps ───────────────────────────────────────────────────────────────
children.push(h1('6. Google Maps Platform'));

children.push(p(
  "L'application affiche une carte interactive des logements. Le point important, et souvent mal compris, " +
  "est que l'affichage de la carte elle-même dans une application mobile native est gratuit et sans limite : " +
  "seuls les services annexes sont facturés."
));

children.push(table(
  ['Service', 'Usage dans l\'application', 'Facturation'],
  [
    ['Maps SDK Android et iOS', 'Affichage de la carte et des marqueurs', 'Gratuit, sans plafond'],
    ['Geocoding API', "Conversion d'une adresse saisie en coordonnées, à la publication", 'Quota mensuel gratuit puis ~5 $ / 1 000 appels'],
    ['Places API', "Auto-complétion des adresses", 'Quota mensuel gratuit puis facturation par session'],
  ],
  [2600, 4200, 3200]
));

children.push(emptyPara(100));
children.push(p(
  "Le géocodage n'est appelé qu'au moment de la publication ou de la modification d'une annonce, " +
  "soit quelques centaines d'appels par mois en phase de croissance : le quota gratuit suffit. " +
  "En année 2, avec 3 000 annonces et une recherche d'adresse plus intensive, une dépense de l'ordre " +
  "de 20 $ par mois est à prévoir."
));

children.push(callout(
  'Protection obligatoire de la facturation',
  "Deux mesures doivent être prises avant la mise en production, faute de quoi la facture Google Maps " +
  "est imprévisible. D'une part, restreindre chaque clé d'API à son application (nom de paquet et empreinte " +
  "de signature côté Android, identifiant de l'application côté iOS) : une clé non restreinte peut être extraite " +
  "de l'application et utilisée par un tiers à vos frais. D'autre part, définir un plafond de requêtes quotidien " +
  "dans la console Google Cloud, ainsi qu'une alerte de budget."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 7. CI/CD ──────────────────────────────────────────────────────────────
children.push(h1('7. Intégration continue — Codemagic'));

children.push(p(
  "La compilation d'une application iOS exige un ordinateur Apple. Le développement se faisant sous Windows, " +
  "Codemagic fournit ces machines à la demande : c'est la seule voie vers l'App Store sans acheter de Mac. " +
  "Le projet est déjà configuré pour quatre chaînes de compilation automatiques."
));

children.push(table(
  ['Formule', 'Contenu', 'Prix'],
  [
    ['Gratuite', '500 minutes de compilation macOS par mois', '0 $'],
    ['Au-delà', 'Facturation à la minute', 'environ 0,095 $ / minute'],
  ],
  [2000, 5000, 3000]
));

children.push(emptyPara(100));
children.push(p(
  "Une compilation iOS complète prend entre 15 et 25 minutes. Le quota gratuit autorise donc environ " +
  "20 à 30 publications par mois, ce qui dépasse largement le rythme d'un projet en exploitation. " +
  "Ce poste reste à zéro dans toutes les projections, sauf période de correction intensive. " +
  "À titre de comparaison, l'achat d'un Mac Mini représenterait entre 400 000 et 600 000 FCFA — " +
  "l'option Codemagic reste préférable tant que le rythme de publication est mensuel."
));

// ── 8. Email ──────────────────────────────────────────────────────────────
children.push(h1('8. Emails transactionnels'));

children.push(p(
  "Le backend envoie des emails automatiques, notamment le lien de paiement à usage unique destiné aux " +
  "utilisateurs iOS. L'envoi passe aujourd'hui par un compte Gmail, solution gratuite mais limitée à " +
  "500 envois par jour et exposée à un blocage pour usage automatisé."
));

children.push(table(
  ['Solution', 'Volume', 'Prix'],
  [
    ['Gmail (actuel)', "500 envois / jour, risque de blocage", '0 $'],
    ['Brevo ou équivalent — offre gratuite', '300 envois / jour', '0 $'],
    ['Brevo ou équivalent — offre payante', '20 000 envois / mois', 'environ 15 $ / mois'],
  ],
  [3200, 3800, 3000]
));

children.push(emptyPara(100));
children.push(p(
  "Le passage à un service d'envoi dédié n'est pas urgent, mais devient recommandé en année 2 : " +
  "un email de paiement bloqué par Gmail est une vente perdue, et la traçabilité des envois " +
  "(délivré, ouvert, en échec) devient nécessaire pour traiter les réclamations."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 9. GeniusPay ──────────────────────────────────────────────────────────
children.push(h1('9. Commissions de paiement — GeniusPay'));

children.push(p(
  "Les encaissements Mobile Money (Wave, Orange Money, MTN, Moov) passent par GeniusPay, qui prélève " +
  "une commission sur chaque transaction. Ce coût est de nature différente de tous les précédents : " +
  "il n'existe que s'il y a du chiffre d'affaires, et il croît proportionnellement à celui-ci. " +
  "Il ne doit donc pas être budgété comme une charge fixe, mais déduit de la marge."
));

children.push(table(
  ['Scénario mensuel', 'Chiffre d\'affaires brut', 'Commission à 3 %', 'Net encaissé'],
  [
    ['10 Pack Pro', '150 000 F', '4 500 F', '145 500 F'],
    ['30 Pack Pro + 20 boosts', '550 000 F', '16 500 F', '533 500 F'],
    ['100 Pack Pro + 80 boosts', '1 900 000 F', '57 000 F', '1 843 000 F'],
  ],
  [3200, 2600, 2200, 2000]
));

children.push(emptyPara(100));
children.push(callout(
  'Taux à confirmer',
  "Le taux de 3 % utilisé ci-dessus est une hypothèse de travail correspondant aux pratiques du marché " +
  "ouest-africain. Le taux réel, ainsi que l'existence éventuelle de frais fixes par transaction ou de frais " +
  "de retrait vers le compte bancaire, doivent être confirmés par écrit auprès de GeniusPay avant le lancement. " +
  "Sur des transactions de 5 000 FCFA, un frais fixe de 100 FCFA pèse davantage qu'un pourcentage."
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 10. Synthèse ──────────────────────────────────────────────────────────
children.push(h1('10. Synthèse consolidée'));

children.push(h2('10.1 Court terme — mois 1 à 3'));
children.push(table(
  ['Poste', 'USD / mois', 'FCFA / mois'],
  [
    ['Firebase (absorbé par les crédits)', '0 $', '0 F'],
    ['Hébergement Railway Hobby', '5 $', fcfa(5) + ' F'],
    ['Nom de domaine (amorti)', '3 $', fcfa(3) + ' F'],
    ['Google Maps', '0 $', '0 F'],
    ['Codemagic', '0 $', '0 F'],
    ['Emails (Gmail)', '0 $', '0 F'],
    ['**Total mensuel', '8 $', fcfa(8) + ' F'],
  ],
  [5200, 2500, 2300]
));
children.push(p("À quoi s'ajoute le prépaiement Firebase de 30 $ (" + fcfa(30) + " FCFA), payé une seule fois à l'activation.", { italic: true, size: 20, color: GRAY }));

children.push(emptyPara(140));
children.push(h2('10.2 Moyen terme — mois 4 à 12'));
children.push(table(
  ['Poste', 'USD / mois', 'FCFA / mois'],
  [
    ['Firebase (dont 18 $ de SMS)', '23 $', fcfa(23) + ' F'],
    ['Hébergement Railway Hobby', '5 $', fcfa(5) + ' F'],
    ['Nom de domaine (amorti)', '3 $', fcfa(3) + ' F'],
    ['Google Maps', '0 $', '0 F'],
    ['Codemagic', '0 $', '0 F'],
    ['Emails (Gmail)', '0 $', '0 F'],
    ['**Total mensuel', '31 $', fcfa(31) + ' F'],
  ],
  [5200, 2500, 2300]
));

children.push(emptyPara(140));
children.push(h2('10.3 Long terme — année 2'));
children.push(table(
  ['Poste', 'Standard (USD)', 'Optimisé (USD)', 'Optimisé (FCFA)'],
  [
    ['Firebase', '132 $', '39 $', fcfa(39) + ' F'],
    ['Hébergement Railway Pro', '20 $', '20 $', fcfa(20) + ' F'],
    ['Google Maps', '20 $', '20 $', fcfa(20) + ' F'],
    ['Emails transactionnels', '15 $', '15 $', fcfa(15) + ' F'],
    ['Nom de domaine (amorti)', '3 $', '3 $', fcfa(3) + ' F'],
    ['Codemagic', '0 $', '0 $', '0 F'],
    ['**Total mensuel', '190 $', '97 $', fcfa(97) + ' F'],
  ],
  [3600, 2200, 2200, 2000]
));

children.push(emptyPara(140));
children.push(h2('10.4 Vue annuelle'));
children.push(table(
  ['Poste', 'Année 1', 'Année 2', 'Année 2 optimisée'],
  [
    ['Infrastructure et hébergement', '303 $', '2 280 $', '1 164 $'],
    ['Prépaiement Firebase', '30 $', '—', '—'],
    ['Google Play (unique)', '25 $', '—', '—'],
    ['Apple Developer', '99 $', '99 $', '99 $'],
    ['**Total (USD)', '457 $', '2 379 $', '1 263 $'],
    ['**Total (FCFA)', fcfa(457) + ' F', fcfa(2379) + ' F', fcfa(1263) + ' F'],
    ['**Moyenne mensuelle (FCFA)', fcfa(38) + ' F', fcfa(198) + ' F', fcfa(105) + ' F'],
  ],
  [3600, 2000, 2200, 2200]
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 11. Optimisation ──────────────────────────────────────────────────────
children.push(h1('11. Leviers d\'optimisation'));

children.push(p(
  "Les quatre actions ci-dessous sont des décisions techniques à prendre une fois, dont l'effet se répète " +
  "chaque mois. Elles sont classées par rapport entre l'économie obtenue et l'effort requis."
));

children.push(h2('11.1 Générer des miniatures pour les listes — économie ~43 $ / mois'));
children.push(p(
  "Aujourd'hui, parcourir la liste des annonces télécharge les photos en pleine résolution, alors qu'elles " +
  "s'affichent dans une vignette de quelques centimètres. Générer automatiquement une miniature de 150 Ko " +
  "à l'upload et l'utiliser dans les listes et la carte divise le volume téléchargé par cinq. " +
  "C'est le levier le plus rentable du projet : une demi-journée de travail pour près de 26 000 FCFA " +
  "d'économie mensuelle en année 2."
));

children.push(h2('11.2 Réduire la dépendance aux SMS — économie ~50 $ / mois'));
children.push(p(
  "La vérification par SMS est le poste le plus cher par utilisateur. Trois mesures, cumulables : " +
  "présenter l'inscription par email et par Google avant l'option téléphone plutôt qu'après ; " +
  "ne vérifier le numéro qu'au moment de publier une annonce, et non à l'inscription, ce qui réserve " +
  "le coût aux propriétaires réellement actifs ; et bloquer les demandes répétées depuis un même numéro. " +
  "Cette dernière mesure protège aussi contre une attaque connue qui consiste à déclencher massivement " +
  "des envois de SMS aux frais de l'éditeur."
));

children.push(h2('11.3 Héberger sur Firebase Hosting — économie 5 à 20 $ / mois'));
children.push(p(
  "Détaillé au chapitre 5. Supprime un fournisseur et une facture, sans perte de fonctionnalité."
));

children.push(h2('11.4 Alertes de budget — protection, pas économie'));
children.push(p(
  "Une alerte de budget doit être configurée dans la console Google Cloud à trois seuils : " +
  "50 %, 90 % et 100 % du montant mensuel attendu. Elle ne réduit pas la facture mais évite la mauvaise " +
  "surprise : le plan Blaze ne s'arrête pas tout seul, une erreur de programmation ou un usage abusif " +
  "peut faire déraper la consommation en quelques heures. C'est la première chose à faire après l'activation " +
  "de la facturation, avant même le déploiement."
));

children.push(emptyPara(120));
children.push(table(
  ['Levier', 'Effort', 'Économie annuelle (FCFA)'],
  [
    ['Miniatures des photos', 'Faible', fcfa(43 * 12) + ' F'],
    ['Réduction des SMS', 'Moyen', fcfa(50 * 12) + ' F'],
    ['Hébergement Firebase', 'Faible', fcfa(20 * 12) + ' F'],
    ['**Total', '', fcfa(113 * 12) + ' F'],
  ],
  [4000, 2600, 3400]
));

children.push(new Paragraph({ children: [new docx.PageBreak()] }));

// ── 12. Risques ───────────────────────────────────────────────────────────
children.push(h1('12. Risques budgétaires'));

children.push(table(
  ['Risque', 'Conséquence', 'Parade'],
  [
    ['Clé Google Maps non restreinte', 'Facture imprévisible, usage par un tiers', 'Restriction par application et plafond quotidien'],
    ['Absence d\'alerte de budget Firebase', 'Dérapage non détecté pendant plusieurs jours', 'Alertes à 50 %, 90 % et 100 %'],
    ['Attaque par déclenchement massif de SMS', 'Plusieurs centaines de dollars en une nuit', 'App Check activé en mode strict et limitation par numéro'],
    ['Crédits Firebase activés trop tôt', '300 $ consommés pendant les tests', 'N\'activer Blaze qu\'à l\'approche de la production'],
    ['Non-renouvellement du compte Apple', 'Retrait de l\'application de l\'App Store', 'Rappel calendaire à 30 jours de l\'échéance'],
    ['Photos non compressées à l\'upload', 'Coût de téléchargement multiplié', 'Compression déjà en place, à vérifier après chaque évolution'],
    ['Variation du taux USD / FCFA', 'Écart de 5 à 10 % sur la facture', 'Taux prudent de 600 retenu, marge de 15 % conseillée'],
  ],
  [3200, 3400, 3400]
));

children.push(emptyPara(160));
children.push(h1('13. Plan d\'action'));

children.push(bulletKV('Avant la mise en production : ', "restreindre les clés Google Maps, configurer les alertes de budget, activer App Check en mode strict, confirmer par écrit le taux de commission GeniusPay."));
children.push(bulletKV("Au moment du déploiement : ", "activer le plan Blaze et le prépaiement de 30 $, déployer le back-office et faire pointer admin.myhomeci.ci, enregistrer l'échéance annuelle Apple au calendrier."));
children.push(bulletKV('Dans les trois premiers mois : ', "mettre en place les miniatures de photos avant que le volume ne rende l'opération coûteuse à rattraper, et relever la consommation réelle pour recaler les projections de ce document."));
children.push(bulletKV('À la fin de la première année : ', "arbitrer le passage à Railway Pro ou la bascule sur Firebase Hosting, et décider du service d'envoi d'emails dédié."));

children.push(emptyPara(200));
children.push(rule(SECONDARY));
children.push(p(
  "Ce document est une projection fondée sur des hypothèses de charge explicites et sur les tarifs publics " +
  "constatés au 15 août 2026. Il doit être recalé après trois mois d'exploitation réelle, lorsque la " +
  "consommation effective sera mesurable dans les consoles Firebase et Google Cloud.",
  { italic: true, size: 20, color: GRAY }
));

// ══════════════════════════════════════════════════════════════════════════

const doc = new Document({
  creator: 'My Home CI',
  title: "Budget d'exploitation - My Home CI",
  description: "Budget hebergement, stores et services cloud - My Home CI",
  numbering: {
    config: [
      {
        reference: 'bullets',
        levels: [
          { level: 0, format: docx.LevelFormat.BULLET, text: '—', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
          { level: 1, format: docx.LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1440, hanging: 360 } } } },
        ],
      },
    ],
  },
  sections: [
    {
      properties: { page: { margin: { top: 1200, bottom: 1200, left: 1200, right: 1200 } } },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              alignment: AlignmentType.CENTER,
              children: [
                new TextRun({ text: 'My Home CI — Budget d\'exploitation — ', size: 16, color: GRAY, font: 'Calibri' }),
                new TextRun({ children: [PageNumber.CURRENT], size: 16, color: GRAY, font: 'Calibri' }),
              ],
            }),
          ],
        }),
      },
      children,
    },
  ],
});

const output = path.join(__dirname, 'BUDGET_MY_HOME_CI.docx');
Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(output, buffer);
  console.log('Document genere : ' + output);
  console.log('Taille : ' + Math.round(buffer.length / 1024) + ' Ko');
});
