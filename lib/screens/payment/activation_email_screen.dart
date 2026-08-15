import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';

/// Parcours d'activation iOS.
///
/// ─── Ce que cet ecran ne doit JAMAIS contenir ───────────────────────────
/// Aucun montant, aucune devise, aucun nom d'operateur, aucun bouton menant
/// a une page de paiement, et aucun des mots « paiement », « payer »,
/// « acheter », « tarif », « abonnement ». La regle App Store 3.1.1 interdit
/// non seulement d'encaisser hors achat in-app, mais aussi de *diriger*
/// l'utilisateur vers un encaissement externe depuis l'application.
///
/// Ce que l'ecran fait : demander une adresse email et declencher l'envoi
/// d'un message. Tout le reste se passe hors de l'application, dans le
/// navigateur, depuis un lien recu par email. L'application ne fait ensuite
/// que constater l'activation via le document utilisateur.
///
/// Toute modification de ce fichier doit passer le script
/// `tool/audit_ios_payment_traces.dart` avant d'etre publiee.
class ActivationEmailScreen extends StatefulWidget {
  final PaidProduct product;

  /// Ce que l'utilisateur active, formule sans reference commerciale.
  final String serviceLabel;

  final String? targetId;

  const ActivationEmailScreen({
    super.key,
    required this.product,
    required this.serviceLabel,
    this.targetId,
  });

  @override
  State<ActivationEmailScreen> createState() => _ActivationEmailScreenState();
}

class _ActivationEmailScreenState extends State<ActivationEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    // Pre-remplir evite une saisie inutile dans la grande majorite des cas :
    // l'adresse du compte est presque toujours la bonne. On lit celle de
    // Firebase Auth plutot que le profil Firestore, ou l'email vit dans un
    // sous-document prive qui demanderait une lecture supplementaire.
    final email = AuthService.instance.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    final result = await PaymentService.instance.requestActivationByEmail(
      product: widget.product,
      email: _emailController.text.trim(),
      targetId: widget.targetId,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (result.success) {
      setState(() => _sent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activation',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: _sent ? _confirmation() : _form()),
    );
  }

  Widget _form() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 42,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Terminez l\'activation par email',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.serviceLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'L\'activation de ce service se termine depuis votre navigateur. '
              'Indiquez l\'adresse a laquelle vous souhaitez recevoir le lien.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sending ? null : _send(),
              decoration: const InputDecoration(
                labelText: 'Adresse email',
                hintText: 'nom@exemple.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'Indiquez une adresse email.';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                  return 'Cette adresse ne semble pas valide.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Recevoir le lien',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              'Le lien reste valable 24 heures. Une fois l\'operation terminee '
              'dans votre navigateur, revenez ici : votre espace se met a jour '
              'automatiquement.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.55,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 58,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Email envoye',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Un message vient d\'etre envoye a ${_emailController.text.trim()}. '
            'Ouvrez-le pour terminer l\'activation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              height: 1.55,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pensez a verifier vos courriers indesirables.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 34),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 42, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
            ),
            child: Text(
              'Terminer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
