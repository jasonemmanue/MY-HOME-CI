import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/advertisement_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/publication_quota_service.dart';
import '../../utils/phone.dart';
import '../../widgets/operator_selector.dart';

/// Publicite video : 1 000 FCFA pour 3 jours, gratuite en Pack Pro.
///
/// L'ecran ne decide de rien : c'est le serveur qui active la diffusion, apres
/// paiement confirme ou verification du Pack Pro. Ici, on ne fait que
/// televerser la video, creer le brouillon, et declencher l'un ou l'autre.
class AdvertisementScreen extends StatefulWidget {
  const AdvertisementScreen({super.key});

  @override
  State<AdvertisementScreen> createState() => _AdvertisementScreenState();
}

class _AdvertisementScreenState extends State<AdvertisementScreen> {
  static const int _prix = 1000;
  static const int _jours = 3;

  final _titre = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();

  /// Sur iOS, la regle App Store 3.1.1 interdit de faire payer un service
  /// numerique hors achat integre : ni prix ni operateur ne doivent
  /// apparaitre. Le serveur envoie alors un lien, et tout se joue dans le
  /// navigateur.

  File? _video;
  MobileMoneyOperator? _operateur;
  PublicationQuota? _quota;

  bool _busy = false;
  double _progression = 0;
  String? _etape;

  @override
  void initState() {
    super.initState();
    _chargerQuota();
    _email.text = AuthService.instance.currentUser?.email ?? '';
  }

  bool get _paiementIntegre => PaymentService.instance.isInAppPaymentAllowed;

  @override
  void dispose() {
    _titre.dispose();
    _telephone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _chargerQuota() async {
    final q = await PublicationQuotaService.instance.fetch();
    if (mounted) setState(() => _quota = q);
  }

  bool get _estPro => _quota?.isPro ?? false;

  Future<void> _choisirVideo() async {
    final fichier = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      // Au-dela, le televersement devient penible en 3G et la video n'apporte
      // plus rien : une publicite de 30 secondes suffit.
      maxDuration: const Duration(seconds: 60),
    );
    if (fichier == null) return;

    final f = File(fichier.path);
    final taille = await f.length();
    if (taille > 50 * 1024 * 1024) {
      _erreur('Video trop lourde (maximum 50 Mo). Filmez plus court.');
      return;
    }
    setState(() => _video = f);
  }

  String? _valider() {
    if (_titre.text.trim().length < 5) {
      return 'Donnez un titre d\'au moins 5 caracteres.';
    }
    if (_video == null) return 'Choisissez une video.';
    if (!_estPro) {
      if (!_paiementIntegre) {
        final email = _email.text.trim();
        if (email.isEmpty || !email.contains('@')) {
          return 'Indiquez une adresse email valide.';
        }
        return null;
      }
      if (_operateur == null) return 'Choisissez un moyen de paiement.';
      if (!isPlausiblePhone(_telephone.text)) {
        return 'Indiquez le numero a debiter.';
      }
    }
    return null;
  }

