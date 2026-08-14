import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/property_service.dart';
import '../../widgets/property_card.dart';
import '../property_detail/property_detail_screen.dart';

/// Annonces mises de côté.
///
/// Les identifiants viennent de [FavoritesProvider] (temps réel), les annonces
/// elles-mêmes sont rechargées à la demande : garder les documents complets en
/// mémoire les figerait, alors qu'un loyer ou un statut peut changer.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Property> _properties = const [];
  Set<String> _loadedFor = const {};
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithFavorites();
  }

  Future<void> _syncWithFavorites() async {
    // `read` et non `watch` : la dependance est deja enregistree par le
    // `watch` de build(), c'est lui qui declenche ce rappel via
    // didChangeDependencies. Un `watch` ici n'ajouterait rien et serait
    // invalide apres le premier `await`.
    final favorites = context.read<FavoritesProvider>();
    final ids = favorites.ids;

    // On ne recharge que si l'ensemble a changé : sans cette garde, chaque
    // notification du provider relancerait une requête réseau.
    if (ids.length == _loadedFor.length && ids.containsAll(_loadedFor)) return;

    _loadedFor = {...ids};

    if (ids.isEmpty) {
      setState(() {
        _properties = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final ordered = await favorites.orderedIds();
      final loaded = await PropertyService.instance.fetchByIds(ordered);
      if (!mounted) return;
      setState(() {
        _properties = loaded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favoris',
          style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (favorites.count > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${favorites.count}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _body(auth, favorites),
    );
  }

  Widget _body(AuthProvider auth, FavoritesProvider favorites) {
    if (_loading && _properties.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (favorites.count == 0) {
      return _empty(auth);
    }

    // Une annonce archivée par son propriétaire disparaît de la liste mais
    // reste dans les favoris : on le signale plutôt que de laisser l'écart
    // passer pour un bug.
    final missing = favorites.count - _properties.length;

    return RefreshIndicator(
      onRefresh: () async {
        _loadedFor = const {};
        await _syncWithFavorites();
      },
      child: CustomScrollView(
        slivers: [
          if (missing > 0)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppTheme.secondaryOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        missing == 1
                            ? '1 annonce enregistree n\'est plus disponible.'
                            : '$missing annonces enregistrees ne sont plus '
                                'disponibles.',
                        style: GoogleFonts.inter(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final property = _properties[i];
                  return PropertyCard(
                    property: property,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.propertyDetail,
                      arguments: PropertyDetailArgs.of(property),
                    ),
                  );
                },
                childCount: _properties.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AuthProvider auth) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border,
                size: 60, color: Theme.of(context).disabledColor),
            const SizedBox(height: 20),
            Text(
              'Aucun favori',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur le coeur d\'une annonce pour la retrouver ici.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ),
            if (auth.isGuest) ...[
              const SizedBox(height: 20),
              Text(
                'Vos favoris sont enregistres sur cet appareil. Creez un '
                'compte pour les retrouver partout.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.auth),
                child: Text('Creer un compte',
                    style: GoogleFonts.inter(fontSize: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
