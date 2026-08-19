/// Noms de routes.
///
/// Les arguments typés associés vivent avec l'écran qui les consomme
/// (`PropertyDetailArgs`, `ChatDetailArgs`, …) plutôt qu'ici : cela évite
/// qu'un changement de signature d'écran oblige à toucher ce fichier.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String otp = '/otp';
  static const String completeProfile = '/auth/complete-profile';
  static const String home = '/home';
  static const String map = '/map';
  static const String propertyList = '/property-list';
  static const String propertyDetail = '/property-detail';
  static const String chat = '/chat';
  static const String chatDetail = '/chat-detail';
  static const String ownerDashboard = '/owner-dashboard';
  static const String publish = '/publish';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String alerts = '/profile/alerts';
  static const String notifications = '/notifications';
  static const String verification = '/profile/verification';
  static const String legal = '/legal';
}
