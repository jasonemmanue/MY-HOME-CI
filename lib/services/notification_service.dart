import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';

/// Point d'entree unique des notifications : jeton FCM, permissions,
/// affichage en premier plan et routage au tap.
///
/// Le routage passe par [onOpenTarget] plutot que par un `Navigator` capture :
/// une notification peut arriver alors qu'aucun contexte n'est monte, et
/// conserver une reference de navigation ici provoquerait des fuites.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Appele quand l'utilisateur ouvre une notification.
  /// `(type, targetId)` — a brancher sur la navigation dans `app.dart`.
  void Function(String type, String? targetId)? onOpenTarget;

  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'my_home_ci_channel',
    'Notifications My Home CI',
    description: 'Messages, alertes de recherche et suivi de vos annonces',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _setupLocalNotifications();

    // Android 13+ et iOS exigent un consentement explicite. On ne le demande
    // pas au tout premier lancement : l'appel est declenche depuis l'ecran de
    // profil ou apres la premiere action utile, pour ne pas gaspiller
    // l'unique occasion de poser la question.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    // Application lancee depuis une notification alors qu'elle etait fermee.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onOpened(initial);
    }

    _messaging.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _saveToken(uid, token);
    });
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final parts = payload.split('|');
        onOpenTarget?.call(parts.first, parts.length > 1 ? parts[1] : null);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Demande le consentement puis enregistre le jeton.
  /// Renvoie `true` si les notifications sont autorisees.
  Future<bool> requestPermissionAndRegister() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) return false;

    // Sur iOS, le jeton FCM n'existe qu'une fois le jeton APNs disponible.
    // Le demander trop tot renvoie null sans erreur — d'ou l'attente courte.
    if (Platform.isIOS) {
      final apns = await _messaging.getAPNSToken();
      if (apns == null) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    final token = await _messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await _saveToken(uid, token);
    }
    return true;
  }

  Future<bool> isPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Enregistre le jeton dans `users/{uid}/tokens/{token}`.
  ///
  /// Un document par jeton, et non un tableau : un utilisateur a souvent
  /// plusieurs appareils, et cette forme permet de purger un jeton devenu
  /// invalide sans relire tout le document utilisateur.
  Future<void> _saveToken(String uid, String token) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .set({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Enregistrement du jeton FCM impossible : $e');
    }
  }

  /// Retire le jeton de l'appareil courant. A appeler a la deconnexion, sans
  /// quoi l'appareil continue de recevoir les notifications du compte quitte.
  Future<void> unregisterCurrentDevice(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _db
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .delete();
    } catch (_) {}
  }

  // ── Reception ───────────────────────────────────────────────────────────

  /// En premier plan, le systeme n'affiche rien : c'est a l'application de le
  /// faire, d'ou la notification locale.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload:
          '${message.data['type'] ?? 'admin'}|${message.data['targetId'] ?? ''}',
    );
  }

  void _onOpened(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? 'admin';
    final targetId = message.data['targetId']?.toString();
    onOpenTarget?.call(type, targetId?.isEmpty == true ? null : targetId);
  }

  // ── Historique in-app ───────────────────────────────────────────────────

  Stream<List<AppNotification>> watchNotifications(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromFirestore).toList());
  }

  Stream<int> watchUnreadCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markRead(String uid, String notificationId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .limit(100)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

/// Handler des messages recus alors que l'application est terminee.
///
/// Doit etre une fonction de premier niveau : Flutter la reveille dans un
/// isolate distinct, sans acces a l'etat de l'application.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Rien a faire ici : le systeme affiche deja la notification. Le point
  // d'entree doit exister pour que FCM ne journalise pas d'avertissement.
}
