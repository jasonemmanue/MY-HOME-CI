import 'package:flutter/material.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/property_list/property_list_screen.dart';
import 'screens/property_detail/property_detail_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_detail_screen.dart';
import 'screens/owner_dashboard/owner_dashboard_screen.dart';
import 'screens/publish_property/publish_property_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/profile/profile_screen.dart';

class MyHomeCIApp extends StatefulWidget {
  const MyHomeCIApp({super.key});

  static final GlobalKey<_MyHomeCIAppState> appKey =
      GlobalKey<_MyHomeCIAppState>();

  static void toggleTheme() {
    appKey.currentState?.toggleTheme();
  }

  static void setThemeMode(ThemeMode mode) {
    appKey.currentState?.setThemeMode(mode);
  }

  @override
  State<MyHomeCIApp> createState() => _MyHomeCIAppState();
}

class _MyHomeCIAppState extends State<MyHomeCIApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: MyHomeCIApp.appKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.onboarding: (_) => const OnboardingScreen(),
        AppRoutes.auth: (_) => const AuthScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.map: (_) => const MapScreen(),
        AppRoutes.propertyList: (_) => const PropertyListScreen(),
        AppRoutes.propertyDetail: (_) => const PropertyDetailScreen(),
        AppRoutes.chat: (_) => const ChatListScreen(),
        AppRoutes.chatDetail: (_) => const ChatDetailScreen(),
        AppRoutes.ownerDashboard: (_) => const OwnerDashboardScreen(),
        AppRoutes.publish: (_) => const PublishPropertyScreen(),
        AppRoutes.favorites: (_) => const FavoritesScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
      },
    );
  }
}
