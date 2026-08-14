import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/user_service.dart';
import '../legal/legal_screen.dart';

/// Profil et paramètres.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _version = '';
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      /* la version est un confort, pas une fonctionnalite */
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil',
          style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (auth.isSignedIn)
            _userHeader(auth.user!, isDark)
          else
            _guestHeader(isDark),
          const SizedBox(height: 8),
          if (auth.isSignedIn && auth.user!.isOwner) ...[
            _sectionTitle('Espace proprietaire'),
            _tile(
              icon: Icons.home_work_outlined,
              title: 'Mes annonces',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.ownerDashboard),
            ),
            _tile(
              icon: Icons.add_circle_outline,
              title: 'Publier une annonce',
              onTap: () => Navigator.pushNamed(context, AppRoutes.publish),
            ),
            if (!auth.user!.isVerified)
              _tile(
                icon: Icons.verified_outlined,
                title: 'Faire verifier mon profil',
                subtitle: 'Obtenez le badge « Proprietaire verifie »',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.verification),
              ),
          ],
          _sectionTitle('Mon activite'),
          _tile(
            icon: Icons.favorite_outline,
            title: 'Mes favoris',
            trailing: favorites.count == 0 ? null : '${favorites.count}',
            onTap: () => Navigator.pushNamed(context, AppRoutes.favorites),
          ),
          _tile(
            icon: Icons.notifications_active_outlined,
            title: 'Mes alertes de recherche',
            onTap: auth.isSignedIn
                ? () => Navigator.pushNamed(context, AppRoutes.alerts)
                : () => _requireAccount(),
          ),
          _tile(
            icon: Icons.notifications_none,
            title: 'Notifications recues',
            onTap: auth.isSignedIn
                ? () => Navigator.pushNamed(context, AppRoutes.notifications)
                : () => _requireAccount(),
          ),
          _sectionTitle('Parametres'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined, size: 22),
            title: Text('Notifications push',
                style: GoogleFonts.inter(fontSize: 14.5)),
            value: settings.notificationsEnabled,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (v) async {
              final granted = await settings.setNotificationsEnabled(v);
              if (v && !granted && mounted) {
                _snack('Autorisez les notifications dans les reglages de '
                    'votre appareil.');
              }
            },
          ),
          _themeTile(settings),
          _sectionTitle('Informations'),
          _tile(
            icon: Icons.description_outlined,
            title: 'Conditions generales',
            onTap: () => Navigator.pushNamed(context, AppRoutes.legal,
                arguments: LegalDocument.terms),
          ),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialite',
            onTap: () => Navigator.pushNamed(context, AppRoutes.legal,
                arguments: LegalDocument.privacy),
          ),
          _tile(
            icon: Icons.info_outline,
            title: 'A propos',
            subtitle: _version.isEmpty ? null : 'Version $_version',
            onTap: () => Navigator.pushNamed(context, AppRoutes.legal,
                arguments: LegalDocument.about),
          ),
          const SizedBox(height: 20),
          if (auth.isSignedIn) ...[
            _dangerTile(
              icon: Icons.logout,
              label: 'Se deconnecter',
              color: Theme.of(context).colorScheme.onSurface,
              onTap: _signOut,
            ),
            _dangerTile(
              icon: Icons.delete_forever_outlined,
              label: 'Supprimer mon compte',
              color: Theme.of(context).colorScheme.error,
              onTap: _deleteAccount,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.auth),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                ),
                child: Text('Se connecter / Creer un compte',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userHeader(UserModel user, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
            backgroundImage: (user.photoUrl?.isNotEmpty ?? false)
                ? NetworkImage(user.photoUrl!)
                : null,
            child: (user.photoUrl?.isNotEmpty ?? false)
                ? null
                : Text(
                    user.initials,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified,
                          size: 17, color: AppTheme.primaryGreen),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  user.role.label,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Theme.of(context).hintColor),
                ),
                if (user.hasActivePro) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Pack Pro actif',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryOrange,
                        )),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Modifier',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.editProfile),
          ),
        ],
      ),
    );
  }

  Widget _guestHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
            child: const Icon(Icons.person_outline,
                size: 30, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode visiteur',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  'Creez un compte pour contacter les proprietaires et '
                  'sauvegarder vos favoris.',
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeTile(SettingsProvider settings) {
    final label = switch (settings.themeMode) {
      ThemeMode.light => 'Clair',
      ThemeMode.dark => 'Sombre',
      ThemeMode.system => 'Systeme',
    };

    return ListTile(
      leading: const Icon(Icons.dark_mode_outlined, size: 22),
      title: Text('Apparence', style: GoogleFonts.inter(fontSize: 14.5)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Theme.of(context).hintColor)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              final modeLabel = switch (mode) {
                ThemeMode.light => 'Clair',
                ThemeMode.dark => 'Sombre',
                ThemeMode.system => 'Suivre le systeme',
              };
              return ListTile(
                leading: Icon(
                  switch (mode) {
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.dark => Icons.dark_mode_outlined,
                    ThemeMode.system => Icons.brightness_auto_outlined,
                  },
                  size: 21,
                ),
                title: Text(modeLabel,
                    style: GoogleFonts.inter(fontSize: 14.5)),
                trailing: settings.themeMode == mode
                    ? const Icon(Icons.check,
                        size: 20, color: AppTheme.primaryGreen)
                    : null,
                onTap: () {
                  settings.setThemeMode(mode);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14.5)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Theme.of(context).hintColor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _dangerTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: color),
      title: Text(label,
          style: GoogleFonts.inter(fontSize: 14.5, color: color)),
      onTap: _deleting ? null : onTap,
    );
  }

  void _requireAccount() {
    _snack('Creez un compte pour acceder a cette fonctionnalite.');
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se deconnecter ?'),
        content: const Text(
            'Vos favoris et vos messages resteront disponibles a la prochaine '
            'connexion.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Se deconnecter')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.auth, (route) => false);
  }

  /// Suppression définitive du compte.
  ///
  /// Exigée par Apple (5.1.1(v)) et Google Play dès lors qu'un compte peut
  /// être créé dans l'application. La double confirmation — dont une saisie
  /// explicite — évite les suppressions accidentelles d'une action strictement
  /// irréversible.
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 40, color: Theme.of(context).colorScheme.error),
        title: const Text('Supprimer definitivement ?'),
        content: const Text(
          'Cette action est irreversible. Seront supprimes :\n\n'
          '• votre compte et votre profil\n'
          '• toutes vos annonces et leurs photos\n'
          '• vos favoris et vos alertes\n\n'
          'Vos conversations seront anonymisees.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final typed = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Saisissez SUPPRIMER pour confirmer.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'SUPPRIMER'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (typed?.toUpperCase() != 'SUPPRIMER' || !mounted) return;

    setState(() => _deleting = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2)),
            SizedBox(width: 18),
            Expanded(child: Text('Suppression en cours…')),
          ],
        ),
      ),
    );

    try {
      await UserService.instance.deleteAccount();
      if (!mounted) return;
      Navigator.pop(context); // ferme l'indicateur
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.auth, (route) => false);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack(e is StateError ? e.message : 'Suppression impossible.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }
}
