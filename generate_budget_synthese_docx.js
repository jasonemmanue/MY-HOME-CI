// Synthese budgetaire My Home CI — version courte, deux pages maximum.
//
// Meme charte que generate_docx.js et generate_budget_docx.js. Le document
// long reste la reference : celui-ci ne garde que les chiffres de decision.
//
//   node generate_budget_synthese_docx.js

const docx = require('docx');
const fs = require('fs');
const path = require('path');

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, WidthType, BorderStyle, ImageRun, PageBreak,
} = docx;

const PRIMARY = '2E7D5B';
const SECONDARY = 'F5A623';
const DARK = '1A1A2E';
const GRAY = '6B7280';
const LIGHT_BG = 'F0F4F2';
const ALERT_BG = 'FDF3E3';
const WHITE = 'FFFFFF';

// ── Helpers compacts ──────────────────────────────────────────────────────
// Les espacements sont volontairement plus serres que dans le document long :
// la contrainte de deux pages ne laisse pas de place au confort typographique.

function h1(text) {
  return new Paragraph({
    spacing: { before: 220, after: 100 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: PRIMARY } },
    children: [new TextRun({ text, bold: true, size: 24, color: PRIMARY, font: 'Calibri' })],
  });
}

function p(text, opts = {}) {
  const { bold = false, italic = false, size = 19, color = DARK, alignment = AlignmentType.JUSTIFIED } = opts;
  return new Paragraph({
    alignment,
    spacing: { before: 50, after: 50 },
    children: [new TextRun({ text, bold, italic, size, color, font: 'Calibri' })],
  });
}

function bulletKV(label, rest) {
  return new Paragraph({
    numbering: { reference: 'bullets', level: 0 },
    spacing: { before: 30, after: 30 },
    children: [
      new TextRun({ text: label, bold: true, size: 19, color: DARK, font: 'Calibri' }),
      new TextRun({ text: rest, size: 19, color: DARK, font: 'Calibri' }),
    ],
  });
}

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
    rows: [new TableRow({
      children: [new TableCell({
        shading: { fill: ALERT_BG },
        margins: { top: 90, bottom: 90, left: 160, right: 160 },
        children: [
          new Paragraph({ spacing: { after: 40 }, children: [new TextRun({ text: title, bold: true, size: 19, color: '8A5A00', font: 'Calibri' })] }),
          new Paragraph({ children: [new TextRun({ text, size: 18, color: DARK, font: 'Calibri' })] }),
        ],
      })],
    })],
  });
}

function table(headers, rows, widths) {
  const cell = (text, opts = {}) => {
    const { bold = false, fill = null, align = AlignmentType.LEFT, color = DARK } = opts;
    return new TableCell({
      shading: fill ? { fill } : undefined,
      margins: { top: 55, bottom: 55, left: 110, right: 110 },
      children: [new Paragraph({
        alignment: align,
        children: [new TextRun({ text, bold, size: 18, color, font: 'Calibri' })],
      })],
    });
  };

  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) => cell(h, {
      bold: true, fill: PRIMARY, color: WHITE,
      align: i === 0 ? AlignmentType.LEFT : AlignmentType.RIGHT,
    })),
  });

  const bodyRows = rows.map((r, ri) => {
    const isTotal = r[0].startsWith('**');
    return new TableRow({
      children: r.map((c, i) => cell(c.replace(/^\*\*/, ''), {
        bold: isTotal,
        fill: isTotal ? LIGHT_BG : (ri % 2 === 1 ? 'FAFBFA' : null),
        align: i === 0 ? AlignmentType.LEFT : AlignmentType.RIGHT,
      })),
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

// ── Bandeau de titre ──────────────────────────────────────────────────────
// Pas de page de couverture : elle consommerait la moitie du document.

const logoPath = path.join(__dirname, 'assets', 'images', 'logo.png');
const titleCells = [];
if (fs.existsSync(logoPath)) {
  titleCells.push(new TableCell({
    width: { size: 14, type: WidthType.PERCENTAGE },
    borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } },
    margins: { top: 40, bottom: 40, left: 0, right: 120 },
    children: [new Paragraph({
      children: [new ImageRun({
        data: fs.readFileSync(logoPath),
        transformation: { width: 62, height: 62 },
        type: 'png',
      })],
    })],
  }));
}
titleCells.push(new TableCell({
  width: { size: 86, type: WidthType.PERCENTAGE },
  borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } },
  margins: { top: 40, bottom: 40 },
  children: [
    new Paragraph({ spacing: { after: 30 }, children: [new TextRun({ text: "BUDGET D'EXPLOITATION", bold: true, size: 34, color: PRIMARY, font: 'Calibri' })] }),
    new Paragraph({ spacing: { after: 30 }, children: [new TextRun({ text: 'My Home CI — synthèse', bold: true, size: 24, color: SECONDARY, font: 'Calibri' })] }),
    new Paragraph({ children: [new TextRun({ text: '15 août 2026 — hébergement, stores et services cloud — 1 USD = 600 FCFA', size: 17, color: GRAY, font: 'Calibri' })] }),
  ],
}));

