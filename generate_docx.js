const docx = require('docx');
const fs = require('fs');
const path = require('path');

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, WidthType, BorderStyle,
  TableOfContents, PageBreak, ShadingType,
  ImageRun, Header, Footer, PageNumber,
} = docx;

// Couleurs
const PRIMARY = '2E7D5B';
const SECONDARY = 'F5A623';
const DARK = '1A1A2E';
const GRAY = '6B7280';
const LIGHT_BG = 'F0F4F2';
const WHITE = 'FFFFFF';
const PHONE_BG = 'FAFAFA';
const PHONE_BORDER = '333333';

// Logo
const logoPath = path.join(__dirname, 'assets', 'images', 'logo.png');
const logoExists = fs.existsSync(logoPath);
let logoBuffer = null;
if (logoExists) {
  logoBuffer = fs.readFileSync(logoPath);
  console.log('Logo trouve et charge depuis ' + logoPath);
} else {
  console.log('Logo non trouve a ' + logoPath + ' - un placeholder sera utilise');
}

// Helper: ligne horizontale
function horizontalRule(color = PRIMARY) {
  return new Paragraph({
    spacing: { before: 200, after: 200 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color } },
  });
}

// Helper: paragraphe vide
function emptyPara(spacing = 100) {
  return new Paragraph({ spacing: { before: spacing, after: spacing } });
}

// Helper: texte simple
function textPara(text, opts = {}) {
  const {
    bold = false, italic = false, size = 22, color = DARK,
    alignment = AlignmentType.LEFT, spacing = {}, font = 'Calibri', indent,
  } = opts;
  return new Paragraph({
    alignment, spacing: { before: 60, after: 60, ...spacing }, indent,
    children: [new TextRun({ text, bold, italic, size, color, font })],
  });
}

// Helper: bullet point
function bulletPoint(text, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level },
    spacing: { before: 40, after: 40 },
    children: [new TextRun({ text, size: 22, color: DARK, font: 'Calibri' })],
  });
}

// Helper: bullet gras + normal
function bulletBoldNormal(boldText, normalText, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level },
    spacing: { before: 40, after: 40 },
    children: [
      new TextRun({ text: boldText, bold: true, size: 22, color: DARK, font: 'Calibri' }),
      new TextRun({ text: normalText, size: 22, color: DARK, font: 'Calibri' }),
    ],
  });
}

// Helper: encadre info
function infoBox(text, bgColor = LIGHT_BG, borderColor = PRIMARY) {
  return new Table({
    width: { size: 9000, type: WidthType.DXA },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: 9000, type: WidthType.DXA },
            shading: { type: ShadingType.CLEAR, fill: bgColor },
            borders: {
              top: { style: BorderStyle.SINGLE, size: 1, color: borderColor },
              bottom: { style: BorderStyle.SINGLE, size: 1, color: borderColor },
              left: { style: BorderStyle.SINGLE, size: 8, color: borderColor },
              right: { style: BorderStyle.SINGLE, size: 1, color: borderColor },
            },
            children: [
              new Paragraph({
                spacing: { before: 100, after: 100 },
                indent: { left: 100, right: 100 },
                children: [new TextRun({ text, size: 21, color: DARK, font: 'Calibri', italics: true })],
              }),
            ],
          }),
        ],
      }),
    ],
  });
}

// Helper: tableau
function createTable(headers, rows, colWidths) {
  const totalWidth = colWidths.reduce((a, b) => a + b, 0);
  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) =>
      new TableCell({
        width: { size: colWidths[i], type: WidthType.DXA },
        shading: { type: ShadingType.CLEAR, fill: PRIMARY },
        borders: {
          top: { style: BorderStyle.SINGLE, size: 1, color: PRIMARY },
          bottom: { style: BorderStyle.SINGLE, size: 1, color: PRIMARY },
          left: { style: BorderStyle.SINGLE, size: 1, color: PRIMARY },
          right: { style: BorderStyle.SINGLE, size: 1, color: PRIMARY },
        },
        children: [
          new Paragraph({
            spacing: { before: 60, after: 60 }, alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: h, bold: true, size: 20, color: WHITE, font: 'Calibri' })],
          }),
        ],
      })
    ),
  });
  const dataRows = rows.map((row, rowIdx) =>
    new TableRow({
      children: row.map((cell, i) =>
        new TableCell({
          width: { size: colWidths[i], type: WidthType.DXA },
          shading: { type: ShadingType.CLEAR, fill: rowIdx % 2 === 0 ? WHITE : 'F9FAFB' },
          borders: {
            top: { style: BorderStyle.SINGLE, size: 1, color: 'E5E7EB' },
            bottom: { style: BorderStyle.SINGLE, size: 1, color: 'E5E7EB' },
            left: { style: BorderStyle.SINGLE, size: 1, color: 'E5E7EB' },
            right: { style: BorderStyle.SINGLE, size: 1, color: 'E5E7EB' },
          },
          children: [
            new Paragraph({
              spacing: { before: 40, after: 40 },
              children: [new TextRun({ text: cell, bold: i === 0, size: 20, color: DARK, font: 'Calibri' })],
            }),
          ],
        })
      ),
    })
  );
  return new Table({ width: { size: totalWidth, type: WidthType.DXA }, columnWidths: colWidths, rows: [headerRow, ...dataRows] });
}

