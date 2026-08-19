/**
 * Attribue une fenetre de visibilite aux annonces publiees AVANT
 * l'introduction du champ `visibleUntil`.
 *
 * Pourquoi ce script existe
 * -------------------------
 * `onPropertyWritten` ouvre une fenetre de 30 jours et consomme une unite de
 * quota des qu'une annonce exposee se trouve sans fenetre valide. Une annonce
 * anterieure au deploiement n'en a aucune : sa premiere ecriture — meme une
 * simple moderation, meme un changement que le proprietaire n'a pas demande —
 * serait donc facturee comme une republication.
 *
 * Ce script pose la fenetre a l'avance, SANS toucher aux compteurs : ces
 * annonces ont ete publiees sous l'ancien regime, il n'y a rien a decompter.
 *
 * Prerequis
 * ---------
 *   Firebase Console > Parametres du projet > Comptes de service >
 *   "Generer une nouvelle cle privee" -> serviceAccountKey.json a cote de ce
 *   script (ignore par .gitignore).
 *
 * Usage
 * -----
 *   cd functions
 *   node backfill-visibility.js            # simulation, n'ecrit rien
 *   node backfill-visibility.js --apply    # applique
 *
 * Le script est idempotent : une annonce qui a deja une fenetre est ignoree,
 * le relancer ne prolonge donc la visibilite de personne.
 */

const admin = require("firebase-admin");

const VISIBILITY_DAYS = 30;
const EXPOSED_STATUSES = ["pending", "active", "rented"];

const appliquer = process.argv.includes("--apply");

try {
  admin.initializeApp({
    credential: admin.credential.cert(require("./serviceAccountKey.json")),
  });
} catch (e) {
  console.error(
    "\nCle de service introuvable ou invalide (serviceAccountKey.json).\n" +
    "Voir l'en-tete de ce fichier pour la procedure.\n"
  );
  process.exit(1);
}

const db = admin.firestore();

(async () => {
  const snap = await db.collection("properties").get();

  const aTraiter = snap.docs.filter((d) => {
    const v = d.data();
    return EXPOSED_STATUSES.includes(v.status) && !v.visibleUntil;
  });

  console.log(`\nAnnonces au total          : ${snap.size}`);
  console.log(`Exposees sans fenetre      : ${aTraiter.length}`);

  if (aTraiter.length === 0) {
    console.log("\nRien a faire.\n");
    process.exit(0);
  }

  const expiration = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + VISIBILITY_DAYS * 24 * 60 * 60 * 1000)
  );

  console.log(
    `Fenetre posee jusqu'au     : ` +
    `${expiration.toDate().toLocaleDateString("fr-FR")}\n`
  );

  aTraiter.forEach((d) => {
    const v = d.data();
    console.log(`  ${d.id}  ${String(v.status).padEnd(8)}  ${v.title || "(sans titre)"}`);
  });

  if (!appliquer) {
    console.log(
      `\nSimulation — rien n'a ete ecrit.\n` +
      `Relancez avec --apply pour appliquer.\n`
    );
    process.exit(0);
  }

  // Par lots de 400 : une ecriture par lot est plafonnee a 500 operations.
  for (let i = 0; i < aTraiter.length; i += 400) {
    const lot = db.batch();
    aTraiter.slice(i, i + 400).forEach((d) => {
      lot.update(d.ref, { visibleUntil: expiration });
    });
    await lot.commit();
  }

  console.log(`\n${aTraiter.length} annonce(s) mise(s) a jour.\n`);
  process.exit(0);
})().catch((e) => {
  console.error("\nEchec :", e.message, "\n");
  process.exit(1);
});
