import 'dart:math' as math;

/// Encodage geohash et calcul des plages de prefixes couvrant un disque.
///
/// Firestore n'a pas de requete geospatiale : on ne peut pas demander « les
/// annonces a moins de 3 km ». Le contournement standard est le geohash — une
/// chaine dont le prefixe encode une cellule rectangulaire. Deux points proches
/// partagent (presque toujours) un prefixe. On interroge donc par plages
/// `>= prefixe` / `<= prefixe~`, puis on filtre au metre pres cote client.
///
/// Le « presque toujours » est la subtilite : deux points voisins de part et
/// d'autre d'une frontiere de cellule n'ont aucun prefixe commun. C'est
/// pourquoi [geohashQueryBounds] interroge aussi les huit cellules voisines.
class Geohash {
  Geohash._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static const double _earthRadiusMeters = 6378137.0;

  /// Longueur maximale d'un geohash exploitable (precision ~ 3,7 cm).
  static const int maxPrecision = 12;

  /// Metres couverts par une cellule, par longueur de geohash.
  /// Sert a choisir la precision de requete adaptee au rayon demande.
  static const List<double> _cellSizeMeters = [
    5009400.0, // 1
    1252300.0, // 2
    156500.0,  // 3
    39100.0,   // 4
    4900.0,    // 5
    1200.0,    // 6
    152.9,     // 7
    38.2,      // 8
    4.8,       // 9
    1.2,       // 10
  ];

  /// Encode un couple (latitude, longitude) en geohash.
  static String encode(double latitude, double longitude,
      {int precision = 9}) {
    assert(precision > 0 && precision <= maxPrecision);

    var latMin = -90.0, latMax = 90.0;
    var lonMin = -180.0, lonMax = 180.0;

    final buffer = StringBuffer();
    var bit = 0;
    var index = 0;
    var evenBit = true; // on alterne longitude / latitude

    while (buffer.length < precision) {
      if (evenBit) {
        final lonMid = (lonMin + lonMax) / 2;
        if (longitude > lonMid) {
          index = index * 2 + 1;
          lonMin = lonMid;
        } else {
          index = index * 2;
          lonMax = lonMid;
        }
      } else {
        final latMid = (latMin + latMax) / 2;
        if (latitude > latMid) {
          index = index * 2 + 1;
          latMin = latMid;
        } else {
          index = index * 2;
          latMax = latMid;
        }
      }
      evenBit = !evenBit;

      if (++bit == 5) {
        buffer.write(_base32[index]);
        bit = 0;
        index = 0;
      }
    }

    return buffer.toString();
  }

  /// Longueur de geohash suffisante pour couvrir [radiusMeters].
  static int _precisionForRadius(double radiusMeters) {
    for (var i = 0; i < _cellSizeMeters.length; i++) {
      if (_cellSizeMeters[i] < radiusMeters) {
        // La cellule precedente est la premiere plus large que le rayon.
        return math.max(1, i);
      }
    }
    return _cellSizeMeters.length;
  }

  /// Plages `[debut, fin]` de geohash a interroger pour couvrir le disque de
  /// centre ([latitude], [longitude]) et de rayon [radiusMeters].
  ///
  /// Utilisation cote Firestore :
  /// ```dart
  /// for (final b in Geohash.queryBounds(lat, lng, 3000)) {
  ///   query.orderBy('geohash').startAt([b.start]).endAt([b.end]);
  /// }
  /// ```
  /// Les resultats des differentes plages sont a fusionner et a re-filtrer
  /// avec [distanceBetween] : une plage deborde toujours un peu du disque.
  static List<GeohashRange> queryBounds(
    double latitude,
    double longitude,
    double radiusMeters,
  ) {
    final precision = _precisionForRadius(radiusMeters);
    final center = encode(latitude, longitude, precision: precision);

    // Les huit voisins + la cellule centrale : sans eux, un point situe juste
    // de l'autre cote d'une frontiere de cellule serait invisible.
    final cells = <String>{center, ..._neighbors(center)};

    return cells.map((c) => GeohashRange(c, '$c~')).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Distance orthodromique en metres entre deux points (formule de haversine).
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  // ── Calcul des cellules voisines ────────────────────────────────────────

  static const Map<String, List<String>> _neighborTable = {
    'n:even': ['p0r21436x8zb9dcf5h7kjnmqesgutwvy'],
    'n:odd': ['bc01fg45238967deuvhjyznpkmstqrwx'],
    's:even': ['14365h7k9dcfesgujnmqp0r2twvyx8zb'],
    's:odd': ['238967debc01fg45kmstqrwxuvhjyznp'],
    'e:even': ['bc01fg45238967deuvhjyznpkmstqrwx'],
    'e:odd': ['p0r21436x8zb9dcf5h7kjnmqesgutwvy'],
    'w:even': ['238967debc01fg45kmstqrwxuvhjyznp'],
    'w:odd': ['14365h7k9dcfesgujnmqp0r2twvyx8zb'],
  };

  static const Map<String, List<String>> _borderTable = {
    'n:even': ['prxz'],
    'n:odd': ['bcfguvyz'],
    's:even': ['028b'],
    's:odd': ['0145hjnp'],
    'e:even': ['bcfguvyz'],
    'e:odd': ['prxz'],
    'w:even': ['0145hjnp'],
    'w:odd': ['028b'],
  };

  static String _adjacent(String hash, String direction) {
    if (hash.isEmpty) return '';
    final last = hash[hash.length - 1];
    var parent = hash.substring(0, hash.length - 1);
    final type = hash.length.isEven ? 'even' : 'odd';

    if (_borderTable['$direction:$type']![0].contains(last) &&
        parent.isNotEmpty) {
      parent = _adjacent(parent, direction);
    }

    final index = _neighborTable['$direction:$type']![0].indexOf(last);
    if (index < 0) return hash; // caractere hors alphabet : on ne bouge pas
    return parent + _base32[index];
  }

  static List<String> _neighbors(String hash) {
    final n = _adjacent(hash, 'n');
    final s = _adjacent(hash, 's');
    return [
      n,
      s,
      _adjacent(hash, 'e'),
      _adjacent(hash, 'w'),
      _adjacent(n, 'e'),
      _adjacent(n, 'w'),
      _adjacent(s, 'e'),
      _adjacent(s, 'w'),
    ].where((h) => h.isNotEmpty).toList();
  }
}

/// Plage de geohash `[start, end]` a passer a `startAt` / `endAt`.
class GeohashRange {
  final String start;
  final String end;

  const GeohashRange(this.start, this.end);

  @override
  String toString() => 'GeohashRange($start .. $end)';

  @override
  bool operator ==(Object other) =>
      other is GeohashRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
