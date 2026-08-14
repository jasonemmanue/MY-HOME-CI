import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/property.dart';
import '../../models/quarter.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/property_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/chat_service.dart';
import '../../services/property_service.dart';
import '../../services/quarter_service.dart';
import '../../services/report_service.dart';
import '../../widgets/quarter_info_card.dart';
import '../chat/chat_detail_screen.dart';

/// Arguments de la fiche détail.
///
/// L'écran accepte soit l'annonce déjà chargée (navigation depuis une liste :
/// affichage immédiat), soit son seul identifiant (arrivée par notification ou
/// lien partagé : il faut alors la charger). Sans les deux, une ouverture
/// depuis une notification afficherait un écran vide.
class PropertyDetailArgs {
  final String propertyId;
  final Property? property;

  const PropertyDetailArgs({required this.propertyId, this.property});

  factory PropertyDetailArgs.of(Property property) =>
      PropertyDetailArgs(propertyId: property.id, property: property);
}

class PropertyDetailScreen extends StatefulWidget {
  final PropertyDetailArgs args;

  const PropertyDetailScreen({super.key, required this.args});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Property? _property;
  Quarter? _quarter;
  bool _loading = false;
  bool _contacting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _property = widget.args.property;

    if (_property == null) {
      _load();
    } else {
      _afterLoad(_property!);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final loaded =
          await PropertyService.instance.fetchById(widget.args.propertyId);
      if (!mounted) return;
      if (loaded == null) {
        setState(() {
          _error = 'Cette annonce n\'est plus disponible.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _property = loaded;
        _loading = false;
      });
      _afterLoad(loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger cette annonce.';
        _loading = false;
      });
    }
  }

  void _afterLoad(Property property) {
    // Le comptage passe par le provider, qui déduplique : sans cela, chaque
    // reconstruction de l'écran ajouterait une vue.
    context.read<PropertyProvider>().countView(property);
    _loadQuarter(property.quarter);
  }

  Future<void> _loadQuarter(String name) async {
    final quarter = await QuarterService.instance.fetchByName(name);
    if (mounted && quarter != null) setState(() => _quarter = quarter);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _contactOwner() async {
    final property = _property;
    if (property == null || _contacting) return;

    final auth = context.read<AuthProvider>();

    if (!auth.isSignedIn) {
      _promptSignIn(
        'Creez un compte pour contacter le proprietaire directement dans '
        'l\'application, sans echanger vos numeros de telephone.',
      );
      return;
    }
    if (auth.user!.id == property.ownerId) {
      _snack('Il s\'agit de votre propre annonce.');
      return;
    }

    setState(() => _contacting = true);
    try {
      final conversationId = await ChatService.instance.openConversation(
        property: property,
        tenant: auth.user!,
      );
      await AnalyticsService.instance.logContactOwner(property.id);

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.chatDetail,
        arguments: ChatDetailArgs(conversationId: conversationId),
      );
    } catch (_) {
      _snack('Impossible d\'ouvrir la conversation. Reessayez.',
          isError: true);
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  void _promptSignIn(String message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline,
                size: 40, color: AppTheme.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'Compte requis',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.auth);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                ),
                child: Text('Creer un compte',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    final property = _property;
    if (property == null) return;

    await AnalyticsService.instance.logShareProperty(property.id);
    await Share.share(
      '${property.title}\n'
      '${AppConstants.formatPricePerMonth(property.price)}\n'
      '${property.quarter}, ${property.city}\n\n'
      'A decouvrir sur My Home CI :\n'
      'https://myhomeci.ci/annonce/${property.id}',
      subject: property.title,
    );
  }

  Future<void> _report() async {
    final property = _property;
    if (property == null) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Signaler cette annonce',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            ...Report.reasons.map(
              (reason) => ListTile(
                title: Text(reason, style: GoogleFonts.inter(fontSize: 14)),
                onTap: () => Navigator.pop(context, reason),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (reason == null) return;

    try {
      await ReportService.instance
          .reportProperty(propertyId: property.id, reason: reason);
      _snack('Signalement transmis. Merci de nous aider a garder la '
          'plateforme fiable.');
    } catch (_) {
      _snack('Envoi du signalement impossible.', isError: true);
    }
  }

  void _openGallery(int initialIndex) {
    final images = _property?.images ?? const <String>[];
    if (images.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _FullScreenGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  // ── Rendu ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _property == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined,
                    size: 56, color: Theme.of(context).disabledColor),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Annonce introuvable.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final property = _property!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _gallerySliver(property),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(property, isDark),
                  const SizedBox(height: 20),
                  _characteristics(property, isDark),
                  if (property.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _section(isDark, 'Description'),
                    const SizedBox(height: 8),
                    Text(
                      property.description,
                      style: GoogleFonts.inter(fontSize: 14, height: 1.65),
                    ),
                  ],
                  if (property.equipment.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _section(isDark, 'Equipements'),
                    const SizedBox(height: 12),
                    _equipment(property, isDark),
                  ],
                  if (property.hasLocation) ...[
                    const SizedBox(height: 24),
                    _section(isDark, 'Localisation'),
                    const SizedBox(height: 12),
                    _miniMap(property),
                  ],
                  const SizedBox(height: 24),
                  _section(isDark, 'Decouvrir le quartier'),
                  const SizedBox(height: 12),
                  _quarterSection(property, isDark),
                  const SizedBox(height: 24),
                  _ownerCard(property, isDark),
                  const SizedBox(height: 20),
                  _safetyNotice(isDark),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _report,
                      icon: const Icon(Icons.flag_outlined, size: 17),
                      label: Text('Signaler cette annonce',
                          style: GoogleFonts.inter(fontSize: 13)),
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).hintColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(property, isDark),
    );
  }

  Widget _gallerySliver(Property property) {
    final images = property.images;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: _circleButton(
        icon: Icons.arrow_back,
        onTap: () => Navigator.maybePop(context),
      ),
      actions: [
        Consumer<FavoritesProvider>(
          builder: (context, favorites, _) => _circleButton(
            icon: favorites.isFavorite(property.id)
                ? Icons.favorite
                : Icons.favorite_border,
            color: favorites.isFavorite(property.id)
                ? const Color(0xFFE53935)
                : null,
            onTap: () => favorites.toggle(property.id),
          ),
        ),
        _circleButton(icon: Icons.share_outlined, onTap: _share),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryGreenLight
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.home_rounded,
                      size: 72, color: Colors.white38),
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _openGallery(i),
                  child: CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.black12,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${images.length}',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color ?? Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _header(Property property, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                property.type,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.visibility_outlined,
                size: 15, color: Theme.of(context).hintColor),
            const SizedBox(width: 4),
            Text(
              '${property.views} vues',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          property.title,
          style: GoogleFonts.poppins(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.location_on_outlined,
                size: 16, color: Theme.of(context).hintColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                property.address.isNotEmpty
                    ? property.address
                    : '${property.quarter}, ${property.city}',
                style: GoogleFonts.inter(
                    fontSize: 13.5, color: Theme.of(context).hintColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          AppConstants.formatPricePerMonth(property.price),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _characteristics(Property property, bool isDark) {
    final items = <({IconData icon, String label, String value})>[
      (icon: Icons.bed_outlined, label: 'Pieces', value: '${property.rooms}'),
      (
        icon: Icons.bathtub_outlined,
        label: 'Salles d\'eau',
        value: '${property.bathrooms}'
      ),
      if (property.surface > 0)
        (
          icon: Icons.square_foot,
          label: 'Surface',
          value: '${property.surface.toInt()} m²'
        ),
      if (property.floor > 0)
        (
          icon: Icons.stairs_outlined,
          label: 'Etage',
          value: '${property.floor}'
        ),
      (
        icon: Icons.chair_outlined,
        label: 'Meuble',
        value: property.isFurnished ? 'Oui' : 'Non'
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items
            .map(
              (item) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 21, color: AppTheme.primaryGreen),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _equipment(Property property, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: property.equipment
          .map(
            (item) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_equipmentIcon(item),
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 7),
                  Text(item, style: GoogleFonts.inter(fontSize: 13)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  IconData _equipmentIcon(String equipment) {
    final lower = equipment.toLowerCase();
    if (lower.contains('climatisation')) return Icons.ac_unit;
    if (lower.contains('piscine')) return Icons.pool;
    if (lower.contains('parking') || lower.contains('garage')) {
      return Icons.local_parking;
    }
    if (lower.contains('gardien') || lower.contains('securite')) {
      return Icons.security;
    }
    if (lower.contains('wifi') || lower.contains('internet')) return Icons.wifi;
    if (lower.contains('cuisine')) return Icons.kitchen;
    if (lower.contains('balcon')) return Icons.balcony;
    if (lower.contains('jardin') || lower.contains('cour')) return Icons.yard;
    if (lower.contains('ascenseur')) return Icons.elevator;
    if (lower.contains('eau')) return Icons.water_drop;
    if (lower.contains('electr')) return Icons.bolt;
    if (lower.contains('meuble')) return Icons.chair;
    return Icons.check_circle_outline;
  }

  Widget _miniMap(Property property) {
    final position = LatLng(property.latitude!, property.longitude!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: position, zoom: 15),
          markers: {
            Marker(markerId: MarkerId(property.id), position: position),
          },
          // Carte purement illustrative : la manipuler dans une page qui
          // défile capturerait les gestes de défilement.
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }

  Widget _quarterSection(Property property, bool isDark) {
    final amenities = _quarter?.amenities ?? const <String, int>{};

    if (amenities.isEmpty) {
      // Repli générique tant que la fiche quartier n'est pas renseignée côté
      // administration : mieux vaut une information neutre qu'une section vide.
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined,
                size: 22, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${property.quarter} — ${property.city}',
                style: GoogleFonts.inter(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: amenities.entries.take(8).map((entry) {
        return QuarterInfoCard(
          icon: _amenityIcon(entry.key),
          label: Quarter.amenityLabels[entry.key] ?? entry.key,
          count: '${entry.value}',
        );
      }).toList(),
    );
  }

  IconData _amenityIcon(String key) {
    switch (key) {
      case 'schools':
        return Icons.school_outlined;
      case 'pharmacies':
        return Icons.local_pharmacy_outlined;
      case 'hospitals':
        return Icons.local_hospital_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'banks':
        return Icons.account_balance_outlined;
      case 'restaurants':
        return Icons.restaurant_outlined;
      case 'markets':
        return Icons.storefront_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _ownerCard(Property property, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
            backgroundImage: (property.ownerPhotoUrl?.isNotEmpty ?? false)
                ? NetworkImage(property.ownerPhotoUrl!)
                : null,
            child: (property.ownerPhotoUrl?.isNotEmpty ?? false)
                ? null
                : Text(
                    property.ownerName.isEmpty
                        ? '?'
                        : property.ownerName[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        property.ownerName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                    ),
                    if (property.ownerIsVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified,
                          size: 16, color: AppTheme.primaryGreen),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  property.ownerIsVerified
                      ? 'Proprietaire verifie'
                      : 'Proprietaire',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              size: 20, color: AppTheme.secondaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ne versez jamais d\'argent avant d\'avoir visite le logement. '
              'My Home CI ne gere aucun paiement entre utilisateurs.',
              style: GoogleFonts.inter(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(bool isDark, String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
      ),
    );
  }

  Widget _bottomBar(Property property, bool isDark) {
    final auth = context.watch<AuthProvider>();
    final isOwnListing = auth.user?.id == property.ownerId;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_contacting || isOwnListing) ? null : _contactOwner,
            icon: _contacting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.chat_bubble_outline, size: 19),
            label: Text(
              isOwnListing
                  ? 'Votre annonce'
                  : 'Contacter le proprietaire',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Galerie plein écran, avec zoom.
class _FullScreenGallery extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: PhotoViewGallery.builder(
        itemCount: images.length,
        pageController: PageController(initialPage: initialIndex),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        builder: (context, index) => PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(images[index]),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
        ),
      ),
    );
  }
}
