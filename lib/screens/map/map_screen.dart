import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/property.dart';
import '../../providers/settings_provider.dart';
import '../../services/location_service.dart';
import '../../services/property_service.dart';
import '../../widgets/property_card.dart';
import '../property_detail/property_detail_screen.dart';

/// Carte interactive : marqueurs des logements, position de l'utilisateur,
/// filtre de distance et aperçu au tap.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  /// 3 km par défaut : à Abidjan, c'est l'ordre de grandeur d'un quartier.
  int _distanceIndex = 2;

  double _latitude = LocationService.abidjanLat;
  double _longitude = LocationService.abidjanLng;
  bool _hasUserPosition = false;

  List<Property> _properties = const [];
  Property? _selected;
  bool _loading = true;
  String? _message;

  int get _radiusMeters => AppConstants.distanceFilters[_distanceIndex];

  @override
  void initState() {
    super.initState();
    _locateThenLoad();
  }

  Future<void> _locateThenLoad() async {
    final result = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final latitude, :final longitude):
        _latitude = latitude;
        _longitude = longitude;
        _hasUserPosition = true;
        _message = null;
      case LocationServiceDisabled():
        _message = 'Localisation desactivee — carte centree sur Abidjan.';
      case LocationDenied():
        _message = 'Position non autorisee — carte centree sur Abidjan.';
      case LocationFailure():
        _message = 'Position indisponible — carte centree sur Abidjan.';
    }

    await _load();
    await _recenter();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await PropertyService.instance.fetchNearby(
        latitude: _latitude,
        longitude: _longitude,
        radiusMeters: _radiusMeters.toDouble(),
      );
      if (!mounted) return;
      setState(() {
        _properties = items;
        _loading = false;
        // Un marqueur sélectionné hors du nouveau rayon doit disparaître,
        // sinon l'aperçu resterait affiché sans point correspondant.
        if (_selected != null && !items.contains(_selected)) _selected = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Chargement des logements impossible.';
      });
    }
  }

  Future<void> _recenter() async {
    final controller = await _controller.future;
    // Le zoom suit le rayon : afficher 10 km au zoom d'une rue n'aurait
    // aucun sens, et l'inverse non plus.
    final zoom = switch (_radiusMeters) {
      <= 500 => 15.5,
      <= 1000 => 14.5,
      <= 3000 => 13.5,
      <= 5000 => 12.8,
      _ => 11.8,
    };
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(_latitude, _longitude), zoom: zoom),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return _properties.where((p) => p.hasLocation).map((property) {
      return Marker(
        markerId: MarkerId(property.id),
        position: LatLng(property.latitude!, property.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          property.isBoosted
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: property.title,
          snippet: AppConstants.formatPricePerMonth(property.price),
        ),
        onTap: () => setState(() => _selected = property),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDark ||
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_latitude, _longitude),
              zoom: 13.5,
            ),
            markers: _buildMarkers(),
            myLocationEnabled: _hasUserPosition,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: isDark ? _darkMapStyle : null,
            onMapCreated: (controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
            },
            // Toucher la carte hors d'un marqueur referme l'aperçu.
            onTap: (_) => setState(() => _selected = null),
          ),
          _topBar(isDark),
          if (_message != null) _banner(isDark),
          Positioned(
            right: 16,
            bottom: _selected != null ? 300 : 120,
            child: Column(
              children: [
                _roundButton(
                  icon: Icons.my_location,
                  onTap: () async {
                    await _locateThenLoad();
                  },
                ),
                const SizedBox(height: 10),
                _roundButton(
                  icon: Icons.refresh,
                  onTap: _load,
                ),
              ],
            ),
          ),
          _distanceFilter(isDark),
          if (_selected != null) _preview(_selected!),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _topBar(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 20, color: AppTheme.primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _loading
                      ? 'Recherche en cours…'
                      : '${_properties.length} logement(s) dans '
                          '${AppConstants.distanceLabel(_radiusMeters)}',
                  style: GoogleFonts.inter(
                      fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.view_list_outlined, size: 21),
                tooltip: 'Voir en liste',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.propertyList),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 76, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.secondaryOrange.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 17, color: Colors.white),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _message!,
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _distanceFilter(bool isDark) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _selected != null ? 268 : 24,
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: AppConstants.distanceFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final selected = _distanceIndex == i;
            return GestureDetector(
              onTap: () async {
                setState(() => _distanceIndex = i);
                await _load();
                await _recenter();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryGreen
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Text(
                  AppConstants.distanceLabel(
                      AppConstants.distanceFilters[i]),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _preview(Property property) {
    String? distance;
    if (_hasUserPosition && property.hasLocation) {
      distance = LocationService.instance.formatDistance(
        LocationService.instance.distanceBetween(
          _latitude,
          _longitude,
          property.latitude!,
          property.longitude!,
        ),
      );
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: SizedBox(
        height: 236,
        child: Align(
          alignment: Alignment.centerLeft,
          child: PropertyCard(
            property: property,
            variant: PropertyCardVariant.horizontal,
            distanceLabel: distance,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.propertyDetail,
              arguments: PropertyDetailArgs.of(property),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 21, color: AppTheme.primaryGreen),
        ),
      ),
    );
  }
}

/// Style de carte sombre, aligné sur le thème de l'application.
///
/// Sans lui, la carte reste blanche en mode sombre et éblouit — c'est le
/// défaut le plus visible d'une application censée proposer les deux modes.
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c25"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3a7"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2c25"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#4b6b5a"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6b9c82"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#22382c"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c4438"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ec7b0"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c5b4a"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2c4438"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f1c17"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4b6b5a"}]}
]
''';