  Future<void> _envoyer() async {
    final probleme = _valider();
    if (probleme != null) {
      _erreur(probleme);
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      _erreur('Connexion requise.');
      return;
    }

    setState(() {
      _busy = true;
      _progression = 0;
      _etape = 'Envoi de la video…';
    });

    try {
      final adId = await AdvertisementService.instance.createDraft(
        ownerId: auth.uid!,
        ownerName: auth.user?.name ?? '',
        title: _titre.text,
        video: _video!,
        onProgress: (p) {
          if (mounted) setState(() => _progression = p);
        },
      );

      if (_estPro) {
        setState(() => _etape = 'Activation…');
        await AdvertisementService.instance.activateAsPro(adId);
        if (!mounted) return;
        _succes('Votre publicite est en ligne pour $_jours jours.');
        return;
      }

      if (!_paiementIntegre) {
        setState(() => _etape = 'Envoi du lien…');
        final parEmail =
            await PaymentService.instance.requestActivationByEmail(
          product: PaidProduct.adVideo,
          email: _email.text.trim(),
          targetId: adId,
        );
        if (!mounted) return;
        if (!parEmail.success) {
          _erreur(parEmail.message);
          return;
        }
        _succes(parEmail.message);
        return;
      }

      setState(() => _etape = 'Ouverture du paiement…');
      final resultat =
          await PaymentService.instance.initiateMobileMoneyPayment(
        product: PaidProduct.adVideo,
        operator: _operateur!,
        phone: toE164(_telephone.text) ?? _telephone.text,
        targetId: adId,
      );

      if (!resultat.success || resultat.paymentUrl == null) {
        _erreur(resultat.message.isNotEmpty
            ? resultat.message
            : 'Paiement impossible pour le moment.');
        return;
      }

      final ouvert = await launchUrl(
        Uri.parse(resultat.paymentUrl!),
        mode: LaunchMode.externalApplication,
      );
      if (!ouvert) {
        _erreur('Impossible d\'ouvrir la page de paiement.');
        return;
      }

      if (!mounted) return;
      // La diffusion n'est PAS accordee ici : elle l'est au retour du webhook,
      // apres verification aupres de l'operateur. L'accorder des maintenant
      // permettrait d'abandonner le paiement et d'etre diffuse quand meme.
      _succes(
        'Finalisez le paiement dans la page qui vient de s\'ouvrir. '
        'Votre publicite passera en ligne des sa confirmation.',
      );
    } catch (e) {
      _erreur('Envoi impossible. Reessayez.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _etape = null;
        });
      }
    }
  }

  void _erreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _succes(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Publicite video',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _offre(isDark),
            const SizedBox(height: 22),

            Text('Titre de la publicite',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _titre,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'Belle villa 4 pieces a Cocody',
                prefixIcon: Icon(Icons.title, size: 20),
              ),
            ),

            const SizedBox(height: 8),
            Text('Votre video',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choixVideo(isDark),

            if (!_estPro && !_paiementIntegre) ...[
              const SizedBox(height: 24),
              Text('Activation',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                "Nous vous envoyons un lien securise par email. La diffusion "
                "demarre des la confirmation.",
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Adresse email',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
              ),
            ],

            if (!_estPro && _paiementIntegre) ...[
              const SizedBox(height: 24),
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
            ],

            const SizedBox(height: 28),
            if (_busy) ...[
              LinearProgressIndicator(
                value: _progression > 0 && _progression < 1
                    ? _progression
                    : null,
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(_etape ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Theme.of(context).hintColor)),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _busy ? null : _envoyer,
              child: Text(_estPro
                  ? 'Diffuser ma publicite'
                  : (_paiementIntegre
                      ? 'Payer ${AppConstants.formatPrice(_prix)} et diffuser'
                      : 'Recevoir le lien d’activation')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _offre(bool isDark) {
    final pro = _estPro;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (pro ? AppTheme.primaryGreen : AppTheme.secondaryOrange)
            .withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(
          color: (pro ? AppTheme.primaryGreen : AppTheme.secondaryOrange)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pro ? Icons.workspace_premium_outlined : Icons.play_circle_outline,
              size: 22,
              color: pro ? AppTheme.primaryGreen : AppTheme.secondaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pro
                      ? 'Incluse dans votre Pack Pro'
                      : (_paiementIntegre
                          ? '${AppConstants.formatPrice(_prix)} pour $_jours jours'
                          : 'Diffusion de $_jours jours'),
                  style: GoogleFonts.poppins(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  pro
                      ? 'Votre video est diffusee $_jours jours dans '
                          'l\'application, sans frais.'
                      : 'Votre video est diffusee $_jours jours dans '
                          'l\'application, aupres des personnes qui cherchent '
                          'un logement. '
                          '${_paiementIntegre ? "Le Pack Pro la rend gratuite." : "L’activation se termine dans votre navigateur."}',
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

  Widget _choixVideo(bool isDark) {
    if (_video == null) {
      return OutlinedButton.icon(
        onPressed: _choisirVideo,
        icon: const Icon(Icons.videocam_outlined, size: 20),
        label: const Text('Choisir une video'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          const Icon(Icons.movie_outlined,
              size: 22, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _video!.path.split(Platform.pathSeparator).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _video = null),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Retirer',
          ),
        ],
      ),
    );
  }
}
