# Publication d'une version release

Ce document couvre la signature, la construction et le deploiement de
l'application Android sur Google Play.

> **Regle absolue** : le keystore et ses mots de passe ne sont JAMAIS versionnes.
> Perdre le keystore interdit definitivement toute mise a jour de l'application
> sur Google Play — il faudrait republier sous un nouveau nom de package, et les
> utilisateurs deja installes ne recevraient plus rien. Sauvegardez-le hors du
> poste de developpement.

---

## 1. Preparation (une seule fois)

### 1.1 Generer le keystore

```bash
keytool -genkeypair -v -keystore C:/cles/my-home-ci.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias my-home-ci
```

`keytool` demande interactivement le mot de passe puis l'identite (nom,
organisation, ville, pays : `CI`). La validite de 10000 jours est le minimum
exige par Google Play pour une cle de signature.

Conservez le fichier `.jks` **et** ses mots de passe dans un gestionnaire de
secrets. Une copie hors ligne est recommandee.

### 1.2 Declarer le keystore au build

Copier le modele et renseigner les valeurs reelles :

```bash
cp android/key.properties.example android/key.properties
```

```properties
storePassword=...
keyPassword=...
keyAlias=my-home-ci
storeFile=C:/cles/my-home-ci.jks
```

`storeFile` doit utiliser des **barres obliques**. L'antislash est un caractere
d'echappement dans un fichier `.properties` : `C:\cles\my-home-ci.jks` serait
lu comme `C:cles`, et le build echouerait sur un keystore introuvable.

`keyPassword` n'est **pas** forcement different de `storePassword`. A la
generation, `keytool` propose « appuyez sur Entree s'il s'agit du mot de passe
du fichier de cles » : si vous avez valide par Entree, la clef a herite du mot
de passe du magasin et les deux lignes doivent porter la meme valeur. Y mettre
un mot de passe distinct fait echouer le build sur `Cannot recover key`, mais
seulement a la toute derniere tache — apres une compilation complete.

Pour verifier quel mot de passe ouvre la clef sans rien modifier :

```bash
keytool -certreq -alias my-home-ci -keystore C:/cles/my-home-ci.jks
```

`keytool` demande d'abord le mot de passe du magasin, puis celui de la clef.
Une demande de certificat s'affiche si les deux sont bons ; `Cannot recover
key` designe le second.

Le fichier est couvert par `.gitignore` (`android/key.properties`, `*.jks`).
Verifiez-le avant tout commit :

```bash
git check-ignore -v android/key.properties
```

Sans `android/key.properties`, un build release reste possible mais il est
signe avec la cle de **debogage** : Gradle affiche un avertissement, et Google
Play rejettera l'artefact.

### 1.3 Renseigner la clef Google Maps

Dans `android/local.properties` (non versionne) :

```properties
MAPS_API_KEY=AIza...
```

Gradle ne charge automatiquement que `gradle.properties` ; `local.properties`
est lu explicitement par `android/app/build.gradle.kts`, qui injecte la valeur
dans le manifeste via le placeholder `${MAPS_API_KEY}`. Si la clef manque, le
build affiche un avertissement et la carte reste grise a l'execution
(`Authorization failure` dans logcat) — l'application se lance normalement par
ailleurs, ce qui rend l'oubli facile a manquer.

### 1.4 Declarer l'empreinte SHA-1 de release

C'est l'etape la plus souvent oubliee : la cle de release a une empreinte
**differente** de la cle de debogage. Sans cette declaration, la connexion
Google et la carte fonctionnent en debug puis echouent en production.

Relever les empreintes :

```bash
keytool -list -v -keystore C:/cles/my-home-ci.jks -alias my-home-ci
```

Puis les enregistrer aux deux endroits :

| Service | Ou | Effet si oubli |
|---|---|---|
| Firebase Console | Parametres du projet > Vos applications > Ajouter une empreinte, puis **retelecharger `google-services.json`** dans `android/app/` | Connexion Google en echec |
| Google Cloud Console | APIs & Services > Identifiants > clef Maps > Restriction Android : `SHA1;com.myhomeci.app` | Carte grise en release |

Si Google Play Signing est active (recommande), Play **resigne** l'application
avec sa propre cle. L'empreinte a declarer est alors aussi celle affichee dans
Play Console > Configuration > Integrite de l'application, en plus de la votre.

---

## 2. Construire

```bash
flutter build appbundle --release
```

Sortie : `build/app/outputs/bundle/release/app-release.aab` — le format attendu
par Google Play.

Pour une installation directe sur un appareil (test, distribution hors Play) :

```bash
flutter build apk --release
```

Sortie : `build/app/outputs/flutter-apk/app-release.apk`.

## 3. Verifier avant d'envoyer

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

L'empreinte SHA-1 affichee doit correspondre a celle du keystore, et le
proprietaire ne doit pas etre `CN=Android Debug`.

```bash
grep -A2 geo.API_KEY build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
```

`android:value=""` signale une clef Maps absente.

Installer enfin l'APK release sur un appareil reel et verifier les chemins qui
dependent de la signature ou de la minification, car ils ne cassent qu'en
release : affichage de la carte, connexion Google, notifications push, et
absence de plantage au demarrage (une regle ProGuard manquante ne se manifeste
qu'ici — voir `android/app/proguard-rules.pro`).

## 4. Deployer sur Google Play

1. Incrementer `version:` dans `pubspec.yaml` (`1.0.0+1` -> `1.0.1+2`). Le
   `+N` est le `versionCode` : Play refuse un envoi dont le `versionCode` n'est
   pas strictement superieur au precedent.
2. Play Console > Production > Creer une version > televerser l'`.aab`.
3. Renseigner les notes de version, puis soumettre a l'examen.

Passer d'abord par un canal de test interne evite de decouvrir une regression
de signature ou de minification directement en production.

## 5. En cas de probleme

| Symptome | Cause probable |
|---|---|
| `key.properties : propriete « X » absente` | Cle manquante dans `android/key.properties`, ou BOM UTF-8 ajoute par PowerShell |
| `Keystore introuvable` | `storeFile` utilise des antislashs |
| `Cannot recover key` a la tache `signReleaseBundle` | `keyPassword` incorrect. Le magasin s'ouvre (donc `storePassword` est bon), mais pas la clef — voir 1.2 |
| Play rejette l'AAB (« signe en debug ») | `android/key.properties` absent au moment du build |
| Carte grise en release, OK en debug | SHA-1 de release non declare sur la clef Maps |
| Connexion Google en echec en release | SHA-1 de release absent de Firebase, ou `google-services.json` non retelecharge |
| Plantage au demarrage en release seulement | Regle ProGuard manquante ; lancer `flutter build apk --release` puis lire logcat |
