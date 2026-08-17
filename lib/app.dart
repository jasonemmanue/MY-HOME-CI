import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/constants.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'models/property.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/property_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/chat/chat_detail_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/legal/legal_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/owner_dashboard/owner_dashboard_screen.dart';
import 'screens/profile/alerts_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/verification_screen.dart';
import 'screens/property_detail/property_detail_screen.dart';
import 'screens/property_list/property_list_screen.dart';
import 'screens/publish_property/publish_property_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

class MyHomeCIApp extends StatefulWidget {
  final SettingsProvider settings;

  const MyHomeCIApp({super.key, required this.settings});

  @override
  State<MyHomeCIApp> createState() => _MyHomeCIAppState();
}

class _MyHomeCIAppState extends State<MyHomeCIApp> {
  /// Clef de navigation globale : les notifications arrivent hors de tout
  /// `BuildContext` et doivent pouvoir pousser un ecran malgre tout.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  late final AuthProvider _auth;
  late final FavoritesProvider _favorites;

  @override
  void initState() {
    super.initState();

    _auth = AuthProvider();
    _favorites = FavoritesProvider();

    // Les favoris suivent l'utilisateur connecte : a la deconnexion, on
    // rebascule sur le stockage local du mode visiteur.
    _auth.addListener(_syncFavorites);
    _favorites.bind(_auth.uid);

    NotificationService.instance.initialize();
    NotificationService.instance.onOpenTarget = _handleNotificationTap;
  }

  void _syncFavorites() {
    _favorites.bind(_auth.uid);
  }

  void _handleNotificationTap(String type, String? targetId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null || targetId == null) return;

    switch (type) {
      case 'message':
        navigator.pushNamed(AppRoutes.chatDetail,
            arguments: ChatDetailArgs(conversationId: targetId));
        break;
      case 'alertMatch':
      case 'propertyApproved':
      case 'propertyRejected':
      case 'boostActivated':
        navigator.pushNamed(AppRoutes.propertyDetail,
            arguments: PropertyDetailArgs(propertyId: targetId));
        break;
      default:
        navigator.pushNamed(AppRoutes.notifications);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncFavorites);
    _auth.dispose();
    _favorites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _favorites),
        ChangeNotifierProvider(create: (_) => PropertyProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            navigatorObservers: [
              AnalyticsService.instance.navigatorObserver,
            ],
            initialRoute: AppRoutes.splash,
            onGenerateRoute: _onGenerateRoute,
            builder: (context, child) {
              // Plafonne l'agrandissement de police : au-dela de 1.3, les
              // cartes d'annonce debordent. On respecte le reglage systeme
              // jusqu'a ce seuil plutot que de l'ignorer.
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.3,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case AppRoutes.splash:
        page = const SplashScreen();
        break;
      case AppRoutes.onboarding:
        page = const OnboardingScreen();
        break;
      case AppRoutes.auth:
        page = AuthScreen(
          initialTab: (settings.arguments as AuthScreenArgs?)?.initialTab ?? 0,
        );
        break;
      case AppRoutes.home:
        page = HomeScreen(
          initialTab: (settings.arguments as int?) ?? 0,
        );
        break;
      case AppRoutes.map:
        page = const MapScreen();
        break;
      case AppRoutes.propertyList:
        page = PropertyListScreen(
          args: settings.arguments as PropertyListArgs?,
        );
        break;
      case AppRoutes.propertyDetail:
        page = PropertyDetailScreen(
          args: settings.arguments as PropertyDetailArgs,
        );
        break;
      case AppRoutes.chat:
        page = const ChatListScreen();
        break;
      case AppRoutes.chatDetail:
        page = ChatDetailScreen(args: settings.arguments as ChatDetailArgs);
        break;
      case AppRoutes.ownerDashboard:
        page = const OwnerDashboardScreen();
        break;
      case AppRoutes.publish:
        page = PublishPropertyScreen(
          existing: settings.arguments as Property?,
        );
        break;
      case AppRoutes.favorites:
        page = const FavoritesScreen();
        break;
      case AppRoutes.profile:
        page = const ProfileScreen();
        break;
      case AppRoutes.editProfile:
        page = const EditProfileScreen();
        break;
      case AppRoutes.alerts:
        page = const AlertsScreen();
        break;
      case AppRoutes.notifications:
        page = const NotificationsScreen();
        break;
      case AppRoutes.verification:
        page = const VerificationScreen();
        break;
      case AppRoutes.legal:
        page = LegalScreen(
          document: (settings.arguments as LegalDocument?) ??
              LegalDocument.terms,
        );
        break;
      default:
        page = const SplashScreen();
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
