import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';

class OtpArgs {
  final String phone;
  final String? name;
  final UserRole? role;

  const OtpArgs({required this.phone, this.name, this.role});
}

/// Connexion par SMS, en deux temps : saisie du numéro puis du code.
///
/// Les deux étapes vivent dans le même écran plutôt que dans deux routes : le
/// `verificationId` renvoyé par Firebase doit survivre au passage d'une étape
/// à l'autre, et une seconde route obligerait à le faire transiter par les
/// arguments de navigation.
class OtpScreen extends StatefulWidget {
  final OtpArgs args;

  const OtpScreen({super.key, required this.args});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  bool _busy = false;
  String? _error;

  /// Délai avant de pouvoir redemander un code. Firebase limite les envois ;
  /// laisser l'utilisateur marteler le bouton le ferait bannir temporairement.
  static const int _resendDelaySeconds = 60;
  int _secondsLeft = 0;
  Timer? _countdown;

  bool get _codeSent => _verificationId != null;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.args.phone;
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = _resendDelaySeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final phone = _phoneController.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      setState(() => _error = 'Numero de telephone invalide.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    await AuthService.instance.startPhoneVerification(
      phoneNumber: phone,
      resendToken: isResend ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _busy = false;
        });
        _startCountdown();
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() {
          _error = error.message;
          _busy = false;
        });
      },
      // Android peut lire le SMS lui-même : on enchaîne alors sans saisie.
      onAutoVerified: (credential) async {
        if (!mounted || _verificationId == null) return;
        await _confirm(autoCode: credential.smsCode);
      },
    );
  }

  Future<void> _confirm({String? autoCode}) async {
    final code = autoCode ?? _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Le code comporte 6 chiffres.');
      return;
    }
    if (_verificationId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.instance.confirmOtp(
        verificationId: _verificationId!,
        smsCode: code,
        name: widget.args.name,
        role: widget.args.role,
      );
      await AnalyticsService.instance.logLogin('phone');
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Verification impossible. Reessayez.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Connexion par SMS',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _codeSent ? Icons.mark_email_read_outlined : Icons.sms_outlined,
                  size: 30,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _codeSent ? 'Saisissez le code' : 'Votre numero',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Un code a 6 chiffres a ete envoye au '
                        '${_phoneController.text.trim()}.'
                    : 'Nous vous enverrons un code de verification par SMS.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 28),
              if (!_codeSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Telephone',
                    hintText: '07 00 00 00 00',
                    prefixText: '+225 ',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                )
              else
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 12,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '······',
                  ),
                  onChanged: (v) {
                    // Validation dès le sixième chiffre : demander en plus un
                    // appui sur un bouton est une étape de trop.
                    if (v.length == 6 && !_busy) _confirm();
                  },
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _codeSent ? _confirm() : _sendCode(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _codeSent ? 'Verifier' : 'Recevoir le code',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_secondsLeft > 0 || _busy)
                      ? null
                      : () => _sendCode(isResend: true),
                  child: Text(
                    _secondsLeft > 0
                        ? 'Renvoyer le code dans ${_secondsLeft}s'
                        : 'Renvoyer le code',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _verificationId = null;
                            _codeController.clear();
                            _error = null;
                          }),
                  child: Text(
                    'Modifier le numero',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppTheme.primaryGreen),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
