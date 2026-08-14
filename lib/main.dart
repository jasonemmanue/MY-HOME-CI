import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // `runZonedGuarded` capture les erreurs asynchrones qui echappent a
  // `FlutterError.onError` — typiquement une exception dans un `Future` non
  // attendu. Sans elle, ces plantages n'apparaissent jamais dans Crashlytics.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _setUpCrashReporting();
    await _setUpAppCheck();
    _setUpFirestore();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Sans ces deux initialisations, `DateFormat('d MMMM', 'fr_FR')` leve une
    // exception a la premiere ouverture d'une conversation, et timeago affiche
    // ses libelles en anglais.
    await initializeDateFormatting('fr_FR', null);
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('fr_short', timeago.FrShortMessages());

    // Le theme doit etre connu avant le premier rendu : le charger apres
    // ferait clignoter l'application en clair avant de basculer en sombre.
    final settings = SettingsProvider();
    await settings.load();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      // Le paysage reste autorise : le cahier des charges cible aussi la
      // tablette, et Apple rejette les applications iPad bloquees en portrait
      // sans justification.
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    runApp(MyHomeCIApp(settings: settings));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

void _setUpCrashReporting() {
  // En debug, les remontees polluent la console et la base Crashlytics avec
  // des erreurs de developpement.
  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _setUpAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // En debug, le fournisseur `debug` evite d'avoir a enregistrer chaque
      // machine de developpement dans la console.
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  } catch (e) {
    // App Check non configure ne doit pas empecher l'application de demarrer :
    // l'imposer avant que la console soit prete rendrait l'app inutilisable.
    debugPrint('App Check indisponible : $e');
  }
}

void _setUpFirestore() {
  // Consultation hors connexion des annonces deja vues — exigence explicite
  // du cahier des charges (§5.1) et confort reel sur reseau 3G instable.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024,
  );
}