const titleBanner = new Table({
  width: { size: 100, type: WidthType.PERCENTAGE },
  borders: {
    top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.SINGLE, size: 6, color: PRIMARY },
    left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE },
    insideHorizontal: { style: BorderStyle.NONE }, insideVertical: { style: BorderStyle.NONE },
  },
  rows: [new TableRow({ children: titleCells })],
});

// ══════════════════════════════════════════════════════════════════════════
//  PAGE 1
// ══════════════════════════════════════════════════════════════════════════

const children = [titleBanner];

children.push(h1('Combien ça coûte, par mois'));

children.push(table(
  ['Poste', 'Mois 1 à 3', 'Mois 4 à 12', 'Année 2'],
  [
    ['Firebase (base, photos, notifications, SMS)', '0 F', '13 800 F', '79 200 F'],
    ['Hébergement back-office et site web', '3 000 F', '3 000 F', '12 000 F'],
    ['Google Maps (géocodage des adresses)', '0 F', '0 F', '12 000 F'],
    ['Emails transactionnels', '0 F', '0 F', '9 000 F'],
    ['Nom de domaine .ci (amorti)', '1 800 F', '1 800 F', '1 800 F'],
    ['Compilation iOS (Codemagic, offre gratuite)', '0 F', '0 F', '0 F'],
    ['**Total mensuel', '**4 800 F', '**18 600 F', '**114 000 F'],
    ['**Total mensuel optimisé (voir page 2)', '—', '—', '**58 200 F'],
  ],
  [4400, 1600, 1700, 1700]
));

children.push(p(
  "Hypothèses : moins de 500 inscrits sur les trois premiers mois, 5 000 en fin de première année, " +
  "20 000 en année 2. Les trois premiers mois sont couverts par les 300 $ de crédits Firebase offerts au démarrage.",
  { italic: true, size: 17, color: GRAY }
));

children.push(h1("Combien ça coûte, sur l'année"));

children.push(table(
  ['Poste', 'Année 1', 'Année 2'],
  [
    ['Infrastructure et hébergement (12 mois)', '181 800 F', '1 368 000 F'],
    ['Prépaiement Firebase (une seule fois)', '18 000 F', '—'],
    ['Compte Google Play (une seule fois, à vie)', '15 000 F', '—'],
    ['Compte Apple Developer (à renouveler chaque année)', '59 400 F', '59 400 F'],
    ['**Total', '**274 200 F', '**1 427 400 F'],
    ['**Total optimisé', '—', '**757 800 F'],
  ],
  [5400, 2000, 2000]
));

children.push(new Paragraph({ spacing: { before: 60, after: 60 } }));

children.push(callout(
  'Seuil de rentabilité',
  "8 Pack Pro vendus par mois (15 000 F l'unité) suffisent à couvrir la totalité des coûts d'infrastructure " +
  "en année 2 — ou 23 mises en avant d'annonce à 5 000 F. L'infrastructure n'est pas un frein économique : " +
  "le seul vrai enjeu est l'acquisition d'utilisateurs."
));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ══════════════════════════════════════════════════════════════════════════
//  PAGE 2
// ══════════════════════════════════════════════════════════════════════════

children.push(h1('Ce qui fait réellement la facture'));

children.push(p(
  "En année 2, deux postes représentent 98 % de la dépense Firebase : le téléchargement des photos d'annonces " +
  "(54 $ par mois) et les SMS de vérification à l'inscription (75 $ par mois). Tout le reste — base de données, " +
  "notifications push, logique serveur, statistiques, rapports de plantage — coûte moins de 4 $ par mois cumulés. " +
  "Ces deux postes sont maîtrisables par des décisions techniques à prendre une seule fois."
));

