import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';

enum LegalDocument {
  terms,
  privacy,
  about;

  String get title {
    switch (this) {
      case LegalDocument.terms:
        return 'Conditions generales d\'utilisation';
      case LegalDocument.privacy:
        return 'Politique de confidentialite';
      case LegalDocument.about:
        return 'A propos';
    }
  }
}

/// Textes légaux embarqués dans l'application.
///
/// Embarqués, et non chargés depuis une URL : Apple exige que les conditions
/// et la politique de confidentialité soient consultables sans connexion et
/// sans quitter l'application. Une version web identique doit exister par
/// ailleurs — Google Play réclame une URL publique — mais elle ne remplace pas
/// celle-ci.
///
/// ⚠️ Ces textes sont une base de travail rédigée pour couvrir les exigences
/// des stores. Ils doivent être relus par un juriste connaissant le droit
/// ivoirien des données personnelles avant la publication.
class LegalScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          document.title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _sectionsFor(document)
              .map((s) => _Section(section: s, isDark: isDark))
              .toList(),
        ),
      ),
    );
  }

  List<_LegalSection> _sectionsFor(LegalDocument doc) {
    switch (doc) {
      case LegalDocument.terms:
        return _terms;
      case LegalDocument.privacy:
        return _privacy;
      case LegalDocument.about:
        return _about;
    }
  }
}

class _LegalSection {
  final String? heading;
  final String body;
  const _LegalSection({this.heading, required this.body});
}

class _Section extends StatelessWidget {
  final _LegalSection section;
  final bool isDark;

