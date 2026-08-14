import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// Preferences locales : theme et notifications.
///
/// Le theme est charge de maniere synchrone au demarrage (cf. [load] appele
/// avant `runApp`) : le lire apres coup ferait apparaitre l'application en
/// clair pendant une image avant de basculer en sombre.
class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _onboardingKey = 'onboarding_seen';
  static const _notificationsKey = 'notifications_enabled';

  ThemeMode _themeMode = ThemeMode.system;
  bool _onboardingSeen = false;
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  bool get onboardingSeen => _onboardingSeen;
  bool get notificationsEnabled => _notificationsEnabled;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final stored = prefs.getString(_themeKey);
    _themeMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _onboardingSeen = prefs.getBool(_onboardingKey) ?? false;
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> markOnboardingSeen() async {
    if (_onboardingSeen) return;
    _onboardingSeen = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Active ou coupe les notifications.
  ///
  /// Activer demande le consentement systeme : si l'utilisateur le refuse, le
  /// reglage revient a l'arret plutot que d'afficher un interrupteur allume
  /// qui ne produirait aucune notification.
  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final granted =
          await NotificationService.instance.requestPermissionAndRegister();
      _notificationsEnabled = granted;
    } else {
      _notificationsEnabled = false;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, _notificationsEnabled);
    return _notificationsEnabled;
  }
}
