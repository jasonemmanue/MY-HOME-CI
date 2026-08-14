# ── ProGuard / R8 ──────────────────────────────────────────────────────────
# La minification est active en release. Sans ces regles, R8 supprime des
# classes atteintes uniquement par reflexion et l'application plante au
# demarrage — en release seulement, donc jamais pendant le developpement.

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase : les modeles Firestore sont instancies par reflexion.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics : sans ces lignes, les traces sont illisibles.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Google Maps
-keep class com.google.android.gms.maps.** { *; }

# Sign in with Apple / navigateur personnalise
-keep class androidx.browser.** { *; }

# Desugaring
-dontwarn java.lang.invoke.**
-dontwarn **$$serializer