  const _Section({required this.section, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.heading != null) ...[
          const SizedBox(height: 20),
          Text(
            section.heading!,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          section.body,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.65,
            color:
                isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

// ── Conditions générales ──────────────────────────────────────────────────

const List<_LegalSection> _terms = [
  _LegalSection(
    body: 'Derniere mise a jour : aout 2026\n\n'
        'Les presentes conditions regissent l\'utilisation de l\'application '
        'My Home CI. En creant un compte ou en consultant les annonces, vous '
        'les acceptez sans reserve.',
  ),
  _LegalSection(
    heading: '1. Objet du service',
    body: 'My Home CI est une plateforme de mise en relation entre des '
        'proprietaires de logements situes en Cote d\'Ivoire et des personnes '
        'cherchant a louer.\n\n'
        'My Home CI n\'est ni agence immobiliere, ni mandataire, ni partie aux '
        'contrats de location conclus entre utilisateurs. La plateforme '
        'n\'intervient dans aucune transaction financiere et ne percoit aucune '
        'commission sur les loyers.',
  ),
  _LegalSection(
    heading: '2. Acces et compte utilisateur',
    body: 'La consultation des annonces est libre et ne necessite aucun '
        'compte. La creation d\'un compte est requise pour contacter un '
        'proprietaire, enregistrer des favoris, creer des alertes ou publier '
        'une annonce.\n\n'
        'L\'application est reservee aux personnes agees de 18 ans revolus. '
        'Vous vous engagez a fournir des informations exactes et a maintenir '
        'la confidentialite de vos identifiants.',
  ),
  _LegalSection(
    heading: '3. Publication d\'annonces',
    body: 'Le proprietaire est seul responsable du contenu qu\'il publie : '
        'exactitude de la description, du loyer, de la localisation et des '
        'photographies, et legalite de la mise en location.\n\n'
        'Toute annonce est soumise a une validation avant publication. My Home '
        'CI se reserve le droit de refuser, suspendre ou supprimer sans '
        'preavis toute annonce contraire aux presentes conditions, a la loi, '
        'ou manifestement frauduleuse.\n\n'
        'Sont notamment interdits : les logements inexistants, les demandes '
        'd\'avance de fonds avant visite, les coordonnees invitant a quitter '
        'l\'application pour contourner la moderation, et tout contenu '
        'discriminatoire.',
  ),
  _LegalSection(
    heading: '4. Messagerie',
    body: 'La messagerie integree permet d\'echanger sans divulguer votre '
        'numero de telephone. Les conversations peuvent etre consultees par '
        'l\'equipe de moderation dans le seul cadre du traitement d\'un '
        'signalement.\n\n'
        'Il est interdit d\'utiliser la messagerie a des fins de demarchage, '
        'de harcelement ou d\'escroquerie.',
  ),
  _LegalSection(
    heading: '5. Signalement et moderation',
    body: 'Chaque annonce et chaque conversation peut etre signalee depuis '
        'l\'application. Les signalements sont examines et peuvent conduire au '
        'retrait du contenu et a la suspension du compte concerne.\n\n'
        'Vous pouvez egalement ecrire a support@myhomeci.ci.',
  ),
  _LegalSection(
    heading: '6. Services payants',
    body: 'Certaines fonctionnalites destinees aux proprietaires (mise en '
        'avant d\'une annonce, offre Pro) sont payantes. Leurs tarifs et '
        'modalites sont presentes avant toute souscription.\n\n'
        'Les services payants sont fournis pour la duree annoncee et ne sont '
        'pas remboursables une fois actives, sauf defaillance imputable a la '
        'plateforme.',
  ),
  _LegalSection(
    heading: '7. Limitation de responsabilite',
    body: 'My Home CI met en oeuvre des moyens raisonnables pour verifier les '
        'annonces mais ne garantit ni l\'existence, ni l\'etat, ni la '
        'disponibilite des logements presentes.\n\n'
        'Il vous appartient de visiter le logement, de verifier l\'identite de '
        'votre interlocuteur et de n\'effectuer aucun versement avant la '
        'signature d\'un contrat. My Home CI ne saurait etre tenue responsable '
        'des differends entre utilisateurs.',
  ),
  _LegalSection(
    heading: '8. Suppression du compte',
    body: 'Vous pouvez supprimer votre compte a tout moment depuis Profil > '
        'Parametres > Supprimer mon compte. Cette action est definitive : vos '
        'annonces, vos messages, vos favoris et vos alertes sont supprimes.',
  ),
  _LegalSection(
    heading: '9. Modification et droit applicable',
    body: 'Les presentes conditions peuvent evoluer. Les utilisateurs sont '
        'informes des modifications substantielles au sein de l\'application.\n\n'
        'Elles sont soumises au droit ivoirien. Tout litige releve des '
        'juridictions competentes d\'Abidjan.',
  ),
];

// ── Politique de confidentialité ──────────────────────────────────────────

const List<_LegalSection> _privacy = [
  _LegalSection(
    body: 'Derniere mise a jour : aout 2026\n\n'
        'Cette politique explique quelles donnees My Home CI collecte, '
        'pourquoi, et comment vous en gardez le controle.',
  ),
  _LegalSection(
    heading: '1. Donnees collectees',
    body: 'Compte : nom, adresse email, numero de telephone, photo de profil, '
        'role (locataire ou proprietaire).\n\n'
        'Annonces : descriptions, photographies, adresse et coordonnees '
        'geographiques des biens que vous publiez.\n\n'
        'Messages : contenu des conversations echangees dans l\'application.\n\n'
        'Localisation : votre position approximative ou precise, uniquement '
        'lorsque vous ouvrez la carte ou demandez les logements proches, et '
        'seulement si vous y avez consenti.\n\n'
        'Technique : identifiant d\'appareil, jeton de notification, rapports '
        'de plantage et statistiques d\'usage anonymisees.',
  ),
  _LegalSection(
    heading: '2. Finalites',
    body: 'Vos donnees servent exclusivement a : faire fonctionner le service '
        '(publication, recherche, messagerie), vous notifier des messages et '
        'des annonces correspondant a vos alertes, moderer les contenus et '
        'lutter contre la fraude, et ameliorer l\'application.\n\n'
        'Vos donnees ne sont ni vendues, ni louees a des tiers.',
  ),
  _LegalSection(
    heading: '3. Ce qui reste prive',
    body: 'Votre numero de telephone et votre adresse email ne sont jamais '
        'visibles des autres utilisateurs. Les echanges passent par la '
        'messagerie integree, precisement pour que vous n\'ayez pas a '
        'communiquer vos coordonnees.\n\n'
        'Votre profil public se limite a votre nom, votre photo et, le cas '
        'echeant, votre badge de verification.',
  ),
  _LegalSection(
    heading: '4. Hebergement et sous-traitants',
    body: 'Les donnees sont hebergees sur l\'infrastructure Google Firebase '
        '(authentification, base de donnees, stockage de fichiers, '
        'notifications, statistiques et rapports de plantage), au sein de '
        'centres de donnees situes dans l\'Union europeenne.\n\n'
        'Les paiements des services optionnels sont traites par un '
        'prestataire de paiement agree ; My Home CI ne conserve aucune donnee '
        'bancaire.',
  ),
  _LegalSection(
    heading: '5. Duree de conservation',
    body: 'Les donnees de compte sont conservees tant que le compte existe. '
        'Les annonces archivees sont conservees douze mois. Les messages sont '
        'conserves pour la duree de la conversation.\n\n'
        'Apres suppression du compte, les donnees sont effacees sous trente '
        'jours, hors obligations legales de conservation.',
  ),
  _LegalSection(
    heading: '6. Vos droits',
    body: 'Vous pouvez consulter et corriger vos informations depuis l\'ecran '
        'Profil, retirer a tout moment le consentement a la geolocalisation et '
        'aux notifications depuis les reglages de votre appareil, et supprimer '
        'integralement votre compte depuis Profil > Parametres.\n\n'
        'Pour toute demande relative a vos donnees : privacy@myhomeci.ci',
  ),
  _LegalSection(
    heading: '7. Securite',
    body: 'Les communications sont chiffrees (HTTPS/TLS). L\'acces aux donnees '
        'est restreint par des regles de securite serveur controlant, pour '
        'chaque lecture et chaque ecriture, l\'identite et le role du '
        'demandeur.',
  ),
  _LegalSection(
    heading: '8. Mineurs',
    body: 'Le service est reserve aux personnes majeures. Aucune donnee n\'est '
        'sciemment collectee aupres de mineurs. Si une telle collecte etait '
        'portee a notre connaissance, les donnees seraient supprimees.',
  ),
];

// ── À propos ──────────────────────────────────────────────────────────────

const List<_LegalSection> _about = [
  _LegalSection(
    body: 'My Home CI met en relation directement proprietaires et personnes '
        'cherchant un logement en Cote d\'Ivoire, sans intermediaire et sans '
        'frais d\'agence.',
  ),
  _LegalSection(
    heading: 'Contact',
    body: 'Support : support@myhomeci.ci\n'
        'Confidentialite : privacy@myhomeci.ci',
  ),
  _LegalSection(
    heading: 'Conseils de securite',
    body: 'Ne versez jamais d\'argent avant d\'avoir visite le logement et '
        'rencontre le proprietaire.\n\n'
        'Mefiez-vous des loyers anormalement bas et des interlocuteurs qui '
        'refusent la visite ou demandent a quitter l\'application.\n\n'
        'Signalez toute annonce suspecte : le bouton se trouve en bas de '
        'chaque fiche.',
  ),
];
