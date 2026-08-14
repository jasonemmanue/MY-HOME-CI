import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

/// Etat de session tel que l'interface a besoin de le connaitre.
///
/// [guest] est un etat a part entiere, distinct de [signedOut] : le cahier des
/// charges autorise la consultation sans compte, mais l'application doit
/// savoir qu'un visiteur a explicitement choisi ce mode pour ne pas le
/// renvoyer sans cesse vers l'ecran d'authentification.
enum SessionState { unknown, signedOut, guest, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _listen();
  }

  final AuthService _auth = AuthService.instance;

  SessionState _state = SessionState.unknown;
  UserModel? _user;
  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<UserModel?>? _profileSub;

  SessionState get state => _state;
  UserModel? get user => _user;
  String? get uid => _user?.id ?? _auth.uid;

  bool get isSignedIn => _state == SessionState.signedIn;
  bool get isGuest => _state == SessionState.guest;
  bool get isOwner => _user?.isOwner ?? false;
  bool get isLoading => _state == SessionState.unknown;

  /// Le compte a-t-il ete suspendu par la moderation ?
  bool get isSuspended => _user?.isSuspended ?? false;

  void _listen() {
    _authSub = _auth.authStateChanges.listen((fbUser) async {
      await _profileSub?.cancel();
      _profileSub = null;

      if (fbUser == null) {
        _user = null;
        // On ne repasse pas un visiteur en `signedOut` : il a choisi ce mode,
        // le lui retirer le renverrait a l'ecran d'authentification a chaque
        // rafraichissement de session.
        if (_state != SessionState.guest) {
          _state = SessionState.signedOut;
        }
        notifyListeners();
        return;
      }

      _profileSub = UserService.instance.watch(fbUser.uid).listen((model) {
        _user = model;
        _state = SessionState.signedIn;
        notifyListeners();
      });

      // Post-connexion : on remonte les favoris pris en mode invite et on
      // enregistre l'appareil pour les notifications.
      unawaited(_afterSignIn(fbUser.uid));
    });
  }

  Future<void> _afterSignIn(String uid) async {
    try {
      await FavoritesService.instance.migrateGuestFavorites(uid);
    } catch (_) {}
    try {
      if (await NotificationService.instance.isPermissionGranted()) {
        await NotificationService.instance.requestPermissionAndRegister();
      }
    } catch (_) {}
    try {
      final role = _user?.role.name ?? 'tenant';
      await AnalyticsService.instance.setUser(uid: uid, role: role);
    } catch (_) {}
  }

  /// Entre en mode visiteur.
  void continueAsGuest() {
    if (_state == SessionState.signedIn) return;
    _state = SessionState.guest;
    notifyListeners();
  }

  /// Quitte le mode visiteur pour revenir a l'ecran d'authentification.
  void exitGuest() {
    if (_state != SessionState.guest) return;
    _state = SessionState.signedOut;
    notifyListeners();
  }

  Future<void> signOut() async {
    final currentUid = uid;
    if (currentUid != null) {
      await NotificationService.instance.unregisterCurrentDevice(currentUid);
    }
    await AnalyticsService.instance.clearUser();
    await _auth.signOut();
    _user = null;
    _state = SessionState.signedOut;
    notifyListeners();
  }

  /// Rafraichit le profil apres une modification (nom, photo).
  Future<void> refresh() async {
    final currentUid = uid;
    if (currentUid == null) return;
    _user = await UserService.instance.fetch(currentUid);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