children.push(table(
  ['Levier', 'Ce que ça change', 'Effort', 'Économie / an'],
  [
    ['Miniatures des photos', "Les listes chargent une vignette de 150 Ko au lieu de la photo entière", 'Faible', '309 600 F'],
    ['Moins de SMS', "Inscription par email ou Google mise en avant ; numéro vérifié seulement à la publication", 'Moyen', '360 000 F'],
    ['Hébergement Firebase', "Le back-office passe sur l'hébergement Firebase déjà inclus, au lieu d'un service payant", 'Faible', '144 000 F'],
    ['**Total', '', '', '**813 600 F'],
  ],
  [1900, 4600, 1200, 1500]
));

children.push(h1('Points de vigilance'));

children.push(bulletKV("Le compte Apple est un abonnement annuel, pas un achat. ", "Un oubli de renouvellement retire l'application de l'App Store, et sa remise en ligne impose de repasser toute la revue Apple. À inscrire au calendrier avec une alerte à 30 jours."));
children.push(bulletKV('Les crédits Firebase expirent au bout de 90 jours. ', "Le compteur démarre à l'activation de la facturation, pas à la publication : n'activer le plan payant qu'à l'approche réelle de la mise en production."));
children.push(bulletKV('Les clés Google Maps doivent être restreintes. ', "Une clé non restreinte peut être extraite de l'application et utilisée par un tiers à vos frais. Restriction par application et plafond quotidien obligatoires."));
children.push(bulletKV("L'envoi de SMS peut être attaqué. ", "Des envois déclenchés massivement coûtent plusieurs centaines de dollars en une nuit. La protection App Check doit être activée en mode strict avant l'ouverture au public."));
children.push(bulletKV('Le plan Firebase ne se coupe pas tout seul. ', "Des alertes de budget à 50 %, 90 % et 100 % doivent être posées avant le déploiement, pas après."));

children.push(h1('À faire avant la mise en production'));

children.push(bulletKV('Restreindre les clés Google Maps ', "et poser un plafond de requêtes quotidien."));
children.push(bulletKV('Configurer les alertes de budget ', "Firebase et Google Cloud aux trois seuils."));
children.push(bulletKV('Activer App Check en mode strict ', "sur la base de données, le stockage et les fonctions serveur."));
children.push(bulletKV('Faire confirmer par écrit le taux de commission GeniusPay ', "et l'existence éventuelle de frais fixes par transaction : sur une mise en avant à 5 000 F, un frais fixe pèse plus lourd qu'un pourcentage."));
children.push(bulletKV('Mettre en place les miniatures de photos ', "dès les premiers mois, tant que le volume à traiter est faible."));

children.push(new Paragraph({ spacing: { before: 140, after: 60 } }));

children.push(p(
  "Réserves — Deux montants restent à confirmer : la commission GeniusPay (3 % retenus en hypothèse) et le prix " +
  "d'un domaine .ci (30 000 à 35 000 F par an selon le bureau d'enregistrement). Les tarifs cloud sont ceux publiés " +
  "au 15 août 2026 ; une marge de 15 % est conseillée sur les projections de long terme. Le détail complet des " +
  "calculs figure dans le document BUDGET_MY_HOME_CI.docx.",
  { italic: true, size: 17, color: GRAY }
));

// ══════════════════════════════════════════════════════════════════════════

const doc = new Document({
  creator: 'My Home CI',
  title: "Budget d'exploitation - synthese - My Home CI",
  description: "Synthese budgetaire deux pages - My Home CI",
  numbering: {
    config: [{
      reference: 'bullets',
      levels: [
        { level: 0, format: docx.LevelFormat.BULLET, text: '—', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 460, hanging: 280 } } } },
      ],
    }],
  },
  sections: [{
    properties: { page: { margin: { top: 900, bottom: 800, left: 1000, right: 1000 } } },
    children,
  }],
});

const output = path.join(__dirname, 'BUDGET_SYNTHESE_MY_HOME_CI.docx');
Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(output, buffer);
  console.log('Document genere : ' + output);
  console.log('Taille : ' + Math.round(buffer.length / 1024) + ' Ko');
});
