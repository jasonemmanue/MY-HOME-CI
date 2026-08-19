# Creer un administrateur (sans deployer de Cloud Function)

Le back-office web verifie un **custom claim `admin`** sur le compte Firebase
(les regles Firestore aussi). Ce claim se pose cote serveur uniquement. Le
script `make-admin.js` permet de le poser **une seule fois en local**, sans
avoir a deployer `setAdminRole` / `bootstrapFirstAdmin`.

## Etapes

1. **Cle de service** (une fois) : Firebase Console → Parametres du projet →
   Comptes de service → *Generer une nouvelle cle privee*. Enregistre le
   fichier ici sous le nom `serviceAccountKey.json` (il est ignore par Git).

2. **Installer les dependances** (si pas deja fait) :
   ```bash
   cd functions
   npm install
   ```

3. **Creer / promouvoir l'admin** :
   ```bash
   node make-admin.js admin@myhomeci.ci MonMotDePasse123
   ```
   - Compte inexistant + mot de passe fourni → il est cree puis promu.
   - Compte deja existant → il est simplement promu (le mot de passe n'est pas
     modifie).

4. **Se connecter** au dashboard avec cet email + mot de passe. L'email joue le
   role d'identifiant. Rien d'autre a deployer.

> Si tu etais deja connecte au dashboard avant de lancer le script,
> deconnecte-toi puis reconnecte-toi : le jeton doit etre rafraichi pour
> embarquer le nouveau claim.

## Securite

- `serviceAccountKey.json` donne un acces total au projet : ne le versionne
  jamais, ne le partage pas. Il est deja dans `.gitignore`.
- Pour retirer les droits d'un compte : relance en remplacant la valeur du
  claim (ou via la fonction `setAdminRole` si tu deploies un jour les
  fonctions).
