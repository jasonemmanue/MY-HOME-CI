import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/phone.dart';
import '../../widgets/operator_selector.dart';

/// Souscription au Pack Pro : 15 000 FCFA pour 30 jours.
///
/// L'abonnement n'est jamais accorde ici : il l'est au retour du webhook,
/// apres verification du paiement aupres de l'operateur. L'accorder des
/// l'initiation permettrait d'obtenir le pack en abandonnant le paiement.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const int _prix = 15000;
  static const int _jours = 30;

  final _telephone = TextEditingController();
  MobileMoneyOperator? _operateur;
  bool _busy = false;

  @override
  void dispose() {
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _souscrire() async {
    if (_operateur == null) {
      _message('Choisissez un moyen de paiement.', erreur: true);
      return;
    }
    if (!isPlausiblePhone(_telephone.text)) {
      _message('Indiquez le numero a debiter.', erreur: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final resultat =
          await PaymentService.instance.initiateMobileMoneyPayment(
        product: PaidProduct.pro,
        operator: _operateur!,
        phone: toE164(_telephone.text) ?? _telephone.text,
      );

      if (!resultat.success || resultat.paymentUrl == null) {
        _message(
          resultat.message.isNotEmpty
              ? resultat.message
              : 'Paiement impossible pour le moment.',
          erreur: true,
        );
        return;
      }

      final ouvert = await launchUrl(
        Uri.parse(resultat.paymentUrl!),
        mode: LaunchMode.externalApplication,
      );
      if (!ouvert) {
        _message('Impossible d\'ouvrir la page de paiement.', erreur: true);
        return;
      }

      if (!mounted) return;
      _message('Finalisez le paiement dans la page qui vient de s\'ouvrir. '
          'Votre Pack Pro s\'activera des sa confirmation.');
      Navigator.pop(context);
    } catch (_) {
      _message('Souscription impossible. Reessayez.', erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String texte, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texte),
        backgroundColor:
            erreur ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;

    // `isPro` seul ne suffit pas : le pack expire, et le drapeau n'est remis
    // a false par aucun processus. C'est la date qui fait foi.
    final actif = (user?.isPro ?? false) &&
        (user?.proUntil == null || user!.proUntil!.isAfter(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: Text('Pack Pro',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _enTete(actif, user?.proUntil, isDark),
            const SizedBox(height: 24),

            Text('Ce que comprend le Pack Pro',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _avantage(Icons.all_inclusive, 'Publications illimitees',
                'Plus de quota de 4 operations : publiez et remettez en ligne '
                'autant d\'annonces que vous voulez, sans frais.',
                isDark),
            _avantage(Icons.verified_outlined, 'Badge proprietaire verifie',
                'Les locataires distinguent immediatement votre profil des '
                'annonces non verifiees.',
                isDark),
            _avantage(Icons.play_circle_outline, 'Publicites video offertes',
                'Diffusez vos videos dans l\'application sans payer les '
                '1 000 FCFA habituels.',
                isDark),
            _avantage(Icons.insights_outlined, 'Statistiques detaillees',
                'Vues, favoris et contacts recus, annonce par annonce.',
                isDark),

            if (!actif) ...[
              const SizedBox(height: 26),
              Text('Moyen de paiement',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              OperatorSelector(
                selected: _operateur,
                onSelected: (o) => setState(() => _operateur = o),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _telephone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numero a debiter',
                  hintText: '07 00 00 00 00',
                  prefixText: kPhonePrefixLabel,
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 24),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _busy ? null : _souscrire,
                child: Text(
                    'Souscrire — ${AppConstants.formatPrice(_prix)} / $_jours jours'),
              ),
              const SizedBox(height: 12),
              Text(
                'Paiement unique, sans reconduction automatique. A l\'echeance, '
                'vous revenez au fonctionnement gratuit sans rien avoir a '
                'resilier.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _enTete(bool actif, DateTime? jusquA, bool isDark) {
    final couleur = actif ? AppTheme.primaryGreen : AppTheme.secondaryOrange;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [couleur.withValues(alpha: 0.16), couleur.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, size: 26, color: couleur),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  actif ? 'Pack Pro actif' : 'Passez au Pack Pro',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            actif
                ? (jusquA == null
                    ? 'Votre abonnement est actif.'
                    : 'Actif jusqu\'au '
                        '${DateFormat('d MMMM yyyy', 'fr_FR').format(jusquA)}.')
                : '${AppConstants.formatPrice(_prix)} pour $_jours jours.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.45,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avantage(
      IconData icone, String titre, String detail, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 19, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
