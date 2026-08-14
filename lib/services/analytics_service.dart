import 'package:firebase_analytics/firebase_analytics.dart';

/// Journalisation des evenements produit.
///
/// Le jeu d'evenements est deliberement reduit aux etapes de l'entonnoir qui
/// decideront des arbitrages : recherche → consultation → contact, et cote
/// offre, publication → validation. Instrumenter davantage produit du bruit
/// que personne ne lit.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> setUser({required String uid, required String role}) async {
    await _analytics.setUserId(id: uid);
    await _analytics.setUserProperty(name: 'role', value: role);
  }

  Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
  }

  // ── Entonnoir locataire ─────────────────────────────────────────────────

  Future<void> logSearch({
    required String query,
    String? type,
    String? quarter,
    int resultCount = 0,
  }) async {
    await _analytics.logSearch(searchTerm: query);
    await _analytics.logEvent(name: 'property_search', parameters: {
      'query': query,
      if (type != null) 'type': type,
      if (quarter != null) 'quarter': quarter,
      'result_count': resultCount,
    });
  }

  Future<void> logViewProperty({
    required String propertyId,
    required String type,
    required int price,
    required String quarter,
  }) async {
    await _analytics.logEvent(name: 'view_property', parameters: {
      'property_id': propertyId,
      'type': type,
      'price': price,
      'quarter': quarter,
    });
  }

  Future<void> logContactOwner(String propertyId) async {
    await _analytics.logEvent(name: 'contact_owner', parameters: {
      'property_id': propertyId,
    });
  }

  Future<void> logAddFavorite(String propertyId) async {
    await _analytics.logEvent(name: 'add_favorite', parameters: {
      'property_id': propertyId,
    });
  }

  Future<void> logShareProperty(String propertyId) async {
    await _analytics.logEvent(name: 'share_property', parameters: {
      'property_id': propertyId,
    });
  }

  Future<void> logCreateAlert() async {
    await _analytics.logEvent(name: 'create_alert');
  }

  // ── Entonnoir proprietaire ──────────────────────────────────────────────

  Future<void> logPublishStarted() async {
    await _analytics.logEvent(name: 'publish_started');
  }

  Future<void> logPublishSubmitted({
    required String type,
    required int price,
    required int photoCount,
  }) async {
    await _analytics.logEvent(name: 'publish_submitted', parameters: {
      'type': type,
      'price': price,
      'photo_count': photoCount,
    });
  }

  Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }
}
