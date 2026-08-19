import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

/// Completion du profil apres une connexion Google ou Apple.
///
/// Ces fournisseurs ne transmettent ni role ni telephone. Tant que ces deux
/// informations manquent, l'application ne peut ni afficher le bon tableau de
/// bord, ni permettre a un locataire de joindre un proprietaire.
///
/// L'ecran est le seul endroit qui cree la fiche `users/{uid}` d'un compte
/// social : `role` figure dans `noPrivilegeEscalation` cote firestore.rules,
/// donc une fiche creee d'office en « locataire » ne pourrait plus jamais
/// devenir « proprietaire » depuis le client. Il faut choisir avant d'ecrire.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _phone = TextEditingController();

  UserRole _role = UserRole.tenant;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Google fournit presque toujours le nom : le pre-remplir evite de
    // redemander une information deja connue.
    final displayName = AuthService.instance.currentUser?.displayName ?? '';
    _name = TextEditingController(text: displayName.trim());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await AuthService.instance.completeProfile(
        name: _name.text,
        role: _role,
        phone: _phone.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Enregistrement impossible. Reessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Quitter sans completer laisse un compte Firebase sans fiche : on se
  /// deconnecte pour ne pas laisser l'utilisateur dans cet entre-deux, ou
  /// l'application ne saurait ni son role ni comment le joindre.
  Future<void> _abandon() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.auth, (route) => false);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Le retour arriere ne doit pas ramener a l'ecran d'authentification en
    // laissant un compte a moitie cree derriere lui.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _abandon();
      },
      child: Scaffold(
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: _busy,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Encore une etape',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votre compte est cree. Indiquez-nous qui vous etes pour '
                      'terminer.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Vous etes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : AppTheme.textPrimaryLight,
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

                    if (_role == UserRole.owner) ...[
                      const SizedBox(height: 12),
                      _infoBanner(
                        isDark,
                        'Une verification d\'identite vous sera demandee avant '
                        'la publication de votre premiere annonce.',
                      ),
                    ],

                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Indiquez votre nom complet.'
                          : null,
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Telephone',
                        hintText: '07 00 00 00 00',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        // Un numero ivoirien compte 10 chiffres ; on tolere un
                        // indicatif et des separateurs, que le service
                        // normalisera.
                        final digits =
                            (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 8) {
                          return 'Indiquez un numero de telephone valide.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Votre numero reste prive : il ne s\'affiche jamais sur '
                      'votre profil public.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),

                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Terminer'),
                    ),

                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _abandon,
                      child: const Text('Utiliser un autre compte'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
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

  Widget _infoBanner(bool isDark, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
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
}
