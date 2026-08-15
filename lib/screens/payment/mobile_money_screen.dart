import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/payment_config.dart';
import '../../config/theme.dart';
import '../../services/mobile_money_service.dart';
import '../../services/payment_service.dart';

/// Parcours Mobile Money — Android et Web uniquement.
///
/// Ce fichier ne doit jamais etre atteignable depuis un build iOS. Il est
/// referencé exclusivement derriere une garde `kMobileMoneyEnabled`, constante
/// de compilation valant `false` sur iOS : le compilateur AOT elimine alors la
/// branche, et aucune des chaines de ce fichier — montants, « FCFA », noms
/// d'operateurs — n'entre dans l'IPA soumis a Apple.
///
/// Voir `lib/config/payment_config.dart` et les workflows iOS de
/// `codemagic.yaml`.
class MobileMoneyScreen extends StatefulWidget {
  final PaidProduct product;
  final String? targetId;

  const MobileMoneyScreen({
    super.key,
    required this.product,
    this.targetId,
  });

  @override
  State<MobileMoneyScreen> createState() => _MobileMoneyScreenState();
}

/// Montants affiches.
///
/// La grille de reference vit dans `functions/index.js` : le serveur ignore
/// tout montant envoye par le client et facture le sien. Ces valeurs ne
/// servent qu'a l'affichage — les modifier ici ne change pas ce qui est
/// preleve, mais les desynchroniser afficherait un prix mensonger.
const Map<PaidProduct, int> _displayAmount = {
  PaidProduct.pro: 15000,
  PaidProduct.boost: 5000,
};

enum _Step { form, pending, success, failure }

class _MobileMoneyScreenState extends State<MobileMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  MobileMoneyOperator? _operator;
  _Step _step = _Step.form;
  bool _submitting = false;
  String _message = '';
  StreamSubscription<PaymentStatus>? _watch;

  @override
  void dispose() {
    _watch?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_operator == null) {
      _snack('Choisissez un operateur.');
      return;
    }

    setState(() => _submitting = true);

    final result = await MobileMoneyService.instance.initiate(
      product: widget.product,
      operator: _operator!,
      phone: _phoneController.text.trim(),
      targetId: widget.targetId,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success || result.reference == null) {
      _snack(result.message);
      return;
    }

    // La page de la passerelle porte la confirmation finale (saisie du code
    // operateur). L'ouvrir hors de l'application est volontaire : un webview
    // interne casse la validation 3-D Secure de certains operateurs.
    final url = result.paymentUrl;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    setState(() => _step = _Step.pending);
    _listen(result.reference!);
  }

  /// Suit le document de transaction plutot que d'interroger la passerelle :
  /// seul le webhook, cote serveur, fait foi.
  void _listen(String reference) {
    _watch?.cancel();
    _watch = PaymentService.instance.watchTransaction(reference).listen((s) {
      if (!mounted || !s.isFinal) return;
      setState(() {
        _step = s == PaymentStatus.succeeded ? _Step.success : _Step.failure;
        _message = s == PaymentStatus.succeeded
            ? 'Votre service est actif.'
            : s == PaymentStatus.cancelled
                ? 'Operation annulee.'
                : 'L\'operation n\'a pas abouti. Aucun montant n\'a ete '
                    'preleve.';
      });
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product.label,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          _Step.form => _form(),
          _Step.pending => _pending(),
          _Step.success => _outcome(true),
          _Step.failure => _outcome(false),
        },
      ),
    );
  }

  // ── Formulaire ──────────────────────────────────────────────────────────

  Widget _form() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = _displayAmount[widget.product] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summary(amount, isDark),
            const SizedBox(height: 26),
            Text(
              'Operateur',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _operators(isDark),
            const SizedBox(height: 26),
            Text(
              'Numero a debiter',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _phoneField(isDark),
            if (_operatorMismatch) ...[
              const SizedBox(height: 10),
              _mismatchWarning(),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Payer ${AppConstants.formatPrice(amount)}',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Vous recevrez une demande de confirmation sur votre telephone. '
              'Le service est active des que l\'operateur confirme le paiement.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.5,
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

  Widget _summary(int amount, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.product.label,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                AppConstants.formatPrice(amount),
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _operators(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: MobileMoneyOperator.values.map((op) {
        final selected = _operator == op;
        return ChoiceChip(
          selected: selected,
          label: Text(op.label, style: GoogleFonts.inter(fontSize: 13.5)),
          onSelected: (_) => setState(() => _operator = op),
          selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: selected
                ? AppTheme.primaryGreen
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            side: BorderSide(
              color: selected
                  ? AppTheme.primaryGreen
                  : (isDark ? AppTheme.dividerDark : AppTheme.dividerLight),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _phoneField(bool isDark) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(kLocalPhoneLength),
      ],
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        prefixText: '$kCountryDialCode ',
        labelText: 'Numero Mobile Money',
        hintText: '0700000000',
        prefixIcon: Icon(Icons.smartphone_outlined),
      ),
      validator: (value) {
        final v = (value ?? '').trim();
        if (v.isEmpty) return 'Indiquez le numero a debiter.';
        if (normalizeIvorianPhone(v) == null) {
          return 'Numero ivoirien a $kLocalPhoneLength chiffres attendu.';
        }
        return null;
      },
    );
  }

  bool get _operatorMismatch {
    final op = _operator;
    final phone = _phoneController.text.trim();
    if (op == null || phone.length < kLocalPhoneLength) return false;
    return !phoneMatchesOperator(phone, op.code);
  }

  Widget _mismatchWarning() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline,
            size: 17, color: AppTheme.secondaryOrangeDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ce numero ne correspond pas au reseau ${_operator!.label}. '
            'Verifiez avant de continuer.',
            style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.secondaryOrangeDark),
          ),
        ),
      ],
    );
  }

  // ── Attente et issue ────────────────────────────────────────────────────

  Widget _pending() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 32),
          Text(
            'Confirmation en cours',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            'Validez la demande recue sur le $kCountryDialCode '
            '${_phoneController.text.trim()}. '
            'Cet ecran se met a jour automatiquement.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.55,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Fermer et revenir plus tard',
              style: GoogleFonts.inter(fontSize: 13.5),
            ),
          ),
          Text(
            'Le service sera active meme si vous quittez cet ecran.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcome(bool success) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = success ? AppTheme.successColor : AppTheme.errorColor;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              size: 56,
              color: color,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            success ? 'Paiement confirme' : 'Paiement non abouti',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              height: 1.55,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(success),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
              ),
              child: Text(
                success ? 'Terminer' : 'Retour',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!success) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _step = _Step.form;
                _message = '';
              }),
              child: Text('Reessayer',
                  style: GoogleFonts.inter(fontSize: 13.5)),
            ),
          ],
        ],
      ),
    );
  }
}