// Helper: emplacement capture en forme de telephone
function phoneScreenPlaceholder(number, screenName, role) {
  const phoneBorder = { style: BorderStyle.SINGLE, size: 6, color: PHONE_BORDER };
  const phoneRoundBorder = { style: BorderStyle.SINGLE, size: 3, color: PHONE_BORDER };

  // Table englobante : 2 colonnes [phone frame | description du role]
  return new Table({
    width: { size: 9000, type: WidthType.DXA },
    columnWidths: [3600, 5400],
    rows: [
      new TableRow({
        height: { value: 6000, rule: docx.HeightRule.ATLEAST },
        children: [
          // Colonne gauche : cadre telephone
          new TableCell({
            width: { size: 3600, type: WidthType.DXA },
            verticalAlign: docx.VerticalAlign.CENTER,
            borders: {
              top: { style: BorderStyle.NONE },
              bottom: { style: BorderStyle.NONE },
              left: { style: BorderStyle.NONE },
              right: { style: BorderStyle.NONE },
            },
            children: [
              // Cadre du telephone
              new Table({
                width: { size: 2800, type: WidthType.DXA },
                rows: [
                  // Barre du haut (notch)
                  new TableRow({
                    height: { value: 300, rule: docx.HeightRule.EXACT },
                    children: [
                      new TableCell({
                        width: { size: 2800, type: WidthType.DXA },
                        shading: { type: ShadingType.CLEAR, fill: PHONE_BORDER },
                        borders: {
                          top: phoneBorder,
                          left: phoneBorder,
                          right: phoneBorder,
                          bottom: { style: BorderStyle.NONE },
                        },
                        children: [
                          new Paragraph({
                            alignment: AlignmentType.CENTER,
                            children: [new TextRun({ text: '———', size: 14, color: '666666' })],
                          }),
                        ],
                      }),
                    ],
                  }),
                  // Ecran (zone de capture)
                  new TableRow({
                    height: { value: 5000, rule: docx.HeightRule.ATLEAST },
                    children: [
                      new TableCell({
                        width: { size: 2800, type: WidthType.DXA },
                        shading: { type: ShadingType.CLEAR, fill: PHONE_BG },
                        borders: {
                          top: { style: BorderStyle.NONE },
                          bottom: { style: BorderStyle.NONE },
                          left: phoneBorder,
                          right: phoneBorder,
                        },
                        verticalAlign: docx.VerticalAlign.CENTER,
                        children: [
                          new Paragraph({
                            alignment: AlignmentType.CENTER,
                            spacing: { before: 600, after: 200 },
                            children: [new TextRun({ text: '📱', size: 56 })],
                          }),
                          new Paragraph({
                            alignment: AlignmentType.CENTER,
                            spacing: { before: 100, after: 100 },
                            children: [
                              new TextRun({ text: 'Capture ' + number, bold: true, size: 22, color: PRIMARY, font: 'Calibri' }),
                            ],
                          }),
                          new Paragraph({
                            alignment: AlignmentType.CENTER,
                            spacing: { before: 60, after: 60 },
                            children: [
                              new TextRun({ text: screenName, size: 18, color: GRAY, font: 'Calibri', italics: true }),
                            ],
                          }),
                          new Paragraph({
                            alignment: AlignmentType.CENTER,
                            spacing: { before: 200, after: 600 },
                            children: [
                              new TextRun({ text: '[ Inserer la capture ici ]', size: 18, color: 'BBBBBB', font: 'Calibri' }),
                            ],
                          }),
                        ],
                      }),
                    ],
                  }),
                  // Barre du bas (bouton home)
                  new TableRow({
                    height: { value: 400, rule: docx.HeightRule.EXACT },
                    children: [
                      new TableCell({
                        width: { size: 2800, type: WidthType.DXA },
                        shading: { type: ShadingType.CLEAR, fill: PHONE_BORDER },
                        borders: {
                          top: { style: BorderStyle.NONE },
                          left: phoneBorder,
                          right: phoneBorder,
                          bottom: phoneBorder,
                        },
                        verticalAlign: docx.VerticalAlign.CENTER,
                        children: [
                          new Paragraph({
                            alignment: AlignmentType.CENTER,
                            children: [new TextRun({ text: '○', size: 20, color: '888888' })],
                          }),
                        ],
                      }),
                    ],
                  }),
                ],
              }),
            ],
          }),
          // Colonne droite : description du role
          new TableCell({
            width: { size: 5400, type: WidthType.DXA },
            verticalAlign: docx.VerticalAlign.CENTER,
            borders: {
              top: { style: BorderStyle.NONE },
              bottom: { style: BorderStyle.NONE },
              left: { style: BorderStyle.SINGLE, size: 1, color: 'E5E7EB' },
              right: { style: BorderStyle.NONE },
            },
            children: [
              new Paragraph({
                spacing: { before: 120, after: 60 },
                indent: { left: 200 },
                children: [
                  new TextRun({ text: 'Ecran ' + number, bold: true, size: 26, color: PRIMARY, font: 'Calibri' }),
                ],
              }),
              new Paragraph({
                spacing: { before: 40, after: 80 },
                indent: { left: 200 },
                children: [
                  new TextRun({ text: screenName, bold: true, size: 22, color: DARK, font: 'Calibri' }),
                ],
              }),
              new Paragraph({
                spacing: { before: 40, after: 40 },
                indent: { left: 200 },
                border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: SECONDARY } },
                children: [
                  new TextRun({ text: 'Role de la page :', bold: true, size: 20, color: SECONDARY, font: 'Calibri' }),
                ],
              }),
              new Paragraph({
                spacing: { before: 60, after: 120 },
                indent: { left: 200, right: 100 },
                children: [
                  new TextRun({ text: role, size: 20, color: DARK, font: 'Calibri' }),
                ],
              }),
            ],
          }),
        ],
      }),
    ],
  });
}

// ============================================
// DOCUMENT
// ============================================

// Logo paragraph for cover
const logoParagraph = logoBuffer
  ? new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 200, after: 200 },
      children: [
        new ImageRun({
          data: logoBuffer,
          transformation: { width: 180, height: 180 },
          type: 'png',
        }),
      ],
    })
  : new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 200, after: 200 },
      children: [
        new TextRun({ text: '🏠', size: 72 }),
      ],
    });

