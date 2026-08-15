import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../services/property_service.dart';
import '../payment/payment_entry.dart';
import '../property_detail/property_detail_screen.dart';

/// Espace propriétaire : statistiques, liste des biens et actions rapides.
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  PropertyStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace proprietaire')),
        body: const Center(child: Text('Connexion requise.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes annonces',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.publish),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Publier',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<Property>>(
        stream: PropertyService.instance.watchByOwner(auth.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? const <Property>[];
          final visible = _filter == null
              ? all
              : all.where((p) => p.status == _filter).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _stats(all, isDark),
              const SizedBox(height: 18),
              if (!auth.user!.isVerified) ...[
                _verificationPrompt(isDark),
                const SizedBox(height: 18),
              ],
              if (!auth.user!.isPro) ...[
                _proPrompt(isDark),
                const SizedBox(height: 18),
              ],
              _statusFilters(all, isDark),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                _empty(isDark)
              else
                ...visible.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _propertyTile(p, isDark),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _stats(List<Property> properties, bool isDark) {
    final active =
        properties.where((p) => p.status == PropertyStatus.active).length;
    final views = properties.fold<int>(0, (sum, p) => sum + p.views);
    final favorites =
        properties.fold<int>(0, (sum, p) => sum + p.favoritesCount);

    return Row(
      children: [
        _statCard(isDark, Icons.home_work_outlined, '$active', 'Actives'),
        const SizedBox(width: 12),
        _statCard(isDark, Icons.visibility_outlined, '$views', 'Vues'),
        const SizedBox(width: 12),
        _statCard(isDark, Icons.favorite_outline, '$favorites', 'Favoris'),
      ],
    );
  }

  Widget _statCard(bool isDark, IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: AppTheme.primaryGreen),
            const SizedBox(height: 7),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }

  /// Un propriétaire non vérifié voit ses annonces publiées, mais sans badge —
  /// et le badge est le principal levier de confiance côté locataire.
  Widget _verificationPrompt(bool isDark) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.verification),
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.secondaryOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_outlined,
                size: 22, color: AppTheme.secondaryOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Faites verifier votre profil pour afficher le badge '
                '« Proprietaire verifie » sur vos annonces.',
                style: GoogleFonts.inter(fontSize: 12.5, height: 1.45),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }

  /// Acces a l'Espace Pro.
  ///
  /// Le libelle decrit le service, jamais son tarif : cet encart s'affiche
  /// aussi sur iOS, ou toute mention commerciale ferait rejeter l'application.
  /// Le prix n'apparait que dans le parcours Android, ou sur la page web.
  Widget _proPrompt(bool isDark) {
    return InkWell(
      onTap: () =>
          PaymentEntry.start(context, product: PaidProduct.pro),
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_outlined,
                size: 22, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Espace Pro',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    'Annonces illimitees, badge et statistiques detaillees.',
                    style: GoogleFonts.inter(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }

  Widget _statusFilters(List<Property> all, bool isDark) {
    final counts = <PropertyStatus, int>{};
    for (final p in all) {
      counts[p.status] = (counts[p.status] ?? 0) + 1;
    }

    final entries = <({PropertyStatus? status, String label, int count})>[
      (status: null, label: 'Toutes', count: all.length),
      ...PropertyStatus.values
          .where((s) => (counts[s] ?? 0) > 0)
          .map((s) => (status: s, label: s.label, count: counts[s]!)),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final entry = entries[i];
          final selected = _filter == entry.status;
          return GestureDetector(
            onTap: () => setState(() => _filter = entry.status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryGreen
                    : (isDark ? AppTheme.cardDark : const Color(0xFFF0F3F1)),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                '${entry.label} (${entry.count})',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _propertyTile(Property property, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.propertyDetail,
              arguments: PropertyDetailArgs.of(property),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: property.coverImage == null
                          ? Container(
                              color: AppTheme.primaryGreen
                                  .withValues(alpha: 0.15),
                              child: const Icon(Icons.home_rounded,
                                  color: AppTheme.primaryGreen),
                            )
                          : CachedNetworkImage(
                              imageUrl: property.coverImage!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.15),
                                child: const Icon(Icons.home_rounded,
                                    color: AppTheme.primaryGreen),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _statusChip(property.status),
                            if (property.isBoosted) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.trending_up,
                                  size: 15, color: AppTheme.secondaryOrange),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          property.title.isEmpty
                              ? 'Brouillon sans titre'
                              : property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppConstants.formatPricePerMonth(property.price),
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 13,
                                color: Theme.of(context).hintColor),
                            const SizedBox(width: 3),
                            Text('${property.views}',
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: Theme.of(context).hintColor)),
                            const SizedBox(width: 12),
                            Icon(Icons.favorite_outline,
                                size: 13,
                                color: Theme.of(context).hintColor),
                            const SizedBox(width: 3),
                            Text('${property.favoritesCount}',
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: Theme.of(context).hintColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (property.status == PropertyStatus.rejected &&
              property.rejectionReason != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                'Motif : ${property.rejectionReason}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Divider(
            height: 1,
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),
          _actions(property),
        ],
      ),
    );
  }

  Widget _actions(Property property) {
    Widget action(IconData icon, String label, VoidCallback? onTap) {
      return Expanded(
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return Row(
      children: [
        action(Icons.edit_outlined, 'Modifier',
            () => Navigator.pushNamed(context, AppRoutes.publish,
                arguments: property)),
        if (property.status == PropertyStatus.active)
          action(Icons.check_circle_outline, 'Loue',
              () => _confirm(
                    'Marquer comme loue ?',
                    'L\'annonce n\'apparaitra plus dans les resultats.',
                    () => PropertyService.instance.markAsRented(property.id),
                  ))
        else if (property.status == PropertyStatus.draft)
          action(Icons.publish_outlined, 'Publier',
              property.isPublishable
                  ? () => _submit(property)
                  : () => _snack(
                      'Completez l\'annonce (titre, description, photos, '
                      'localisation) avant de la publier.'))
        else if (property.status == PropertyStatus.rented ||
            property.status == PropertyStatus.archived)
          action(Icons.replay, 'Republier',
              () => PropertyService.instance.republish(property.id))
        else
          action(Icons.hourglass_empty, 'En attente', null),
        // La mise en avant n'a de sens que sur une annonce visible, et il
        // serait absurde de la revendre a une annonce deja en tete.
        if (property.status == PropertyStatus.active && !property.isBoosted)
          action(
            Icons.trending_up,
            'En avant',
            () => PaymentEntry.start(
              context,
              product: PaidProduct.boost,
              targetId: property.id,
            ),
          ),
        action(
          Icons.delete_outline,
          'Supprimer',
          () => _confirm(
            'Supprimer cette annonce ?',
            'Cette action est definitive.',
            () => PropertyService.instance.delete(property.id),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(Property property) async {
    await PropertyService.instance.submitForReview(property.id);
    _snack('Annonce envoyee en moderation. Vous serez notifie apres examen.');
  }

  Future<void> _confirm(
      String title, String message, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed == true) await action();
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

  Widget _statusChip(PropertyStatus status) {
    final color = switch (status) {
      PropertyStatus.active => AppTheme.primaryGreen,
      PropertyStatus.pending => AppTheme.secondaryOrange,
      PropertyStatus.rejected => const Color(0xFFD64545),
      PropertyStatus.rented => const Color(0xFF1565C0),
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _empty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.home_work_outlined,
              size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text(
            _filter == null
                ? 'Aucune annonce.\nPubliez votre premier logement.'
                : 'Aucune annonce dans cette categorie.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
