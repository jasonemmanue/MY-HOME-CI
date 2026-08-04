import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_home_ci/config/routes.dart';
import 'package:my_home_ci/config/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedRole = -1; // 0 = locataire, 1 = proprietaire

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // -- Logo --
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.primaryGreen.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'MY HOME CI',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // -- Tab bar --
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusDefault),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.primaryGreen,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Se connecter'),
                    Tab(text: 'Creer un compte'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // -- Tab views --
              SizedBox(
                // Fixed height for tab content to avoid layout issues
                height: 520,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginForm(),
                    _buildRegisterForm(),
                  ],
                ),
              ),

              // -- Divider --
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 20),

              // -- Google sign-in --
              OutlinedButton.icon(
                onPressed: _navigateToHome,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: Text(
                  'Continuer avec Google',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(color: AppTheme.dividerLight),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -- Continue as guest --
              Center(
                child: TextButton(
                  onPressed: _navigateToHome,
                  child: Text(
                    'Continuer sans compte',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryLight,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  LOGIN FORM
  // ══════════════════════════════════════════════

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bon retour parmi nous !',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Connectez-vous pour acceder a vos annonces',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondaryLight,
          ),
        ),

        const SizedBox(height: 24),

        // Email / phone
        TextField(
          decoration: InputDecoration(
            labelText: 'Email ou telephone',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            hintText: 'exemple@email.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        // Password
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility_off_outlined, size: 20),
              onPressed: () {},
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Mot de passe oublie ?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Login button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _navigateToHome,
            child: Text(
              'Se connecter',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  REGISTER FORM
  // ══════════════════════════════════════════════

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Creez votre compte',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Choisissez votre profil pour commencer',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondaryLight,
            ),
          ),

          const SizedBox(height: 20),

          // -- Role selection --
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  icon: Icons.search,
                  label: 'Je cherche\nun logement',
                  selected: _selectedRole == 0,
                  onTap: () => setState(() => _selectedRole = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  icon: Icons.apartment,
                  label: 'Je suis\nproprietaire',
                  selected: _selectedRole == 1,
                  onTap: () => setState(() => _selectedRole = 1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Name
          TextField(
            decoration: InputDecoration(
              labelText: 'Nom complet',
              prefixIcon:
                  const Icon(Icons.person_outline, size: 20),
              hintText: 'Jean Kouassi',
            ),
          ),

          const SizedBox(height: 14),

          // Phone
          TextField(
            decoration: InputDecoration(
              labelText: 'Telephone',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              hintText: '+225 07 00 00 00 00',
            ),
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 14),

          // Email
          TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon:
                  const Icon(Icons.email_outlined, size: 20),
              hintText: 'exemple@email.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 14),

          // Password
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon:
                  const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.visibility_off_outlined,
                    size: 20),
                onPressed: () {},
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Register button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _navigateToHome,
              child: Text(
                'Creer mon compte',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  ROLE SELECTION CARD
// ══════════════════════════════════════════════

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: selected
                ? AppTheme.primaryGreen
                : AppTheme.dividerLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                    : AppTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppTheme.primaryGreen
                    : Theme.of(context).colorScheme.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
