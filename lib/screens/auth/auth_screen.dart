import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../legal/legal_screen.dart';
import 'otp_screen.dart';

class AuthScreenArgs {
  final int initialTab;
  const AuthScreenArgs({this.initialTab = 0});
}

/// Point d'entrée de l'application.
///
/// Trois voies coexistent volontairement : le mode visiteur (mis en avant,
/// comme l'impose le cahier des charges), l'email/mot de passe, et le
/// téléphone par OTP. S'y ajoutent Google et — sur iOS uniquement et
/// obligatoirement — Sign in with Apple.
class AuthScreen extends StatefulWidget {
  final int initialTab;

  const AuthScreen({super.key, this.initialTab = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  // Connexion
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  bool _obscurePassword = true;

  // Inscription
  final _registerFormKey = GlobalKey<FormState>();
  final _registerName = TextEditingController();
  final _registerPhone = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPassword = TextEditingController();
  final _registerConfirm = TextEditingController();
  bool _obscureRegisterPassword = true;
  bool _acceptedTerms = false;
  UserRole _selectedRole = UserRole.tenant;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerPhone.dispose();
    _registerEmail.dispose();
    _registerPassword.dispose();
    _registerConfirm.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _goHome() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.home, (route) => false);
  }

  void _continueAsGuest() {
    context.read<AuthProvider>().continueAsGuest();
    _goHome();
  }