const doc = new Document({
  creator: 'MY HOME CI',
  title: 'Cahier des Charges - MY HOME CI',
  description: 'Cahier des charges application mobile MY HOME CI',
  numbering: {
    config: [
      {
        reference: 'bullets',
        levels: [
          { level: 0, format: docx.LevelFormat.BULLET, text: '—', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
          { level: 1, format: docx.LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1440, hanging: 360 } } } },
        ],
      },
      {
        reference: 'ordered',
        levels: [
          { level: 0, format: docx.LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
        ],
      },
    ],
  },
  styles: {
    paragraphStyles: [
      {
        id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal',
        run: { size: 36, bold: true, color: PRIMARY, font: 'Calibri' },
        paragraph: { spacing: { before: 360, after: 200 }, border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: PRIMARY } } },
      },
      {
        id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal',
        run: { size: 28, bold: true, color: '1B5E3B', font: 'Calibri' },
        paragraph: { spacing: { before: 300, after: 160 } },
      },
      {
        id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal',
        run: { size: 24, bold: true, color: DARK, font: 'Calibri' },
        paragraph: { spacing: { before: 240, after: 120 } },
      },
    ],
  },
  sections: [
    // ════════════════════════════════════
    // PAGE DE COUVERTURE
    // ════════════════════════════════════
    {
      properties: { page: { margin: { top: 1440, bottom: 1440, left: 1440, right: 1440 } } },
      children: [
        emptyPara(300),
        horizontalRule(PRIMARY),
        horizontalRule(SECONDARY),
        emptyPara(200),
        // Logo
        logoParagraph,
        emptyPara(100),
        new Paragraph({
          alignment: AlignmentType.CENTER, spacing: { after: 100 },
          children: [new TextRun({ text: 'CAHIER DES CHARGES', bold: true, size: 48, color: PRIMARY, font: 'Calibri' })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER, spacing: { after: 60 },
          children: [new TextRun({ text: 'APPLICATION MOBILE', bold: true, size: 40, color: SECONDARY, font: 'Calibri' })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER, spacing: { after: 200 },
          children: [new TextRun({ text: 'MY HOME CI', bold: true, size: 52, color: PRIMARY, font: 'Calibri' })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER, spacing: { after: 400 },
          children: [new TextRun({ text: 'Plateforme de mise en relation locative en Cote d\'Ivoire', italic: true, size: 24, color: GRAY, font: 'Calibri' })],
        }),
        // Tableau info
        new Table({
          width: { size: 7200, type: WidthType.DXA }, columnWidths: [3000, 4200],
          rows: [
            ['Type', 'Application mobile (Utilitaire / Plateforme collaborative)'],
            ['Secteur', 'Immobilier — Cote d\'Ivoire'],
            ['Cibles', 'Android & iOS — Smartphone & Tablette'],
            ['Langues', 'Francais'],
            ['Monetisation', 'Freemium + Publicite (sans paiement)'],
          ].map((r) =>
            new TableRow({
              children: r.map((cell, i) =>
                new TableCell({
                  width: { size: i === 0 ? 3000 : 4200, type: WidthType.DXA },
                  shading: { type: ShadingType.CLEAR, fill: LIGHT_BG },
                  borders: {
                    top: { style: BorderStyle.SINGLE, size: 1, color: 'D1D5DB' },
                    bottom: { style: BorderStyle.SINGLE, size: 1, color: 'D1D5DB' },
                    left: { style: BorderStyle.SINGLE, size: 1, color: 'D1D5DB' },
                    right: { style: BorderStyle.SINGLE, size: 1, color: 'D1D5DB' },
                  },
                  children: [
                    new Paragraph({
                      alignment: AlignmentType.CENTER, spacing: { before: 60, after: 60 },
                      children: [new TextRun({ text: cell, bold: i === 0, size: 21, color: i === 0 ? PRIMARY : DARK, font: 'Calibri' })],
                    }),
                  ],
                })
              ),
            })
          ),
        }),
        emptyPara(400),
        // Tableau version
        new Table({
          width: { size: 5400, type: WidthType.DXA }, columnWidths: [2700, 2700],
          rows: [
            ['Version du document', '1.0 MVP'],
            ['Date de redaction', '5 aout 2026'],
            ['Statut', 'En cours de validation'],
            ['Confidentialite', 'Confidentiel'],
          ].map((r) =>
            new TableRow({
              children: r.map((cell, i) =>
                new TableCell({
                  width: { size: 2700, type: WidthType.DXA },
                  borders: {
                    top: { style: BorderStyle.NONE },
                    bottom: { style: BorderStyle.SINGLE, size: 1, color: 'D1D5DB' },
                    left: { style: BorderStyle.NONE },
                    right: { style: BorderStyle.NONE },
                  },
                  children: [
                    new Paragraph({
                      spacing: { before: 60, after: 60 },
                      children: [new TextRun({
                        text: cell, bold: i === 0, size: 20, font: 'Calibri',
                        color: i === 0 ? DARK : (cell === 'En cours de validation' ? SECONDARY : (cell === 'Confidentiel' ? '7C3AED' : GRAY)),
                      })],
                    }),
                  ],
                })
              ),
            })
          ),
        }),
        emptyPara(200),
        horizontalRule(SECONDARY),
        horizontalRule(PRIMARY),
      ],
    },

    // ════════════════════════════════════
    // TABLE DES MATIERES
    // ════════════════════════════════════
    {
      properties: { page: { margin: { top: 1440, bottom: 1440, left: 1440, right: 1440 } } },
      children: [
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: 'Table des matieres', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        new TableOfContents('Table des matieres', { hyperlink: true, headingStyleRange: '1-3' }),
      ],
    },

    // ════════════════════════════════════
    // CONTENU PRINCIPAL (Sections 1-11 + Annexe)
    // ════════════════════════════════════
    {
      properties: { page: { margin: { top: 1440, bottom: 1440, left: 1440, right: 1440 } } },
      headers: {
        default: new Header({
          children: [
            new Paragraph({
              alignment: AlignmentType.RIGHT,
              children: [new TextRun({ text: 'MY HOME CI — Cahier des Charges', size: 16, color: GRAY, font: 'Calibri', italics: true })],
            }),
          ],
        }),
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              alignment: AlignmentType.CENTER,
              border: { top: { style: BorderStyle.SINGLE, size: 1, color: 'D1D5DB' } },
              spacing: { before: 100 },
              children: [
                new TextRun({ text: 'Confidentiel — Aout 2026 — Page ', size: 16, color: GRAY, font: 'Calibri' }),
                new TextRun({ children: [PageNumber.CURRENT], size: 16, color: GRAY, font: 'Calibri' }),
              ],
            }),
          ],
        }),
      },
      children: [
        // ── SECTION 1 : Introduction ──
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '1. Introduction et Definitions', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '1.1 Presentation generale du projet', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        infoBox('MY HOME CI est une application mobile dediee au marche locatif ivoirien. Elle connecte directement les proprietaires de logements avec les personnes cherchant a louer, en eliminant les intermediaires et en offrant une experience moderne, geolocalisee et securisee.'),
        emptyPara(60),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '1.1.1 Scenario initial', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        textPara('Le marche immobilier en Cote d\'Ivoire souffre d\'un manque criant de digitalisation dans le segment locatif. Les chercheurs de logements dependent encore largement du bouche-a-oreille, des pancartes "A Louer" et des agences physiques qui prelevent des frais importants. Les proprietaires, de leur cote, peinent a trouver des locataires fiables sans passer par ces intermediaires couteux. MY HOME CI vise a combler ce vide en proposant une plateforme numerique gratuite, intuitive et centree sur la mise en relation directe.'),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '1.1.2 Objet de l\'application', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        textPara('L\'application a pour objet principal de :'),
        bulletPoint('Permettre aux proprietaires de publier et gerer leurs annonces de logements a louer'),
        bulletPoint('Permettre aux chercheurs de logements de rechercher, filtrer et visualiser les offres sur une carte interactive'),
        bulletPoint('Faciliter la communication directe entre proprietaires et locataires potentiels via un chat integre'),
        bulletPoint('Offrir une experience de recherche enrichie grace a la geolocalisation, aux filtres avances et aux alertes personnalisees'),
        bulletPoint('Fournir des informations contextuelles sur les quartiers (commodites, transports, securite)'),
        emptyPara(60),
        infoBox('Important : MY HOME CI ne gere aucun paiement ni transaction financiere. La plateforme se concentre exclusivement sur la mise en relation.', 'FEF3C7', SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '1.1.3 Evolutions envisagees', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        bulletBoldNormal('Phase 1 (MVP) : ', 'Recherche de logements, carte interactive, chat proprietaire-locataire, profils, favoris'),
        bulletBoldNormal('Phase 2 : ', 'Systeme d\'avis et notations, visite virtuelle 360°, alertes intelligentes'),
        bulletBoldNormal('Phase 3 : ', 'Extension geographique a d\'autres villes ivoiriennes puis Afrique de l\'Ouest'),
        bulletBoldNormal('Phase 4 : ', 'Intelligence artificielle pour recommandations personnalisees, estimation de loyer'),
        bulletBoldNormal('Phase 5 : ', 'Module colocation, integration services demenagement, assurance habitation'),

        // 1.2
        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '1.2 Definition des utilisateurs et de leurs roles', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Role', 'Profil', 'Acces & Droits principaux'],
          [
            ['Locataire (Visiteur)', 'Toute personne 18+ cherchant un logement en Cote d\'Ivoire', 'Consultation d\'annonces, geolocalisation, messagerie, favoris, partage reseaux sociaux, alertes'],
            ['Proprietaire', 'Proprietaire individuel ou agence immobiliere', 'Creation de compte, publication d\'annonces, gestion de biens, reception de messages, statistiques basiques'],
            ['Administrateur', 'Equipe interne MY HOME CI', 'Moderation, gestion des utilisateurs, analytics, signalements'],
          ],
          [2000, 3000, 4000]
        ),
        emptyPara(80),
        infoBox('Precision importante : Les locataires peuvent utiliser l\'application sans inscription prealable pour consulter les annonces. L\'inscription est requise uniquement pour envoyer des messages, sauvegarder des favoris et creer des alertes. La creation de compte proprietaire necessite une verification d\'identite.'),

        // 1.3
        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '1.3 Definitions metier', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        bulletBoldNormal('Logement : ', 'Bien immobilier mis en location sur la plateforme (appartement, studio, villa, chambre, duplex, terrain, local commercial)'),
        bulletBoldNormal('Annonce : ', 'Fiche descriptive d\'un logement creee par un proprietaire, contenant photos, description, loyer, localisation, caracteristiques'),
        bulletBoldNormal('Proprietaire : ', 'Personne physique ou morale ayant cree un compte professionnel et publie au moins une annonce'),
        bulletBoldNormal('Locataire : ', 'Utilisateur de l\'application cherchant un logement a louer'),
        bulletBoldNormal('Favori : ', 'Annonce sauvegardee par un locataire pour consultation ulterieure'),
        bulletBoldNormal('Alerte : ', 'Notification automatique envoyee a un locataire lorsqu\'un nouveau logement correspond a ses criteres de recherche'),
        bulletBoldNormal('Badge verifie : ', 'Marqueur attribue aux proprietaires ayant fourni des pieces d\'identite valides'),
        bulletBoldNormal('MVP : ', 'Minimum Viable Product — version minimale fonctionnelle deployable pour tester le marche'),

        // ── SECTION 2 : Modele Economique ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '2. Modele Economique', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '2.1 Types de monetisation', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        textPara('MY HOME CI repose sur un modele economique freemium combine a la publicite in-app. Aucune commission sur transaction n\'est prelevee (pas de paiement integre).'),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '2.1.1 Grille tarifaire', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        createTable(
          ['Service', 'Description', 'Tarif estime'],
          [
            ['Publication annonce (gratuit)', '3 annonces standard offertes par mois', 'Gratuit'],
            ['Annonce Boost', 'Mise en avant dans les resultats pendant 7 jours', '3 000 — 10 000 XOF/sem.'],
            ['Pack Pro Proprietaire', 'Annonces illimitees + badge verifie + statistiques detaillees', '15 000 XOF/mois'],
            ['Publicite display', 'Affichage de publicites tierces dans l\'app', 'CPM / CPC negocie'],
          ],
          [2500, 4000, 2500]
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '2.1.2 Modele publicitaire', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        bulletBoldNormal('Formats publicitaires : ', 'Bannieres en bas d\'ecran, publicites natives integrees au fil d\'annonces'),
        bulletBoldNormal('Ciblage : ', 'Geographique (villes CI), demographique (18+), comportemental (recherches dans l\'app)'),
        bulletBoldNormal('Regle d\'affichage : ', 'Maximum 1 publicite toutes les 6 annonces consultees'),
        bulletBoldNormal('Mode gratuit : ', 'Les utilisateurs gratuits voient les publicites. Le Pack Pro les masque'),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '2.1.3 Economie gratuite et freemium', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        createTable(
          ['Fonctionnalite', 'Gratuit', 'Pro'],
          [
            ['Consultation d\'annonces', '✓', '✓'],
            ['Geolocalisation / Carte', '✓', '✓'],
            ['Messagerie proprietaire-locataire', '✓', '✓'],
            ['3 annonces/mois (proprietaire)', '✓', '✓'],
            ['Annonces illimitees', '—', '✓'],
            ['Annonces Boost', '—', '✓'],
            ['Statistiques detaillees', '—', '✓'],
            ['Sans publicites', '—', '✓'],
            ['Badge proprietaire verifie', '—', '✓'],
          ],
          [4500, 2250, 2250]
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '2.1.4 Projection financiere — Base 10 000+ utilisateurs', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        createTable(
          ['Source de revenu', 'Hypothese', 'Revenu/mois (XOF)', 'Revenu/an (XOF)'],
          [
            ['Pack Pro proprietaires (5%)', '500 x 15 000', '7 500 000', '90 000 000'],
            ['Annonces Boost', '300 x 5 000', '1 500 000', '18 000 000'],
            ['Publicite display (CPM)', 'Estime', '500 000', '6 000 000'],
            ['TOTAL ESTIME', '', '9 500 000', '114 000 000'],
          ],
          [2500, 2000, 2250, 2250]
        ),

        // 2.2
        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '2.2 Analyse concurrentielle', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Concurrent', 'Forces', 'Faiblesses face a MY HOME CI'],
          [
            ['Jumia House CI', 'Presence panafricaine, notoriete', 'Interface peu mobile-first, pas de chat integre'],
            ['CoinAfrique', 'Marketplace generale populaire', 'Pas specialise immobilier, pas de carte'],
            ['Groupes Facebook', 'Grande audience, gratuit', 'Pas de filtres, pas de geolocalisation, arnaques'],
            ['Agences physiques', 'Confiance, visites physiques', 'Frais eleves, pas digital'],
            ['MY HOME CI', 'Mobile-first, carte, chat direct, gratuit, verifie', 'A construire'],
          ],
          [2500, 3000, 3500]
        ),

        // ── SECTION 3 : User Stories ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '3. User Stories et Cas d\'Utilisation', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '3.1 Cas d\'utilisation — Locataire (Visiteur)', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['ID', 'En tant que locataire, je peux...', 'Relation'],
          [
            ['UC-L01', 'Consulter la liste des logements disponibles', '—'],
            ['UC-L02', 'Filtrer les logements par loyer, localisation, type, nombre de pieces', 'include UC-L01'],
            ['UC-L03', 'Visualiser les logements sur une carte interactive', 'include UC-L01'],
            ['UC-L04', 'Consulter la fiche detaillee d\'un logement', 'extend UC-L01'],
            ['UC-L05', 'Voir les photos d\'un logement en plein ecran', 'include UC-L04'],
            ['UC-L06', 'Contacter un proprietaire par messagerie', 'extend UC-L04'],
            ['UC-L07', 'Ajouter un logement a mes favoris', 'extend UC-L04'],
            ['UC-L08', 'Partager une annonce sur les reseaux sociaux', 'extend UC-L04'],
            ['UC-L09', 'Creer une alerte pour nouveaux logements correspondants', 'extend UC-L02'],
            ['UC-L10', 'Recevoir des notifications push', '—'],
            ['UC-L11', 'Consulter les informations du quartier', 'extend UC-L04'],
            ['UC-L12', 'Comparer plusieurs logements cote a cote', 'extend UC-L07'],
            ['UC-L13', 'Signaler une annonce frauduleuse', 'extend UC-L04'],
          ],
          [1200, 5400, 2400]
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '3.2 Cas d\'utilisation — Proprietaire', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['ID', 'En tant que proprietaire, je peux...', 'Relation'],
          [
            ['UC-P01', 'Creer un compte / Me connecter', '—'],
            ['UC-P02', 'Publier une annonce de logement', 'include UC-P01'],
            ['UC-P03', 'Ajouter des photos a mon annonce', 'include UC-P02'],
            ['UC-P04', 'Geolocaliser mon bien sur la carte', 'include UC-P02'],
            ['UC-P05', 'Modifier / Supprimer / Archiver une annonce', 'extend UC-P02'],
            ['UC-P06', 'Recevoir et repondre aux messages', 'extend UC-P01'],
            ['UC-P07', 'Consulter les statistiques de mes annonces', 'extend UC-P01'],
            ['UC-P08', 'Marquer un logement comme "Loue"', 'extend UC-P05'],
            ['UC-P09', 'Recevoir des notifications push', '—'],
            ['UC-P10', 'Faire verifier mon profil (badge)', 'extend UC-P01'],
          ],
          [1200, 5400, 2400]
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '3.3 Cas d\'utilisation — Administrateur', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['ID', 'En tant qu\'administrateur, je peux...'],
          [
            ['UC-A01', 'Gerer les comptes utilisateurs (suspension, validation)'],
            ['UC-A02', 'Moderer les annonces (signalements, suppression)'],
            ['UC-A03', 'Parametrer les publicites et campagnes'],
            ['UC-A04', 'Consulter les analytics (trafic, conversions, revenus)'],
            ['UC-A05', 'Gerer les packs Pro et abonnements'],
            ['UC-A06', 'Envoyer des notifications push globales'],
            ['UC-A07', 'Verifier les profils proprietaires (badge)'],
          ],
          [1200, 7800]
        ),

        // ── SECTION 4 : Specifications UX ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '4. Specifications UX — Ecrans et Fonctionnalites', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),
        textPara('L\'application est structuree en 10 ecrans principaux pour le MVP.', { bold: true }),

        // Ecrans 1-10
        ...[
          { title: '4.1 Ecran 1 — Splash Screen & Onboarding', items: [
            'Logo anime MY HOME CI avec slogan "Trouvez votre chez-vous"',
            '3 pages d\'onboarding illustrees (Explorez / Contactez / Sauvegardez)',
            'Bouton "Commencer" / "Passer"',
            'Affiche une seule fois au premier lancement',
          ]},
          { title: '4.2 Ecran 2 — Authentification', items: [
            'Banniere "Parcourir en tant que visiteur" prominente en haut de page — acces direct a l\'application sans inscription',
            'Connexion par telephone (OTP SMS) ou email/mot de passe',
            'Connexion sociale (Google)',
            'Differenciation des roles : "Je cherche un logement" / "Je suis proprietaire"',
            'Formulaire d\'inscription complet : nom, telephone, email, mot de passe, confirmation, CGU',
            'Formulaire de creation de compte proprietaire avec verification',
            'Formulaire entierement scrollable (pas de contenu tronque)',
          ]},
          { title: '4.3 Ecran 3 — Page d\'accueil', items: [
            'Barre de recherche prominente avec auto-completion',
            'Chips de filtres rapides : Studio, Appartement, Villa, Chambre, Bureau',
            'Section "Pres de vous" avec logements geolocalises',
            'Section "Annonces recentes" avec carrousel horizontal',
            'Section "Quartiers populaires" (Cocody, Plateau, Marcory, Yopougon...)',
            'Navigation bottom bar : Accueil | Carte | Favoris | Messages | Profil',
          ]},
          { title: '4.4 Ecran 4 — Carte Interactive', items: [
            'Carte Google Maps integree avec marqueurs de logements',
            'Clustering de marqueurs pour les zones denses',
            'Fiche resume cliquable (preview card) depuis la carte',
            'Geolocalisation de l\'utilisateur en temps reel',
            'Filtre de distance (500m, 1km, 3km, 5km, 10km)',
            'Bouton de recentrage sur position actuelle',
          ]},
          { title: '4.5 Ecran 5 — Liste des logements', items: [
            'Affichage en grille (2 colonnes) ou en liste',
            'Carte : photo, titre, loyer/mois, localisation, badge verifie, nombre de pieces',
            'Tri : prix croissant/decroissant, plus recent, plus proche',
            'Filtres avances : type, fourchette de loyer, pieces, meuble, quartier',
            'Pagination infinie (lazy loading)',
          ]},
          { title: '4.6 Ecran 6 — Fiche detail logement', items: [
            'Galerie photos horizontale scrollable avec mode plein ecran',
            'Titre, loyer mensuel en XOF, localisation',
            'Caracteristiques en grille : surface, pieces, salle de bain, etage, parking',
            'Equipements : eau, electricite, climatisation, internet, gardien, piscine...',
            'Mini-carte avec position du logement',
            'Section "Decouvrir le quartier" : commerces, ecoles, pharmacies, transports',
            'Bouton principal "Contacter le proprietaire" (ouvre le chat)',
            'Profil resume du proprietaire avec badge verifie',
          ]},
          { title: '4.7 Ecran 7 — Messagerie / Chat', items: [
            'Liste des conversations recentes avec apercu du dernier message',
            'Interface de chat style WhatsApp : textes, photos, horodatage',
            'Indicateur de lecture (vu / non vu) et "en train d\'ecrire..."',
            'Preview du logement concerne en haut de la conversation',
            'Notifications push en temps reel',
          ]},
          { title: '4.8 Ecran 8 — Espace Proprietaire', items: [
            'Resume : nombre d\'annonces actives, vues totales, messages recus',
            'Liste de mes annonces avec statut (active, en attente, louee, archivee)',
            'Bouton "Publier une nouvelle annonce"',
            'Gestion rapide : modifier, archiver, marquer comme "loue"',
          ]},
          { title: '4.9 Ecran 9 — Publier / Modifier une annonce', items: [
            'Formulaire multi-etapes (6 etapes) :',
            '  1. Type de bien  2. Localisation  3. Details  4. Equipements  5. Photos  6. Loyer',
            'Sauvegarde en brouillon possible',
            'Modification d\'une annonce existante',
          ]},
          { title: '4.10 Ecran 10 — Profil / Parametres', items: [
            'Photo de profil et informations personnelles',
            'Mes favoris et mes alertes de recherche',
            'Parametres : notifications, mode clair/sombre, a propos, CGU',
            'Deconnexion et suppression du compte',
          ]},
        ].flatMap(screen => [
          new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: screen.title, bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
          ...screen.items.map(item => bulletPoint(item)),
          emptyPara(40),
        ]),

        // 4.11 Design
        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '4.11 Design et charte graphique', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Element', 'Specification'],
          [
            ['Inspiration visuelle', 'Airbnb + LeBonCoin : moderne, epure, chaleureux'],
            ['Couleur primaire', 'Vert emeraude (#2E7D5B)'],
            ['Couleur secondaire', 'Orange dore (#F5A623)'],
            ['Couleur de fond', 'Blanc (#FFFFFF) et Gris tres clair (#F5F5F5)'],
            ['Police', 'Poppins (titres), Inter (corps de texte)'],
            ['Icones', 'Lucide Icons, style outline coherent'],
            ['Effets visuels', 'Ombres douces, coins arrondis (12px), transitions fluides'],
            ['Modes', 'Clair et Sombre obligatoires'],
          ],
          [3000, 6000]
        ),

        // ── SECTION 5 : Contraintes ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '5. Contraintes Metier et Logistiques', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '5.1 Contraintes techniques', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Contrainte', 'Description', 'Priorite'],
          [
            ['Plateformes', 'Android ET iOS obligatoires', 'Critique'],
            ['Framework', 'Flutter (cross-platform)', 'Critique'],
            ['Backend', 'Firebase (Auth, Firestore, Storage, FCM)', 'Critique'],
            ['Performances', 'Fluide, < 2s de chargement', 'Critique'],
            ['Mode hors connexion', 'Consultation des annonces recentes sans internet', 'Haute'],
            ['Securite', 'HTTPS, chiffrement des donnees, anti-injection', 'Critique'],
            ['Langue', 'Francais', 'Critique'],
            ['Notifications push', 'Firebase Cloud Messaging', 'Haute'],
            ['Scalabilite', 'Infrastructure prevue pour 500k+ utilisateurs', 'Haute'],
          ],
          [2500, 4500, 2000]
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '5.2 Contraintes de securite', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        bulletPoint('Chiffrement TLS/HTTPS pour toutes les communications'),
        bulletPoint('Regles de securite Firestore strictes (lecture/ecriture par role)'),
        bulletPoint('Limitation du nombre de tentatives de connexion (anti-brute force)'),
        bulletPoint('Conformite aux reglementations locales de protection des donnees'),
        bulletPoint('Authentification securisee (Firebase Auth + OTP)'),
        bulletPoint('Moderation des contenus publies (signalement + revue admin)'),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '5.3 Objectifs qualitatifs et quantitatifs', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        textPara('Le service doit etre fiable, fluide, facile a utiliser et optimise pour les reseaux 3G/4G ivoiriens.'),
        createTable(
          ['Indicateur', 'Cible'],
          [
            ['Volume de trafic vise', 'Plus de 100 000 sessions/mois'],
            ['Telechargements vises', '500 000 en 2 ans'],
            ['Annonces actives', '10 000+ a 1 an'],
            ['Utilisateurs long terme', '1 million d\'abonnes'],
            ['Cible geographique', 'Abidjan et grandes villes CI (18+)'],
            ['Temps de chargement', '< 2 secondes'],
            ['Disponibilite', '99.5% uptime'],
          ],
          [4500, 4500]
        ),

        // ── SECTION 6 : MVP ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '6. Cahier des Charges MVP', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '6.1 Perimetre du MVP', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        infoBox('Principe : Lancer rapidement, apprendre des utilisateurs, iterer. Le MVP permet une utilisation complete du cycle principal (chercher un logement → contacter le proprietaire).'),
        emptyPara(60),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '6.1.1 Fonctionnalites incluses dans le MVP', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        ...[
          'Splash & Onboarding : premiere impression soignee',
          'Authentification : inscription/connexion proprietaire, mode invite locataire',
          'Page d\'accueil avec recherche, filtres rapides, sections recommandees',
          'Carte interactive avec geolocalisation et marqueurs',
          'Liste des logements avec filtres avances et tri',
          'Fiche detail complete avec photos, description, caracteristiques, quartier',
          'Messagerie temps reel proprietaire-locataire',
          'Espace proprietaire : publication et gestion d\'annonces',
          'Favoris : sauvegarde d\'annonces',
          'Profil & Parametres : gestion du compte, mode sombre/clair',
        ].map(item => new Paragraph({
          numbering: { reference: 'ordered', level: 0 },
          spacing: { before: 40, after: 40 },
          children: [new TextRun({ text: item, size: 22, color: DARK, font: 'Calibri' })],
        })),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '6.1.2 Fonctionnalites exclues du MVP (Phase 2+)', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        bulletPoint('Systeme d\'avis et notations des proprietaires'),
        bulletPoint('Visite virtuelle 360 degres'),
        bulletPoint('Alertes intelligentes avec IA'),
        bulletPoint('Module colocation'),
        bulletPoint('Estimation automatique de loyer'),
        bulletPoint('Extension hors Abidjan'),
        bulletPoint('Pack Pro / Monetisation'),

        new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: '6.1.3 Recapitulatif technique du MVP', bold: true, size: 24, color: DARK, font: 'Calibri' })] }),
        createTable(
          ['Element', 'Specification'],
          [
            ['Type de solution', 'Application mobile cross-platform (Flutter)'],
            ['Plateformes', 'Android ET iOS'],
            ['Supports', 'Smartphone ET Tablette'],
            ['Backend', 'Firebase (Spark gratuit au demarrage)'],
            ['Nombre d\'ecrans MVP', '10 ecrans principaux'],
            ['Langue', 'Francais'],
            ['Paiement MVP', 'Non inclus (aucun paiement)'],
            ['Analytiques', 'Firebase Analytics (base)'],
          ],
          [3500, 5500]
        ),

        // ── SECTION 7 : Budget ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '7. Budget Infrastructure et Outils', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),
        infoBox('Note : Le budget developpement humain (salaires, freelances) est non inclus dans ce tableau. Ce tableau couvre uniquement les outils et services a souscrire.', 'FEF3C7', SECONDARY),
        emptyPara(60),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '7.1 Budget Developpement et Outils', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Categorie', 'Outil / Service', 'Cout/mois (USD)', 'Cout/an (XOF)', 'Priorite'],
          [
            ['Backend Cloud', 'Firebase (Spark → Blaze)', '$0–100', '0 – 720 000', 'Critique'],
            ['Cartographie', 'Google Maps Platform', '$0–200*', '0 – 1 440 000', 'Critique'],
            ['Notifications', 'Firebase Cloud Messaging', 'Gratuit', '0', 'Critique'],
            ['Analytics', 'Firebase Analytics', 'Gratuit', '0', 'Haute'],
            ['Messagerie', 'Firebase Firestore', '$0–50', '0 – 360 000', 'Critique'],
            ['Stockage', 'Firebase Storage', '$5–50', '36 000 – 360 000', 'Critique'],
            ['Publicite', 'Google AdMob', 'Gratuit', 'Revenus', 'Haute'],
            ['Publication', 'Google Play ($25 unique)', '$25', '18 000', 'Critique'],
            ['Publication', 'Apple Developer ($99/an)', '$99/an', '712 800', 'Critique'],
            ['Monitoring', 'Firebase Crashlytics', 'Gratuit', '0', 'Haute'],
            ['CI/CD', 'GitHub Actions', '$0–49', '0 – 352 800', 'Haute'],
          ],
          [1600, 2400, 1600, 1800, 1600]
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '7.2 Recapitulatif budgetaire annuel', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Configuration', 'Cout annuel estime (XOF)'],
          [
            ['Fourchette basse (outils gratuits)', '~ 766 800 XOF/an'],
            ['Fourchette haute (config complete)', '~ 2 530 800 XOF/an'],
          ],
          [4500, 4500]
        ),
        emptyPara(60),
        infoBox('Recommandation : Partir avec la fourchette basse (outils gratuits et freemium) pour le MVP. Firebase offre une formule Spark (gratuite) tres genereuse pour le lancement.'),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '7.3 Budget previsionnel de developpement', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Phase', 'Description', 'Fourchette estimee (XOF)'],
          [
            ['Design UX/UI', 'Maquettes Figma, prototypes', '300 000 — 1 500 000'],
            ['Developpement MVP', '10 ecrans, Firebase, carte, chat', '2 000 000 — 10 000 000'],
            ['Tests et QA', 'Tests fonctionnels, performance', '200 000 — 800 000'],
            ['Deploiement Stores', 'Publication + suivi', '100 000 — 400 000'],
            ['Maintenance (an 1)', 'Corrections de bugs, mises a jour', '300 000 — 1 500 000'],
            ['TOTAL', '', '2 900 000 — 14 200 000 XOF'],
          ],
          [2500, 3500, 3000]
        ),

        // ── SECTION 8 : Plateforme et Originalite ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '8. Plateforme, Coeur de Metier et Originalite', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '8.1 Coeur de metier', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        textPara('MY HOME CI est une plateforme de mise en relation locative mobile-first dediee au marche ivoirien. Elle connecte proprietaires et chercheurs de logements dans un ecosysteme simple, transparent et gratuit, sans intermediaires ni frais de commission.'),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '8.2 Originalite et differenciation', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        bulletBoldNormal('Zero intermediaire : ', 'Mise en relation directe proprietaire-locataire, aucun frais cache'),
        bulletBoldNormal('Mobile-first Africa : ', 'Concue pour les contraintes reseau africaines (3G, optimisation bande passante)'),
        bulletBoldNormal('Carte interactive locale : ', 'Navigation visuelle adaptee aux communes d\'Abidjan'),
        bulletBoldNormal('Chat integre securise : ', 'Communication directe sans echanger de numeros de telephone'),
        bulletBoldNormal('Verification proprietaire : ', 'Badge "Verifie" pour reduire les arnaques'),
        bulletBoldNormal('Informations quartier : ', 'Donnees contextuelles (commerces, ecoles, transports)'),
        bulletBoldNormal('Gratuit et accessible : ', 'Consultation et mise en relation toujours gratuites'),
        bulletBoldNormal('Mode hors connexion : ', 'Consultation des annonces vues recemment sans internet'),

        new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: '8.3 Inspirations et modeles de reference', bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })] }),
        createTable(
          ['Reference', 'Ce qu\'on en retient'],
          [
            ['Airbnb', 'Photos immersives, fiche logement detaillee, UX de recherche'],
            ['LeBonCoin', 'Simplicite, rapidite, filtres efficaces'],
            ['Jumia House', 'Adaptation marche africain, categories locales'],
            ['WhatsApp', 'Messagerie fluide et familiere'],
            ['Google Maps', 'Navigation carte, fiches de lieux'],
          ],
          [2500, 6500]
        ),

        // ── SECTION 9 : Planning ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '9. Planning Previsionnel', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),
        createTable(
          ['Phase', 'Duree estimee', 'Livrables'],
          [
            ['Phase 0 — Cadrage', '1 semaine', 'Cahier des charges valide, charte graphique'],
            ['Phase 1 — Design UI', '2 semaines', 'Maquettes Flutter (interfaces sans logique)'],
            ['Phase 2 — Validation client', '1 semaine', 'Screenshots valides, ajustements UI'],
            ['Phase 3 — Developpement MVP', '6–8 semaines', 'App fonctionnelle avec Firebase'],
            ['Phase 4 — Tests & QA', '2 semaines', 'Tests fonctionnels, corrections'],
            ['Phase 5 — Deploiement', '1 semaine', 'Publication Google Play + App Store'],
            ['Phase 6 — Lancement beta', '2 semaines', 'Beta test avec utilisateurs reels'],
          ],
          [2500, 2500, 4000]
        ),

        // ── SECTION 10 : Maquettes / Captures d'ecran ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '10. Maquettes de l\'application — Captures d\'ecran', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),
        infoBox('Cette section presente les maquettes de chaque ecran de l\'application sous forme de captures realisees sur appareil Android. Chaque maquette est accompagnee d\'une description du role de la page. Les emplacements seront completes apres validation des interfaces par le client.'),
        emptyPara(100),

        // 10 emplacements en forme de telephone avec role
        ...[
          {
            num: '1', name: 'Splash Screen & Onboarding',
            role: 'Premier contact de l\'utilisateur avec l\'application. L\'ecran Splash affiche le logo et le slogan MY HOME CI pendant le chargement. L\'Onboarding (3 pages) presente les fonctionnalites cles : recherche geolocalisee, contact direct proprietaire, et sauvegarde de favoris. Il guide l\'utilisateur vers l\'inscription ou le mode invite.',
          },
          {
            num: '2', name: 'Authentification (Connexion / Inscription)',
            role: 'Point d\'entree de l\'application. En haut, une banniere "Parcourir en tant que visiteur" permet d\'explorer l\'app sans inscription. En dessous, deux onglets (Connexion / Inscription) avec formulaires complets et scrollables. L\'inscription inclut le choix du role (locataire/proprietaire), nom, telephone, email, mot de passe avec confirmation, et acceptation des CGU. Connexion Google egalement disponible.',
          },
          {
            num: '3', name: 'Page d\'accueil',
            role: 'Hub central de navigation. Affiche la barre de recherche, les filtres rapides par type de bien, les logements proches de l\'utilisateur, les quartiers populaires d\'Abidjan, et les annonces recentes. La bottom navigation bar donne acces aux 5 sections principales : Accueil, Carte, Favoris, Messages, Profil.',
          },
          {
            num: '4', name: 'Carte Interactive',
            role: 'Visualisation geographique de tous les logements disponibles sur une carte Google Maps. Les marqueurs representent chaque annonce. L\'utilisateur peut filtrer par distance, voir sa position en temps reel, et cliquer sur un marqueur pour afficher un apercu du logement. Essentiel pour la recherche par localisation.',
          },
          {
            num: '5', name: 'Liste des logements',
            role: 'Catalogue complet des annonces avec affichage en grille ou en liste. Propose des filtres avances (type, prix, nombre de pieces, meuble, quartier) et des options de tri (prix, date, distance). Chaque carte affiche la photo, le titre, le loyer, la localisation et le badge verifie.',
          },
          {
            num: '6', name: 'Fiche detail logement',
            role: 'Page complete d\'une annonce avec galerie photos, description detaillee, caracteristiques (surface, pieces, etage), equipements disponibles, mini-carte de localisation, informations sur le quartier et profil du proprietaire. Le bouton "Contacter le proprietaire" ouvre directement le chat pour entamer la communication.',
          },
          {
            num: '7', name: 'Messagerie / Chat',
            role: 'Systeme de communication directe entre locataires et proprietaires. L\'ecran liste affiche les conversations recentes avec apercu et badge de messages non lus. Le chat detail offre une interface style WhatsApp avec historique des messages, envoi de textes et photos, et apercu du logement concerne en en-tete.',
          },
          {
            num: '8', name: 'Espace Proprietaire (Tableau de bord)',
            role: 'Interface de gestion reservee aux proprietaires. Affiche les statistiques cles (annonces actives, vues, messages), la liste de leurs biens avec statut (active/en attente/louee/archivee), et des actions rapides : publier une nouvelle annonce, modifier, archiver ou marquer comme loue un bien existant.',
          },
          {
            num: '9', name: 'Publier / Modifier une annonce',
            role: 'Formulaire multi-etapes (6 etapes) pour creer ou modifier une annonce : 1) Type de bien, 2) Localisation sur carte, 3) Details (surface, pieces, description), 4) Equipements disponibles, 5) Photos du logement, 6) Loyer mensuel et conditions. Permet la sauvegarde en brouillon.',
          },
          {
            num: '10', name: 'Profil & Parametres',
            role: 'Gestion du compte utilisateur : photo, informations personnelles, acces aux favoris et alertes de recherche. Parametres de l\'application : activation/desactivation des notifications, basculement mode clair/sombre, informations legales (CGU, politique de confidentialite), deconnexion et suppression du compte.',
          },
        ].flatMap(s => [
          new Paragraph({
            heading: HeadingLevel.HEADING_2,
            children: [new TextRun({ text: '10.' + s.num + ' ' + s.name, bold: true, size: 28, color: '1B5E3B', font: 'Calibri' })],
          }),
          emptyPara(40),
          phoneScreenPlaceholder(s.num, s.name, s.role),
          emptyPara(60),
          new Paragraph({
            border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: 'E5E7EB' } },
            spacing: { before: 40, after: 120 },
            children: [],
          }),
        ]),

        // ── SECTION 11 : Conclusion ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: '11. Conclusion', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),
        textPara('Le present cahier des charges definit les bases solides pour le developpement de MY HOME CI, plateforme de mise en relation locative mobile dediee a la Cote d\'Ivoire.'),
        emptyPara(60),
        textPara('Les points cles a retenir sont :', { bold: true }),
        bulletPoint('Application mobile Android & iOS, cross-platform Flutter (smartphone + tablette)'),
        bulletPoint('Cible : toute personne 18 ans et plus en Cote d\'Ivoire'),
        bulletBoldNormal('Aucun paiement integre', ' — plateforme de mise en relation pure'),
        bulletPoint('Modele economique freemium + publicite'),
        bulletPoint('MVP : 10 ecrans fonctionnels, geolocalisation, chat integre, mode clair/sombre'),
        bulletPoint('Infrastructure Firebase (gratuite au demarrage), evolutive'),
        bulletBoldNormal('Budget outils estime : ', '766 800 — 2 530 800 XOF/an'),
        bulletBoldNormal('Budget developpement estime : ', '2 900 000 — 14 200 000 XOF'),
        emptyPara(100),
        textPara('Ce document est un document vivant qui evoluera en fonction des retours du prestataire technique, des validations du commanditaire et des apprentissages issus du terrain.', { italic: true }),
        emptyPara(100),

        // Prochaines etapes
        new Table({
          width: { size: 9000, type: WidthType.DXA },
          rows: [
            new TableRow({
              children: [
                new TableCell({
                  width: { size: 9000, type: WidthType.DXA },
                  shading: { type: ShadingType.CLEAR, fill: LIGHT_BG },
                  borders: {
                    top: { style: BorderStyle.SINGLE, size: 2, color: PRIMARY },
                    bottom: { style: BorderStyle.SINGLE, size: 2, color: PRIMARY },
                    left: { style: BorderStyle.SINGLE, size: 2, color: PRIMARY },
                    right: { style: BorderStyle.SINGLE, size: 2, color: PRIMARY },
                  },
                  children: [
                    new Paragraph({
                      alignment: AlignmentType.CENTER, spacing: { before: 120, after: 80 },
                      children: [new TextRun({ text: 'Prochaines etapes :', bold: true, size: 24, color: PRIMARY, font: 'Calibri' })],
                    }),
                    ...['Validation du cahier des charges par toutes les parties', 'Finalisation des maquettes UI (interfaces Flutter)', 'Validation des captures d\'ecran par le client', 'Developpement du MVP (integration Firebase)', 'Tests utilisateurs et lancement beta'].map(step =>
                      new Paragraph({
                        numbering: { reference: 'ordered', level: 0 },
                        spacing: { before: 30, after: 30 }, indent: { left: 400 },
                        children: [new TextRun({ text: step, size: 21, color: DARK, font: 'Calibri' })],
                      })
                    ),
                    emptyPara(60),
                  ],
                }),
              ],
            }),
          ],
        }),

        // ── ANNEXE A ──
        new Paragraph({ children: [new PageBreak()] }),
        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: 'Annexe A — Recapitulatif du formulaire initial', bold: true, size: 36, color: PRIMARY, font: 'Calibri' })] }),
        horizontalRule(SECONDARY),
        createTable(
          ['Champ', 'Valeur renseignee'],
          [
            ['Nom du projet', 'MY HOME CI'],
            ['Services/produits', 'Mise en relation locative (immobilier)'],
            ['Axes de developpement', 'Recherche logements, carte, messagerie, favoris, alertes'],
            ['Concurrent principal', 'Jumia House CI, CoinAfrique, Groupes Facebook'],
            ['Solution actuelle', 'Application mobile Flutter'],
            ['Plateformes', 'Android et iOS'],
            ['Hebergement', 'Firebase (Spark puis Blaze)'],
            ['Nombre d\'ecrans MVP', '10 ecrans'],
            ['Type de monetisation', 'Freemium + Publicite'],
            ['Paiements a integrer', 'Aucun (mise en relation uniquement)'],
            ['Objectifs qualitatifs', 'Fiable, fluide, facile a utiliser, peu energivore'],
            ['Objectifs quantitatifs', '500 000 telechargements en 2 ans'],
            ['Cibles', 'Toutes personnes 18+, Cote d\'Ivoire'],
            ['OS cibles', 'Android ET iOS'],
            ['Langue', 'Francais'],
            ['Inspiration visuelle', 'Airbnb (immersif) + LeBonCoin (simple, rapide)'],
          ],
          [3000, 6000]
        ),
      ],
    },
  ],
});

Packer.toBuffer(doc).then((buffer) => {
  const outPath = path.join(__dirname, 'CAHIER_DES_CHARGES_MY_HOME_CI.docx');
  fs.writeFileSync(outPath, buffer);
  console.log('Document Word genere avec succes : ' + outPath);
  console.log('Taille : ' + (buffer.length / 1024).toFixed(1) + ' Ko');
}).catch(err => {
  console.error('Erreur lors de la generation :', err);
});
