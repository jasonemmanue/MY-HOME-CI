import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resultat d'une demande de position : soit des coordonnees, soit la raison
/// precise de l'echec.
///
/// Un simple `null` ne suffirait pas : l'ecran doit distinguer « service
/// desactive » (proposer d'ouvrir les reglages systeme) de « permission
/// refusee definitivement » (proposer d'ouvrir les reglages de l'app), sinon
/// l'utilisateur tourne en rond.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  final double latitude;
  final double longitude;
  const LocationSuccess(this.latitude, this.longitude);
}

class LocationDenied extends LocationResult {
  /// `true` si l'utilisateur a coche « ne plus demander » : seule une visite
  /// aux reglages de l'application peut alors debloquer la situation.
  final bool permanently;
  const LocationDenied({this.permanently = false});
}

class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

class LocationFailure extends LocationResult {
  final String message;
  const LocationFailure(this.message);
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Centre d'Abidjan — repli quand la position reelle est indisponible.
  /// Mieux vaut une carte centree sur la bonne ville qu'au large du golfe de
  /// Guinee (coordonnees 0,0).
  static const double abidjanLat = 5.3599517;
  static const double abidjanLng = -4.0082563;

  Position? _lastKnown;
  Position? get lastKnown => _lastKnown;

  /// Demande la position courante, en gerant permissions et service systeme.
  Future<LocationResult> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServiceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationDenied(permanently: true);
      }
      if (permission == LocationPermission.denied) {
        return const LocationDenied();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
      _lastKnown = position;
      return LocationSuccess(position.latitude, position.longitude);
    } catch (e) {
      // Le GPS peut expirer en interieur : plutot que d'echouer sec, on
      // reutilise la derniere position connue si on en a une.
      if (_lastKnown != null) {
        return LocationSuccess(_lastKnown!.latitude, _lastKnown!.longitude);
      }
      return LocationFailure('Position indisponible : $e');
    }
  }

  /// Suivi continu, pour le point bleu de la carte.
  Stream<Position> watchPosition({int distanceFilterMeters = 25}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) =>
      Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

  /// Libelle lisible d'une distance : « 450 m », « 2,3 km ».
  String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
  }

  // ── Geocodage ───────────────────────────────────────────────────────────

  /// Adresse approximative d'un point, pour prerenseigner le formulaire de
  /// publication apres selection sur la carte.
  Future<String?> addressFromCoordinates(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return null;
      final p = places.first;
      final parts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.trim().isNotEmpty)
          .cast<String>();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Quartier devine a partir d'un point, compare a la liste connue.
  Future<String?> quarterFromCoordinates(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return null;
      return places.first.subLocality?.trim().isNotEmpty == true
          ? places.first.subLocality
          : places.first.locality;
    } catch (_) {
      return null;
    }
  }

  Future<({double lat, double lng})?> coordinatesFromAddress(
      String address) async {
    try {
      final results = await locationFromAddress('$address, Cote d\'Ivoire');
      if (results.isEmpty) return null;
      return (lat: results.first.latitude, lng: results.first.longitude);
    } catch (_) {
      return null;
    }
  }
}
