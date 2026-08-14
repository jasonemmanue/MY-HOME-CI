import Flutter
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Clef Maps injectee au build : Codemagic l'expose via la variable
    // d'environnement MAPS_API_KEY_IOS, elle-meme ecrite dans Runner/Keys.plist
    // par le script de build. On evite ainsi de versionner la clef.
    //
    // Une clef Google ne porte qu'une seule restriction applicative a la fois :
    // celle d'iOS est distincte de celle d'Android, restreinte au bundle
    // com.myhomeci.app et au seul « Maps SDK for iOS ».
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty {
      GMSServices.provideAPIKey(key)
    } else {
      NSLog("⚠️ GMSApiKey absente d'Info.plist — la carte restera grise.")
    }

    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── Transmission manuelle du jeton APNs ──────────────────────────────────
  //
  // Info.plist fixe FirebaseAppDelegateProxyEnabled a false : le swizzling est
  // desactive, et rien n'est transmis automatiquement au SDK Firebase.
  //
  // Sans les deux methodes ci-dessous, la verification silencieuse de Phone
  // Auth n'aboutit jamais et l'OTP par SMS n'est tout simplement pas envoye
  // sur iOS — sans message d'erreur exploitable cote Dart. C'est l'une des
  // causes les plus courantes de « l'OTP marche sur Android mais pas sur iOS ».

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if DEBUG
      Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
    #else
      Auth.auth().setAPNSToken(deviceToken, type: .prod)
    #endif
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Les push de verification Phone Auth sont silencieux et ne doivent pas
    // remonter jusqu'a Flutter, sous peine d'afficher une notification vide.
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}