  /// Exécute [action] en gérant l'état occupé et l'affichage des erreurs.
  ///
  /// Centralisé pour que chaque bouton d'authentification ait exactement le
  /// même comportement : impossible de laisser un chemin sans indicateur de
  /// chargement ou sans message d'erreur.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Une erreur est survenue. Reessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _submitLogin() {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return Future.value();
    }
    return _run(() async {
      await AuthService.instance.signInWithEmail(
        email: _loginEmail.text,
        password: _loginPassword.text,
      );
      await AnalyticsService.instance.logLogin('email');
      _goHome();
    });
  }

  Future<void> _submitRegister() {
    if (!(_registerFormKey.currentState?.validate() ?? false)) {
      return Future.value();
    }
    if (!_acceptedTerms) {
      _showError(
          'Vous devez accepter les conditions generales pour creer un compte.');
      return Future.value();
    }
    return _run(() async {
      await AuthService.instance.signUpWithEmail(
        name: _registerName.text,
        email: _registerEmail.text,
        password: _registerPassword.text,
        phone: _registerPhone.text,
        role: _selectedRole,
      );
      await AnalyticsService.instance.logSignUp('email');
      _goHome();
    });
  }

  Future<void> _signInWithGoogle() {
    return _run(() async {
      await AuthService.instance.signInWithGoogle(
        role: _currentTab == 1 ? _selectedRole : null,
      );
      await AnalyticsService.instance.logLogin('google');
      _goHome();
    });
  }

  Future<void> _signInWithApple() {
    return _run(() async {
      await AuthService.instance.signInWithApple(
        role: _currentTab == 1 ? _selectedRole : null,
      );
      await AnalyticsService.instance.logLogin('apple');
      _goHome();
    });
  }

  void _startPhoneLogin() {
    Navigator.pushNamed(
      context,
      AppRoutes.otp,
      arguments: OtpArgs(
        phone: _currentTab == 1 ? _registerPhone.text : '',
        name: _currentTab == 1 ? _registerName.text : null,
        role: _currentTab == 1 ? _selectedRole : null,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _loginEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Saisissez d\'abord votre adresse email.');
      return;
    }
    await _run(() async {
      await AuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Un lien de reinitialisation a ete envoye a $email.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // ── Rendu ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _buildLogo(),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'My Home CI',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildVisitorBanner(isDark),
                const SizedBox(height: 24),
                _divider(isDark, 'ou connectez-vous'),
                const SizedBox(height: 24),
                _buildTabBar(),
                const SizedBox(height: 24),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _currentTab == 0
                      ? _buildLoginForm(isDark)
                      : _buildRegisterForm(isDark),
                ),
                const SizedBox(height: 24),
                _divider(isDark, 'ou'),
                const SizedBox(height: 16),
                _buildSocialButtons(isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _divider(bool isDark, String label) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildVisitorBanner(bool isDark) {
    return GestureDetector(
      onTap: _continueAsGuest,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondaryOrange.withValues(alpha: 0.12),
              AppTheme.primaryGreen.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: AppTheme.secondaryOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.secondaryOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore_outlined,
                  size: 24, color: AppTheme.secondaryOrange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parcourir en tant que visiteur',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Explorez les logements sans inscription',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppTheme.secondaryOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.primaryGreen,
        labelStyle:
            GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Se connecter'),
          Tab(text: 'Creer un compte'),
        ],
      ),
    );
  }

  // ── Formulaire de connexion ─────────────────────────────────────────────

  Widget _buildLoginForm(bool isDark) {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bon retour',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Connectez-vous pour retrouver vos favoris et vos messages',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'exemple@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPassword,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submitLogin(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Saisissez votre mot de passe'
                : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: Text(
                'Mot de passe oublie ?',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _primaryButton('Se connecter', _submitLogin),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _startPhoneLogin,
            icon: const Icon(Icons.sms_outlined, size: 20),
            label: Text(
              'Connexion par SMS',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w500),
            ),
            style: _outlinedStyle(isDark),
          ),
        ],
      ),
    );
  }

  // ── Formulaire d'inscription ────────────────────────────────────────────

  Widget _buildRegisterForm(bool isDark) {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Creer un compte',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vous etes',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _roleCard(
                  isDark: isDark,
                  role: UserRole.tenant,
                  icon: Icons.search,
                  title: 'Je cherche',
                  subtitle: 'un logement',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _roleCard(
                  isDark: isDark,
                  role: UserRole.owner,
                  icon: Icons.home_work_outlined,
                  title: 'Je suis',
                  subtitle: 'proprietaire',
                ),
              ),
            ],
          ),
          if (_selectedRole == UserRole.owner) ...[
            const SizedBox(height: 12),
            _infoBanner(
              isDark,
              'Une verification d\'identite vous sera demandee avant la '
              'publication de votre premiere annonce.',
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _registerName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'Saisissez votre nom complet'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerPhone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Telephone',
              hintText: '07 00 00 00 00',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
              prefixText: '+225 ',
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 8) return 'Numero de telephone invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'exemple@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerPassword,
            obscureText: _obscureRegisterPassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              helperText: '8 caracteres minimum',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegisterPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() =>
                    _obscureRegisterPassword = !_obscureRegisterPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) {
                return 'Le mot de passe doit faire au moins 8 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerConfirm,
            obscureText: _obscureRegisterPassword,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_outline, size: 20),
            ),
            validator: (v) => v != _registerPassword.text
                ? 'Les mots de passe ne correspondent pas'
                : null,
          ),
          const SizedBox(height: 12),
          _buildTermsCheckbox(isDark),
          const SizedBox(height: 16),
          _primaryButton('Creer mon compte', _submitRegister),
        ],
      ),
    );
  }

  Widget _roleCard({
    required bool isDark,
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: selected
                ? AppTheme.primaryGreen
                : (isDark ? AppTheme.dividerDark : AppTheme.dividerLight),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 26,
                color: selected
                    ? AppTheme.primaryGreen
                    : (isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight)),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.primaryGreen
                    : (isDark ? Colors.white : AppTheme.textPrimaryLight),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
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

  Widget _buildTermsCheckbox(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            activeColor: AppTheme.primaryGreen,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'J\'accepte les ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.legal,
                      arguments: LegalDocument.terms),
                  child: Text(
                    'conditions generales',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' et la ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.legal,
                      arguments: LegalDocument.privacy),
                  child: Text(
                    'politique de confidentialite',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoBanner(bool isDark, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppTheme.secondaryOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connexions sociales ─────────────────────────────────────────────────

  Widget _buildSocialButtons(bool isDark) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _signInWithGoogle,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: Text(
            'Continuer avec Google',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          style: _outlinedStyle(isDark),
        ),
        // Sign in with Apple n'est proposé que sur iOS, où la règle App Store
        // 4.8 le rend obligatoire dès lors qu'une connexion tierce existe.
        // L'afficher sur Android n'aurait aucun sens : le flux n'y est pas natif.
        if (AuthService.instance.isAppleSignInAvailable) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _signInWithApple,
            icon: const Icon(Icons.apple, size: 24),
            label: Text(
              'Continuer avec Apple',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            style: _outlinedStyle(isDark),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 20),
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
      ],
    );
  }

  // ── Fabriques ───────────────────────────────────────────────────────────

  Widget _primaryButton(String label, Future<void> Function() onPressed) {
    return ElevatedButton(
      onPressed: _busy ? null : () => onPressed(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
      ),
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
    );
  }

  ButtonStyle _outlinedStyle(bool isDark) {
    return OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      side: BorderSide(
        color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Saisissez votre adresse email';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
      return 'Adresse email invalide';
    }
    return null;
  }
}
