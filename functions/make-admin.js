/**
 * Cree (ou promeut) un administrateur du back-office My Home CI, en local,
 * SANS avoir a deployer de Cloud Function.
 *
 * Le dashboard admin et les regles Firestore verifient un custom claim
 * { admin: true } sur le compte Firebase. Ce claim ne se pose que cote
 * serveur : ce script le fait une seule fois avec une cle de service.
 *
 * Prerequis (une fois) :
 *   Firebase Console > Parametres du projet > Comptes de service >
 *   "Generer une nouvelle cle privee" -> enregistrer le fichier a cote de ce
 *   script sous le nom serviceAccountKey.json (ignore par .gitignore).
 *
 * Usage :
 *   cd functions
 *   npm install                                  # firebase-admin deja present
 *   node make-admin.js <email> [motDePasse]
 *
 * Exemple :
 *   node make-admin.js admin@myhomeci.ci MonMotDePasse123
 *
 * - Si le compte existe deja, il est simplement promu administrateur.
 * - S'il n'existe pas et qu'un mot de passe est fourni, il est cree puis promu.
 * - Pose le claim { admin: true } et met users/{uid}.role = "admin".
 *
 * Ensuite : connexion au dashboard avec cet email + mot de passe. Rien d'autre
 * a deployer. (L'email joue le role de "username".)
 */
const path = require("path");
const admin = require("firebase-admin");

const keyPath = path.join(__dirname, "serviceAccountKey.json");
let serviceAccount;
try {
  serviceAccount = require(keyPath);
} catch (e) {
  console.error("Cle de service introuvable :", keyPath);
  console.error(
    "  Genere-la dans Firebase Console > Parametres du projet > Comptes de " +
      "service, puis enregistre-la sous ce nom a cote du script."
  );
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

async function main() {
  const email = process.argv[2];
  const password = process.argv[3];

  // Aide au diagnostic : le compte est cree dans CE projet. Il doit
  // correspondre a NEXT_PUBLIC_FIREBASE_PROJECT_ID cote admin, sinon la
  // connexion echouera avec « email ou mot de passe incorrect ».
  console.log("Projet Firebase vise :", serviceAccount.project_id);

  if (!email) {
    console.error("Usage : node make-admin.js <email> [motDePasse]");
    process.exit(1);
  }

  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
    console.log("Compte existant :", user.uid);
    // Idempotent : si un mot de passe est fourni, on le (re)definit. Ainsi,
    // relancer le script garantit que le mot de passe correspond, meme si le
    // compte existait deja avec un mot de passe inconnu.
    if (password) {
      await admin.auth().updateUser(user.uid, { password });
      console.log("Mot de passe reinitialise.");
    }
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    if (!password) {
      console.error(
        "Ce compte n'existe pas. Fournis un mot de passe pour le creer :\n" +
          "  node make-admin.js " +
          email +
          " <motDePasse>"
      );
      process.exit(1);
    }
    user = await admin.auth().createUser({ email, password });
    console.log("Compte cree :", user.uid);
  }

  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  await admin
    .firestore()
    .doc("users/" + user.uid)
    .set({ role: "admin", name: "Administrateur" }, { merge: true });

  console.log("Administrateur pret :", email);
  console.log("  Connecte-toi au dashboard avec cet email + mot de passe.");
  console.log(
    "  Si tu etais deja connecte, deconnecte/reconnecte pour rafraichir le jeton."
  );
  process.exit(0);
}

main().catch((e) => {
  console.error("Echec :", e.message || e);
  process.exit(1);
});
