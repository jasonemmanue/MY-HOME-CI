import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

/// Ecran d'ouverture, doublé d'un aiguillage de session.
///
/// La destination dépend de deux informations asynchrones : l'onboarding a-t-il
/// déjà été vu, et une session est-elle rétablie ? On attend donc que
/// [AuthProvider] sorte de l'état `unknown` avant de router — sans cette
/// attente, un utilisateur déjà connecté serait renvoyé vers l'écran de
/// connexion le temps que Firebase restaure sa session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  /// Durée minimale d'affichage : sans elle, une session déjà en cache ferait
  /// disparaître le logo en une fraction de seconde, ce qui donne l'impression
  /// d'un défaut d'affichage.
  static const Duration _minimumDisplay = Duration(milliseconds: 1800);

  /// Au-delà, on n'attend plus la session : mieux vaut afficher l'écran de
  /// connexion qu'un splash figé si le réseau est coupé.
  static const Duration _maximumWait = Duration(seconds: 6);

  bool _navigated = false;
  late final DateTime _startedAt;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _timeout = Timer(_maximumWait, () => _route(force: true));

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRoute());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRoute();
  }

  void _maybeRoute() {
    if (!mounted || _navigated) return;
    final auth = context.read<AuthProvider>();
    if (auth.state == SessionState.unknown) {
      // On se remet en attente : le provider notifiera, et le prochain
      // `didChangeDependencies` rappellera cette méthode.
      return;
    }
    _route();
  }

  Future<void> _route({bool force = false}) async {
    if (!mounted || _navigated) return;

    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed < _minimumDisplay) {
      await Future<void>.delayed(_minimumDisplay - elapsed);
      if (!mounted || _navigated) return;
    }

    _navigated = true;
    _timeout?.cancel();

    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();

    final String destination;
    if (!settings.onboardingSeen) {
      destination = AppRoutes.onboarding;
    } else if (auth.needsProfileCompletion) {
      // Teste avant `isSignedIn`, qui est vrai lui aussi dans ce cas.
      destination = AppRoutes.completeProfile;
    } else if (auth.isSignedIn || auth.isGuest) {
      destination = AppRoutes.home;
    } else {
      destination = AppRoutes.auth;
    }

    Navigator.pushReplacementNamed(context, destination);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Réagit aux changements de session pour déclencher l'aiguillage dès que
    // Firebase a tranché.
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRoute());

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF12211A), const Color(0xFF0B1510)]
                : [Colors.white, const Color(0xFFF0F7F4)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.slogan,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? Colors.white70
                        : AppTheme.textSecondaryLight,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
