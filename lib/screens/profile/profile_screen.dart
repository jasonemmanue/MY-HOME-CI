import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            _buildMenuSection(context),
            const SizedBox(height: 24),
            _buildVersionText(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor:
                AppTheme.primaryGreen.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person,
              size: 44,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Jean Kouame',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'jean.kouame@email.com',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '+225 07 08 09 10',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Modifier mon profil'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        // Section principale
        _buildMenuItem(
          icon: Icons.dashboard_outlined,
          title: 'Mon espace proprietaire',
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.ownerDashboard);
          },
        ),
        _buildMenuItem(
          icon: Icons.favorite_outline,
          title: 'Mes favoris',
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.favorites);
          },
        ),
        _buildMenuItem(
          icon: Icons.notifications_active_outlined,
          title: 'Mes alertes',
          onTap: () {},
        ),
        const Divider(indent: 16, endIndent: 16, height: 1),
        // Section preferences
        _buildSwitchItem(
          icon: Icons.dark_mode_outlined,
          title: 'Mode sombre',
          value: _darkMode,
          onChanged: (value) => setState(() => _darkMode = value),
        ),
        _buildSwitchItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          value: _notifications,
          onChanged: (value) => setState(() => _notifications = value),
        ),
        const Divider(indent: 16, endIndent: 16, height: 1),
        // Section informations
        _buildMenuItem(
          icon: Icons.info_outline,
          title: 'A propos de ${AppConstants.appName}',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.description_outlined,
          title: 'Conditions d\'utilisation',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'Aide et support',
          onTap: () {},
        ),
        const Divider(indent: 16, endIndent: 16, height: 1),
        // Section danger
        _buildMenuItem(
          icon: Icons.logout,
          title: 'Se deconnecter',
          isDestructive: true,
          onTap: () => _showLogoutDialog(context),
        ),
        _buildMenuItem(
          icon: Icons.delete_forever_outlined,
          title: 'Supprimer mon compte',
          isDestructive: true,
          onTap: () => _showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppTheme.errorColor : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        icon,
        color: color ?? AppTheme.textSecondaryLight,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: color ?? AppTheme.textSecondaryLight,
        size: 22,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        icon,
        color: AppTheme.textSecondaryLight,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildVersionText() {
    return Text(
      '${AppConstants.appName} v${AppConstants.appVersion}',
      style: const TextStyle(
        fontSize: 12,
        color: AppTheme.textSecondaryLight,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        title: const Text('Se deconnecter'),
        content: const Text(
          'Etes-vous sur de vouloir vous deconnecter ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Deconnexion (demo)'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Se deconnecter'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.errorColor, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Supprimer mon compte'),
            ),
          ],
        ),
        content: const Text(
          'Cette action est irreversible. Toutes vos donnees, annonces et messages seront definitivement supprimes.\n\nEtes-vous absolument sur ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suppression du compte (demo)'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
