import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/property.dart';
import '../../models/quarter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/property_provider.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/property_service.dart';
import '../../services/quarter_service.dart';
import '../../widgets/property_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../property_detail/property_detail_screen.dart';
import '../property_list/property_list_screen.dart';

/// Écran d'accueil : recherche, filtres rapides, « Près de vous »,
/// annonces récentes et quartiers populaires.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _selectedTypeIndex = 0;

  List<Property> _recent = const [];
  List<Property> _nearby = const [];
  List<Quarter> _quarters = const [];

  bool _loadingRecent = true;
  bool _loadingNearby = false;
  String? _nearbyMessage;

  /// Types proposés en filtres rapides, « Tous » en tête.
  static const List<String> _quickTypes = [
    'Tous',
    'Studio',
    'Appartement',
    'Villa',
    'Chambre',
    'Duplex',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadQuarters();
    _loadNearby();
  }

  Future<void> _loadRecent() async {
    try {
      final items = await PropertyService.instance.fetchRecent(limit: 10);
      if (!mounted) return;
      setState(() {
        _recent = items;
        _loadingRecent = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _loadQuarters() async {
    final quarters = await QuarterService.instance.fetchPopular();
    if (mounted) setState(() => _quarters = quarters);
  }

  /// Charge les logements proches.
  ///
  /// La permission n'est pas demandée au lancement mais ici, au moment où
  /// l'utilisateur voit à quoi elle sert : une demande à froid, dès la
  /// première seconde, se solde massivement par un refus définitif.
  Future<void> _loadNearby() async {
    setState(() {
      _loadingNearby = true;
      _nearbyMessage = null;
    });

    final result = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final latitude, :final longitude):
        try {
          final items = await PropertyService.instance.fetchNearby(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: 5000,
          );
          if (!mounted) return;
          setState(() {
            _nearby = items.take(10).toList();
            _loadingNearby = false;
            _nearbyMessage = items.isEmpty
                ? 'Aucun logement dans un rayon de 5 km pour le moment.'
                : null;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _loadingNearby = false;
            _nearbyMessage = 'Recherche a proximite indisponible.';
          });
        }
      case LocationServiceDisabled():
        setState(() {
          _loadingNearby = false;
          _nearbyMessage =
              'Activez la localisation de votre appareil pour voir les '
              'logements proches.';
        });
      case LocationDenied(:final permanently):
        setState(() {
          _loadingNearby = false;
          _nearbyMessage = permanently
              ? 'Autorisez la localisation dans les reglages pour voir les '
                  'logements proches.'
              : 'Autorisez la localisation pour voir les logements proches.';
        });
      case LocationFailure():
        setState(() {
          _loadingNearby = false;
          _nearbyMessage = 'Position indisponible pour le moment.';
        });
    }
  }

  void _openList({String? type, String? quarter, String? title}) {
    final provider = context.read<PropertyProvider>();
    var filters = provider.filters;
    filters = type == null
        ? filters.copyWith(clearType: true)
        : filters.copyWith(type: type);
    filters = quarter == null
        ? filters.copyWith(clearQuarter: true)
        : filters.copyWith(quarter: quarter);
    provider.applyFilters(filters);

    Navigator.pushNamed(
      context,
      AppRoutes.propertyList,
      arguments: PropertyListArgs(title: title),
    );
  }

  void _openDetail(Property property) {
    Navigator.pushNamed(
      context,
      AppRoutes.propertyDetail,
      arguments: PropertyDetailArgs.of(property),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadRecent(), _loadNearby()]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _header(auth, isDark),
              const SizedBox(height: 8),
              // SearchBarWidget porte sa propre marge horizontale : l'envelopper
              // dans un Padding la doublerait.
              SearchBarWidget(
                onTap: () => _openList(title: 'Rechercher'),
                onFilterTap: () => _openList(title: 'Rechercher'),
              ),
              const SizedBox(height: 16),
              _quickFilters(isDark),
              const SizedBox(height: 20),
              _nearbySection(isDark),
              const SizedBox(height: 24),
              _recentSection(isDark),
              const SizedBox(height: 24),
              if (_quarters.isNotEmpty) _quartersSection(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AuthProvider auth, bool isDark) {
    final name = auth.user?.name.split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name != null ? 'Bonjour $name' : 'Bonjour',
                  style: GoogleFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppConstants.slogan,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          if (auth.isSignedIn)
            StreamBuilder<int>(
              stream:
                  NotificationService.instance.watchUnreadCount(auth.uid!),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return IconButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none, size: 26),
                      if (count > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryOrange,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quickFilters(bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _quickTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _selectedTypeIndex == i;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedTypeIndex = i);
              _openList(
                type: i == 0 ? null : _quickTypes[i],
                title: i == 0 ? 'Tous les logements' : _quickTypes[i],
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryGreen
                    : (isDark ? AppTheme.cardDark : const Color(0xFFF0F3F1)),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Text(
                _quickTypes[i],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppTheme.textPrimaryLight),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nearbySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          isDark,
          'Pres de vous',
          action: _nearby.isEmpty ? null : 'Voir la carte',
          onAction: _nearby.isEmpty
              ? null
              : () => Navigator.pushNamed(context, AppRoutes.home,
                  arguments: 1),
        ),
        const SizedBox(height: 12),
        if (_loadingNearby)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_nearby.isNotEmpty)
          SizedBox(
            height: 268,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _nearby.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final property = _nearby[i];
                final position = LocationService.instance.lastKnown;
                String? distance;
                if (position != null && property.hasLocation) {
                  distance = LocationService.instance.formatDistance(
                    LocationService.instance.distanceBetween(
                      position.latitude,
                      position.longitude,
                      property.latitude!,
                      property.longitude!,
                    ),
                  );
                }
                return PropertyCard(
                  property: property,
                  variant: PropertyCardVariant.horizontal,
                  distanceLabel: distance,
                  onTap: () => _openDetail(property),
                );
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: Row(
                children: [
                  const Icon(Icons.near_me_outlined,
                      size: 22, color: AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _nearbyMessage ??
                          'Autorisez la localisation pour voir les logements '
                              'proches.',
                      style: GoogleFonts.inter(fontSize: 13, height: 1.45),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadNearby,
                    child: Text('Activer',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _recentSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          isDark,
          'Annonces recentes',
          action: 'Tout voir',
          onAction: () => _openList(title: 'Annonces recentes'),
        ),
        const SizedBox(height: 12),
        if (_loadingRecent)
          const SizedBox(
            height: 268,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Aucune annonce publiee pour le moment.',
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: Theme.of(context).hintColor),
            ),
          )
        else
          SizedBox(
            height: 268,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => PropertyCard(
                property: _recent[i],
                variant: PropertyCardVariant.horizontal,
                onTap: () => _openDetail(_recent[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _quartersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isDark, 'Quartiers populaires'),
        const SizedBox(height: 12),
        SizedBox(
          // Plus haut que les 96 px d'origine : une photo de quartier
          // ecrasee a la hauteur d'une simple pastille de texte ne se lit pas.
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _quarters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _quarterCard(_quarters[i]),
          ),
        ),
      ],
    );
  }

  Widget _quarterCard(Quarter quarter) {
    return GestureDetector(
      onTap: () => _openList(quarter: quarter.name, title: quarter.name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        child: SizedBox(
          width: 158,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _quarterImage(quarter),
              // Voile sombre du bas : le nom du quartier est blanc et
              // deviendrait illisible sur une photo claire — ciel de journee,
              // facade blanche — sans ce fond degrade.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x22000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.35, 0.6, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      quarter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (quarter.propertyCount > 0)
                      Text(
                        '${quarter.propertyCount} logements',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quarterImage(Quarter quarter) {
    final url = quarter.imageUrl;
    if (url == null || url.isEmpty) return _quarterFallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _quarterFallback(),
      // Une photo hebergee hors de nos serveurs peut disparaitre ou etre
      // renommee : on retombe sur le degrade plutot que sur une icone cassee.
      errorWidget: (_, __, ___) => _quarterFallback(),
    );
  }

  Widget _quarterFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.9),
            AppTheme.primaryGreenLight.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.location_city, size: 20, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    bool isDark,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
