import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/search_alert.dart';
import '../../providers/auth_provider.dart';
import '../../providers/property_provider.dart';
import '../../services/alert_service.dart';
import '../property_list/property_list_screen.dart';

/// Alertes de recherche enregistrées.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes alertes',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: uid == null
          ? const _Empty(message: 'Connectez-vous pour gerer vos alertes.')
          : StreamBuilder<List<SearchAlert>>(
              stream: AlertService.instance.watch(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final alerts = snapshot.data ?? const <SearchAlert>[];
                if (alerts.isEmpty) {
                  return const _Empty(
                    message: 'Aucune alerte.\n\nDepuis la liste des logements, '
                        'appliquez vos filtres puis enregistrez-les en alerte '
                        'pour etre prevenu des nouvelles annonces.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _AlertCard(uid: uid, alert: alerts[i]),
                );
              },
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String uid;
  final SearchAlert alert;

  const _AlertCard({required this.uid, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ),
              Switch(
                value: alert.isActive,
                activeThumbColor: AppTheme.primaryGreen,
                onChanged: (v) => AlertService.instance.setActive(
                  userId: uid,
                  alertId: alert.id,
                  isActive: v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alert.criteriaSummary,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          if (alert.matchCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${alert.matchCount} logement(s) trouve(s) depuis la creation',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.secondaryOrange),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await context
                      .read<PropertyProvider>()
                      .applyFilters(AlertService.instance.toFilters(alert));
                  if (!context.mounted) return;
                  Navigator.pushNamed(
                    context,
                    AppRoutes.propertyList,
                    arguments: PropertyListArgs(title: alert.label),
                  );
                },
                icon: const Icon(Icons.search, size: 18),
                label: Text('Voir les resultats',
                    style: GoogleFonts.inter(fontSize: 13)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette alerte ?'),
        content: Text('« ${alert.label} » ne vous notifiera plus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AlertService.instance.delete(userId: uid, alertId: alert.id);
    }
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 56,
                color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
