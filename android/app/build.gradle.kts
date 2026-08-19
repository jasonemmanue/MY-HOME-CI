import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Doit venir apres les plugins Android/Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
}

// Signature de release : lue depuis android/key.properties, volontairement
// hors du depot (.gitignore). Voir android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) {
        // PowerShell prefixe volontiers ses fichiers d'un BOM UTF-8, que
        // Properties.load() agrege silencieusement a la premiere cle :
        // `storePassword` devient alors introuvable alors que le fichier
        // parait parfaitement correct a la lecture. On le retire avant chargement.
        load(keystorePropertiesFile.readText(Charsets.UTF_8).removePrefix("\uFEFF").reader())
    }
}

// Gradle ne charge automatiquement que gradle.properties : local.properties
// est lu a la main (par le plugin Android pour sdk.dir, par Flutter pour
// flutter.sdk). Sans cette lecture explicite, findProperty("MAPS_API_KEY")
// renvoie null et la carte se lance avec une clef vide — l'echec se voit
// seulement a l'execution, sous forme d'« Authorization failure ».
val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) load(f.readText(Charsets.UTF_8).removePrefix("﻿").reader())
}

android {
    namespace = "com.myhomeci.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications, qui utilise les API date/heure
        // de Java 8 sur des niveaux d'API anterieurs.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.myhomeci.app"
        // 23 est le plancher impose par firebase_auth ; le laisser suivre
        // flutter.minSdkVersion ferait echouer la fusion des manifestes.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Clef Google Maps injectee au build : elle ne doit pas etre en dur
        // dans le manifeste versionne.
        // Definir MAPS_API_KEY dans android/local.properties ou l'environnement.
        val mapsApiKey =
            (project.findProperty("MAPS_API_KEY") as String?)
                ?: localProperties.getProperty("MAPS_API_KEY")
                ?: System.getenv("MAPS_API_KEY")
                ?: ""
        if (mapsApiKey.isBlank()) {
            logger.warn(
                "\n⚠️  MAPS_API_KEY absente — la carte restera grise " +
                "(« Authorization failure » dans logcat).\n" +
                "   Ajoutez MAPS_API_KEY=... dans android/local.properties.\n"
            )
        }
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // Une propriete absente laisserait le champ a null et l'echec
                // ne surviendrait qu'a la tache signReleaseBundle — apres tout
                // le build — sous forme de NullPointerException sans message.
                // On echoue donc ici, en nommant la cle fautive.
                fun requis(cle: String): String =
                    keystoreProperties.getProperty(cle)
                        ?: throw GradleException(
                            "android/key.properties : propriete « $cle » absente ou vide. " +
                            "Les quatre cles attendues sont storePassword, keyPassword, " +
                            "keyAlias et storeFile (voir key.properties.example)."
                        )

                keyAlias = requis("keyAlias")
                keyPassword = requis("keyPassword")
                storePassword = requis("storePassword")

                val chemin = requis("storeFile")
                val fichier = file(chemin)
                if (!fichier.exists()) {
                    throw GradleException(
                        "Keystore introuvable : $chemin\n" +
                        "Verifiez storeFile dans android/key.properties. Le chemin doit " +
                        "utiliser des barres obliques (C:/Users/...), l'antislash etant " +
                        "un caractere d'echappement dans un fichier .properties."
                    )
                }
                storeFile = fichier
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Repli sur la cle de debogage pour ne pas bloquer un
                // `flutter run --release` local. Google Play REFUSE un artefact
                // signe ainsi : l'avertissement doit rester visible.
                logger.warn(
                    "\n⚠️  android/key.properties introuvable — le build release est " +
                    "signe avec la cle de DEBOGAGE.\n" +
                    "   Google Play rejettera cet AAB. Voir android/key.properties.example.\n"
                )
                signingConfig = signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Les tablettes font partie de la cible : on n'exclut aucune densite.
    bundle {
        language {
            // L'application est monolingue (francais) : decouper par langue
            // n'apporte rien et complique le telechargement.
            enableSplit = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
