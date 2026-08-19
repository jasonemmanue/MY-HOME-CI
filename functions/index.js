// ══════════════════════════════════════════════════════════════════════════
//  MY HOME CI — Cloud Functions
// ──────────────────────────────────────────────────────────────────────────
//  Tout ce qui ne peut pas etre confie au client vit ici :
//   • l'argent (initier un paiement, constater son issue, accorder un service)
//   • les privileges (role, badge verifie, statut Pro)
//   • la suppression de compte, qui doit balayer plusieurs collections
//   • les notifications, qui exigent la liste des jetons d'autrui
//
//  Les regles Firestore interdisent ces ecritures au client ; l'Admin SDK
//  utilise ici les contourne legitimement.
// ══════════════════════════════════════════════════════════════════════════

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

const geniuspay = require("./geniuspay");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "us-central1", maxInstances: 20 });

// ── Tarification ──────────────────────────────────────────────────────────
// Les montants vivent cote serveur, jamais cote client : un tarif envoye par
// l'application serait modifiable, et l'utilisateur fixerait son propre prix.

const PRODUCTS = {
  pro: {
    amount: 15000,
    label: "Pack Pro Proprietaire",
    description: "Annonces illimitees, badge verifie et statistiques detaillees pendant 30 jours",
    durationDays: 30,
  },
  boost: {
    amount: 5000,
    label: "Mise en avant d'une annonce",
    description: "Votre annonce apparait en tete des resultats pendant 7 jours",
    durationDays: 7,
  },
  ad_video: {
    amount: 1000,
    label: "Publicite video",
    description: "Votre video est diffusee dans l'application pendant 3 jours",
    durationDays: 3,
  },
};

const OPERATORS = ["wave", "orange_money", "mtn_money", "moov_money"];

// ── Quota de publication ──────────────────────────────────────────────────
// Chaque proprietaire dispose de quatre operations gratuites — une operation
// etant une publication OU une mise a jour d'annonce. Au-dela, chaque geste
// coute 5 % du prix de l'annonce, avec un plancher : une annonce affichee a
// 0 franc, ou a un prix symbolique, ne doit pas rendre la publication
// gratuite de fait.
const FREE_PUBLICATION_OPERATIONS = 4;
const PUBLICATION_FEE_RATE = 0.05;
const PUBLICATION_FEE_MINIMUM = 500;

// Une annonce reste visible 30 jours. L'unite facturee n'est donc pas le
// geste mais la FENETRE : une fois ouverte — gratuitement au titre du quota,
// ou apres paiement — le proprietaire modifie son annonce autant qu'il veut
// jusqu'a son terme. Seules la publication initiale et la remise en
// visibilite d'une annonce expiree consomment une unite.
const VISIBILITY_DAYS = 30;

/** Statuts sous lesquels une annonce est exposee au public. */
const EXPOSED_STATUSES = ["pending", "active", "rented"];

/// Champs dont la modification constitue une « mise a jour » facturable.
/// `views`, `favoritesCount`, `boostedUntil` et `status` en sont exclus : les
/// deux premiers sont incrementes par n'importe quel visiteur, les deux
/// autres par un paiement ou par la moderation — aucun n'est un geste du
/// proprietaire sur le contenu de son annonce.
const BILLABLE_PROPERTY_FIELDS = [
  "title", "description", "price", "type", "address", "quarter", "city",
  "latitude", "longitude", "surface", "rooms", "bathrooms", "isFurnished",
  "equipment", "images",
];

/** Montant du au-dela du quota, en francs CFA. */
function publicationFee(price) {
  const pourcentage = Math.ceil(Number(price || 0) * PUBLICATION_FEE_RATE);
  return Math.max(pourcentage, PUBLICATION_FEE_MINIMUM);
}

/**
 * Etat du quota d'un proprietaire.
 *
 * Le document `publicationQuotas/{uid}` n'est jamais ecrit par le client :
 * les regles le lui interdisent, sans quoi il suffirait de remettre son
 * compteur a zero pour publier gratuitement.
 */
async function readQuota(uid) {
  const [quotaSnap, userSnap] = await Promise.all([
    db.collection("publicationQuotas").doc(uid).get(),
    db.collection("users").doc(uid).get(),
  ]);

  const q = quotaSnap.exists ? quotaSnap.data() : {};
  const u = userSnap.exists ? userSnap.data() : {};

  // `isPro` seul ne suffit pas : le pack expire, et le drapeau n'est remis a
  // false par aucun processus. On verifie donc la date.
  const proUntil = u.proUntil?.toDate?.() || null;
  const isPro = u.isPro === true && (!proUntil || proUntil > new Date());

  const freeUsed = Number(q.freeUsed || 0);
  const paidCredits = Number(q.paidCredits || 0);

  return {
    isPro,
    freeUsed,
    freeRemaining: Math.max(0, FREE_PUBLICATION_OPERATIONS - freeUsed),
    paidCredits,
  };
}

/** Duree de validite d'un lien de paiement envoye par email. */
const PAYMENT_LINK_TTL_HOURS = 24;

const WEB_PAY_BASE_URL =
  process.env.WEB_PAY_BASE_URL || "https://admin.myhomeci.ci/pay";

const GENIUSPAY_SECRETS = [
  "GENIUSPAY_API_KEY",
  "GENIUSPAY_SECRET_KEY",
  "GENIUSPAY_WEBHOOK_SECRET",
];
const MAIL_SECRETS = ["GMAIL_SENDER_EMAIL", "GMAIL_APP_PASSWORD"];

// ── Utilitaires ───────────────────────────────────────────────────────────

function generateToken() {
  return require("crypto").randomBytes(16).toString("hex");
}

function generateReference(product, uid) {
  const suffix = require("crypto").randomBytes(4).toString("hex");
  return `MHCI-${product.toUpperCase()}-${uid.slice(0, 6)}-${suffix}`;
}

function requireAuth(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Connexion requise.");
  }
  return request.auth.uid;
}

function requireAdmin(request) {
  const uid = requireAuth(request);
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Reserve aux administrateurs.");
  }
  return uid;
}

function normalizePhone(input) {
  let p = String(input || "").replace(/[\s\-().]/g, "");
  if (p.startsWith("+")) return p;
  if (p.startsWith("00")) return `+${p.slice(2)}`;
  if (p.startsWith("225")) return `+${p}`;
  return `+225${p}`;
}

function webhookUrl() {
  const project = process.env.GCLOUD_PROJECT || "my-home-ci";
  return `https://us-central1-${project}.cloudfunctions.net/geniusPayWebhook`;
}

// ══════════════════════════════════════════════════════════════════════════
//  PAIEMENTS
// ══════════════════════════════════════════════════════════════════════════

/**
 * Initie un paiement Mobile Money (parcours Android / Web).
 *
 * Renvoie l'URL de finalisation GeniusPay. Le service n'est PAS accorde ici :
 * il l'est a la confirmation du webhook, apres re-verification aupres de
 * l'API. Accorder des l'initiation permettrait d'obtenir le Pack Pro en
 * abandonnant le paiement.
 */
exports.initiatePayment = onCall(
  { secrets: GENIUSPAY_SECRETS },
  async (request) => {
    const uid = requireAuth(request);
    const { product, operator, phone, targetId } = request.data || {};

    const config = product === "publication"
      ? { label: "Publication d'annonce", durationDays: 0 }
      : PRODUCTS[product];
    if (!config) {
      throw new HttpsError("invalid-argument", "Service inconnu.");
    }
    if (!OPERATORS.includes(operator)) {
      throw new HttpsError("invalid-argument", "Operateur non pris en charge.");
    }
    if (!phone) {
      throw new HttpsError("invalid-argument", "Numero de telephone requis.");
    }
    // Le boost porte sur une annonce precise : sans cible, on ne saurait pas
    // quoi activer une fois le paiement confirme.
    if (product === "boost" && !targetId) {
      throw new HttpsError("invalid-argument", "Annonce a mettre en avant non precisee.");
    }
    if (product === "ad_video" && !targetId) {
      throw new HttpsError("invalid-argument", "Publicite a diffuser non precisee.");
    }

    // Le Pack Pro couvre la diffusion : laisser passer le paiement
    // encaisserait 1000 F pour un service deja du.
    if (product === "ad_video") {
      const snap = await db.collection("advertisements").doc(targetId).get();
      if (!snap.exists || snap.data().ownerId !== uid) {
        throw new HttpsError("permission-denied", "Cette publicite ne vous appartient pas.");
      }
      const { isPro } = await readQuota(uid);
      if (isPro) {
        throw new HttpsError(
          "failed-precondition",
          "Votre Pack Pro couvre deja la diffusion : aucun paiement n'est requis.",
        );
      }
    }

    // Verifie que l'annonce appartient bien au payeur.
    if (product === "boost") {
      const snap = await db.collection("properties").doc(targetId).get();
      if (!snap.exists || snap.data().ownerId !== uid) {
        throw new HttpsError("permission-denied", "Cette annonce ne vous appartient pas.");
      }
    }

    // Le montant d'une publication depend du prix de l'annonce. Il est lu
    // dans Firestore, jamais recu du client : un tarif transmis par
    // l'application permettrait a l'utilisateur de fixer ce qu'il paie.
    let amount = config.amount;
    if (product === "publication") {
      if (!targetId) {
        throw new HttpsError("invalid-argument", "Annonce a publier non precisee.");
      }
      const snap = await db.collection("properties").doc(targetId).get();
      if (!snap.exists || snap.data().ownerId !== uid) {
        throw new HttpsError("permission-denied", "Cette annonce ne vous appartient pas.");
      }
      const quota = await readQuota(uid);
      if (quota.isPro || quota.freeRemaining > 0 || quota.paidCredits > 0) {
        throw new HttpsError(
          "failed-precondition",
          "Cette operation est deja couverte : aucun paiement n'est requis.",
        );
      }
      amount = publicationFee(snap.data().price);
    }

    const reference = generateReference(product, uid);
    const contactSnap = await db
      .collection("users").doc(uid)
      .collection("private").doc("contact").get();
    const email = contactSnap.exists ? contactSnap.data().email : null;

    // Le document est cree AVANT l'appel a GeniusPay : si la passerelle
    // repond puis que l'ecriture echoue, on aurait un paiement encaisse sans
    // trace. L'inverse — une trace sans paiement — reste rattrapable.
    await db.collection("transactions").doc(reference).set({
      reference,
      uid,
      product,
      targetId: targetId || null,
      amount,
      currency: "XOF",
      operator,
      phone: normalizePhone(phone),
      status: "pending",
      channel: "app",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const result = await geniuspay.createPayment({
        reference,
        amount,
        paymentMethod: operator,
        description: config.label,
        customerEmail: email,
        customerPhone: normalizePhone(phone),
        metadata: { uid, product, targetId: targetId || "" },
        callbackUrl: webhookUrl(),
      });

      await db.collection("transactions").doc(reference).update({
        status: "initiated",
        paymentUrl: result.paymentUrl,
        gatewayTransactionId: result.transactionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        reference,
        paymentUrl: result.paymentUrl,
      };
    } catch (e) {
      console.error("initiatePayment :", e.message);
      await db.collection("transactions").doc(reference).update({
        status: "failed",
        error: e.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new HttpsError("unavailable", e.message);
    }
  }
);

/**
 * Webhook GeniusPay.
 *
 * Deux verifications avant d'accorder quoi que ce soit : la signature HMAC,
 * puis une lecture directe de l'API. Un webhook est une requete HTTP publique
 * — s'y fier seul revient a laisser n'importe qui declarer un paiement reussi.
 */
exports.geniusPayWebhook = onRequest(
  { secrets: GENIUSPAY_SECRETS, cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Methode non autorisee");
      return;
    }

    const rawBody = req.rawBody ? req.rawBody.toString("utf8") : JSON.stringify(req.body);
    const signature =
      req.headers["x-geniuspay-signature"] ||
      req.headers["x-signature"] ||
      req.headers["x-webhook-signature"];

    if (!geniuspay.verifyWebhookSignature(rawBody, signature)) {
      console.warn("Webhook GeniusPay : signature invalide.");
      res.status(401).send("Signature invalide");
      return;
    }

    const payload = req.body?.data || req.body || {};
    const reference =
      payload.metadata?.internal_reference || payload.reference || payload.transaction_id;

    if (!reference) {
      console.warn("Webhook GeniusPay : reference absente.", JSON.stringify(req.body));
      // 200 volontaire : renvoyer une erreur ferait rejouer indefiniment un
      // evenement que l'on ne saura de toute facon pas traiter.
      res.status(200).send("Reference absente, ignore");
      return;
    }

    try {
      const verified = await geniuspay.checkPayment(reference);
      await applyTransactionOutcome(reference, verified.status);
      res.status(200).send("OK");
    } catch (e) {
      console.error("geniusPayWebhook :", e.message);
      res.status(500).send("Erreur interne");
    }
  }
);

/**
 * Applique l'issue d'un paiement : met a jour la transaction et, en cas de
 * succes, accorde le service.
 *
 * Idempotent : un webhook rejoue ne doit pas prolonger deux fois un abonnement.
 * La transaction Firestore verrouille le document et sort si l'etat final est
 * deja pose.
 */
async function applyTransactionOutcome(reference, gatewayStatus) {
  const statusMap = {
    completed: "succeeded",
    success: "succeeded",
    successful: "succeeded",
    paid: "succeeded",
    failed: "failed",
    cancelled: "cancelled",
    canceled: "cancelled",
    pending: "pending",
  };
  const status = statusMap[gatewayStatus] || "pending";

  const ref = db.collection("transactions").doc(reference);

  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      console.warn(`Transaction inconnue : ${reference}`);
      return null;
    }
    const data = snap.data();

    if (["succeeded", "failed", "cancelled"].includes(data.status)) {
      console.log(`Transaction ${reference} deja finalisee (${data.status}).`);
      return null;
    }

    tx.update(ref, {
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(status === "succeeded"
        ? { paidAt: admin.firestore.FieldValue.serverTimestamp() }
        : {}),
    });

    return status === "succeeded" ? data : null;
  });

  if (!outcome) return;

  await grantProduct(outcome);
}

/** Accorde le service paye. Appele uniquement depuis un contexte confirme. */
async function grantProduct({ uid, product, targetId, reference }) {
  // Le credit de publication ne figure pas dans PRODUCTS : son montant est
  // calcule, pas catalogue.
  if (product === "publication") {
    await db.collection("publicationQuotas").doc(uid).set({
      paidCredits: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await notifyUser(uid, {
      type: "publicationCredit",
      title: "Paiement confirme",
      body: "Vous pouvez publier ou mettre a jour votre annonce.",
      targetId,
    });
    console.log(`Credit de publication accorde a ${uid} (transaction ${reference}).`);
    return;
  }

  const config = PRODUCTS[product];
  if (!config) return;

  const until = new Date(Date.now() + config.durationDays * 24 * 60 * 60 * 1000);

  if (product === "pro") {
    await db.collection("users").doc(uid).update({
      isPro: true,
      proUntil: admin.firestore.Timestamp.fromDate(until),
    });
    await notifyUser(uid, {
      type: "proActivated",
      title: "Pack Pro active",
      body: `Votre Pack Pro est actif jusqu'au ${until.toLocaleDateString("fr-FR")}.`,
    });
  }

  if (product === "ad_video" && targetId) {
    await db.collection("advertisements").doc(targetId).update({
      status: "active",
      visibleUntil: admin.firestore.Timestamp.fromDate(until),
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await notifyUser(uid, {
      type: "adActivated",
      title: "Publicite en ligne",
      body: `Votre video est diffusee pendant ${config.durationDays} jours.`,
      targetId,
    });
  }

  if (product === "boost" && targetId) {
    await db.collection("properties").doc(targetId).update({
      boostedUntil: admin.firestore.Timestamp.fromDate(until),
    });
    await notifyUser(uid, {
      type: "boostActivated",
      title: "Annonce mise en avant",
      body: "Votre annonce apparait desormais en tete des resultats.",
      targetId,
    });
  }

  console.log(`Service ${product} accorde a ${uid} (transaction ${reference}).`);
}

// ══════════════════════════════════════════════════════════════════════════
//  PARCOURS iOS — activation par email
// ══════════════════════════════════════════════════════════════════════════
//  La regle App Store 3.1.1 interdit d'encaisser un service numerique hors
//  achat in-app, et interdit meme d'orienter l'utilisateur vers un paiement
//  externe depuis l'application.
//
//  Le contournement retenu est le modele « compte » : l'application iOS ne
//  montre ni tarif, ni operateur, ni bouton de paiement. Elle demande
//  uniquement l'envoi d'un email. Le montant est calcule ici, n'apparait que
//  dans le message et sur la page web, et le paiement se deroule entierement
//  hors de l'application.
// ══════════════════════════════════════════════════════════════════════════

function paymentEmailHtml({ token, config, firstName }) {
  const url = `${WEB_PAY_BASE_URL}/${token}`;
  const greeting = firstName ? `Bonjour ${firstName},` : "Bonjour,";

  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>My Home CI — Activation</title></head>
<body style="margin:0;padding:0;background:#f4f6f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1a1a18;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f5;padding:32px 16px;">
<tr><td align="center">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.05);">
<tr><td style="background:#2E7D5B;padding:32px;text-align:center;">
<div style="color:#fff;font-size:24px;font-weight:700;letter-spacing:-.5px;">My Home CI</div>
<div style="color:#c8e6d5;font-size:13px;margin-top:4px;">Activation de votre service</div>
</td></tr>
<tr><td style="padding:32px;">
<p style="margin:0 0 16px;font-size:16px;line-height:1.6;">${greeting}</p>
<p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#4a4a45;">
Pour finaliser l'activation de <strong>${config.label}</strong>, cliquez sur le bouton ci-dessous.
</p>
<p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#4a4a45;">${config.description}.</p>
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px auto;">
<tr><td align="center" style="background:#F5A623;border-radius:8px;">
<a href="${url}" style="display:inline-block;padding:14px 32px;color:#fff;font-size:15px;font-weight:600;text-decoration:none;">Finaliser l'activation →</a>
</td></tr></table>
<p style="margin:24px 0 0;font-size:13px;line-height:1.6;color:#8a877e;text-align:center;">
Ce lien est valable ${PAYMENT_LINK_TTL_HOURS} heures.<br>
Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br>
<a href="${url}" style="color:#2E7D5B;word-break:break-all;">${url}</a>
</p>
</td></tr>
<tr><td style="background:#fafaf8;padding:20px 32px;border-top:1px solid #e6e4de;text-align:center;">
<p style="margin:0;font-size:12px;color:#8a877e;line-height:1.5;">
My Home CI — Mise en relation locative en Cote d'Ivoire<br>
Si vous n'etes pas a l'origine de cette demande, ignorez ce message.
</p>
</td></tr>
</table></td></tr></table></body></html>`;
}

async function sendPaymentLinkEmail({ email, token, config, firstName }) {
  const sender = process.env.GMAIL_SENDER_EMAIL;
  const password = process.env.GMAIL_APP_PASSWORD;
  if (!sender || !password) {
    throw new Error("Service email non configure.");
  }

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user: sender, pass: password },
  });

  await transporter.sendMail({
    from: `"My Home CI" <${sender}>`,
    to: email,
    subject: "My Home CI — Finalisez l'activation de votre service",
    html: paymentEmailHtml({ token, config, firstName }),
    text:
      `Bonjour,\n\nPour finaliser l'activation de ${config.label}, ouvrez ce lien :\n` +
      `${WEB_PAY_BASE_URL}/${token}\n\nCe lien est valable ${PAYMENT_LINK_TTL_HOURS} heures.\n\nMy Home CI`,
  });
}

/** Appelee par l'application iOS. Cree un jeton et envoie l'email. */
exports.sendActivationEmail = onCall(
  { secrets: MAIL_SECRETS },
  async (request) => {
    const uid = requireAuth(request);
    const { product, email, targetId } = request.data || {};

    const config = PRODUCTS[product];
    if (!config) {
      throw new HttpsError("invalid-argument", "Service inconnu.");
    }
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "Adresse email invalide.");
    }
    if (product === "boost") {
      if (!targetId) {
        throw new HttpsError("invalid-argument", "Annonce non precisee.");
      }
      const snap = await db.collection("properties").doc(targetId).get();
      if (!snap.exists || snap.data().ownerId !== uid) {
        throw new HttpsError("permission-denied", "Cette annonce ne vous appartient pas.");
      }
    }

    let firstName = "";
    try {
      const userSnap = await db.collection("users").doc(uid).get();
      firstName = (userSnap.data()?.name || "").split(" ")[0];
    } catch (_) {
      /* personnalisation facultative */
    }

    const token = generateToken();
    const expiresAt = new Date(Date.now() + PAYMENT_LINK_TTL_HOURS * 3600 * 1000);

    await db.collection("webPayments").doc(token).set({
      token,
      uid,
      product,
      targetId: targetId || null,
      amount: config.amount,
      label: config.label,
      description: config.description,
      email,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    try {
      await sendPaymentLinkEmail({ email, token, config, firstName });
    } catch (e) {
      console.error("sendActivationEmail :", e.message);
      // Le document reste : le lien demeure utilisable si l'utilisateur le
      // recoit par un autre canal ou si l'on relance l'envoi.
      throw new HttpsError("internal", "Impossible d'envoyer l'email. Reessayez.");
    }

    return { success: true, token, expiresAt: expiresAt.toISOString() };
  }
);

/**
 * Appelee par la page web /pay/{token}.
 *
 * Pas d'authentification Firebase : le jeton (128 bits, aleatoire, lie a un
 * document precis et expirant sous 24 h) fait office de cle porteuse. Exiger
 * une connexion obligerait l'utilisateur a se reconnecter sur un navigateur
 * de bureau, ce qui ferait chuter la conversion sans gain de securite reel —
 * le jeton n'ouvre que le paiement d'un service deja choisi.
 */
exports.initiatePaymentFromWeb = onRequest(
  { secrets: GENIUSPAY_SECRETS, cors: true },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ success: false, error: "Methode non autorisee" });
      return;
    }

    try {
      const { token, phone, operator } = req.body || {};
      if (!token || !phone || !OPERATORS.includes(operator)) {
        res.status(400).json({ success: false, error: "Parametres invalides" });
        return;
      }

      const ref = db.collection("webPayments").doc(token);
      const snap = await ref.get();
      if (!snap.exists) {
        res.status(404).json({ success: false, error: "Lien invalide" });
        return;
      }

      const data = snap.data();
      if (data.expiresAt.toDate() < new Date()) {
        await ref.update({ status: "expired" });
        res.status(410).json({ success: false, error: "Ce lien a expire" });
        return;
      }
      if (data.status === "succeeded") {
        res.status(409).json({ success: false, error: "Ce service est deja active" });
        return;
      }

      const config = PRODUCTS[data.product];
      const reference = generateReference(data.product, data.uid);

      await db.collection("transactions").doc(reference).set({
        reference,
        uid: data.uid,
        product: data.product,
        targetId: data.targetId,
        amount: config.amount,
        currency: "XOF",
        operator,
        phone: normalizePhone(phone),
        status: "pending",
        channel: "web",
        webToken: token,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const result = await geniuspay.createPayment({
        reference,
        amount: config.amount,
        paymentMethod: operator,
        description: config.label,
        customerEmail: data.email,
        customerPhone: normalizePhone(phone),
        metadata: { uid: data.uid, product: data.product, webToken: token },
        callbackUrl: webhookUrl(),
      });

      await db.collection("transactions").doc(reference).update({
        status: "initiated",
        paymentUrl: result.paymentUrl,
        gatewayTransactionId: result.transactionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await ref.update({ status: "initiated", reference });

      res.status(200).json({
        success: true,
        reference,
        checkoutUrl: result.paymentUrl,
      });
    } catch (e) {
      console.error("initiatePaymentFromWeb :", e.message);
      res.status(500).json({ success: false, error: e.message });
    }
  }
);

/** Lecture publique de l'etat d'un lien de paiement, pour la page web. */
exports.getWebPaymentStatus = onRequest({ cors: true }, async (req, res) => {
  const token = req.query.token || req.body?.token;
  if (!token) {
    res.status(400).json({ success: false, error: "Jeton manquant" });
    return;
  }

  const snap = await db.collection("webPayments").doc(String(token)).get();
  if (!snap.exists) {
    res.status(404).json({ success: false, error: "Lien invalide" });
    return;
  }

  const d = snap.data();
  const expired = d.expiresAt.toDate() < new Date();

  // On n'expose que le strict necessaire a l'affichage : ni uid, ni email.
  res.status(200).json({
    success: true,
    label: d.label,
    description: d.description,
    amount: d.amount,
    currency: "XOF",
    status: expired && d.status === "pending" ? "expired" : d.status,
  });
});

// ══════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS
// ══════════════════════════════════════════════════════════════════════════

/** Ecrit la notification in-app et envoie le push sur tous les appareils. */
async function notifyUser(uid, { type, title, body, targetId = null }) {
  try {
    await db.collection("users").doc(uid).collection("notifications").add({
      type,
      title,
      body,
      targetId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const tokensSnap = await db
      .collection("users").doc(uid).collection("tokens").get();
    const tokens = tokensSnap.docs.map((d) => d.id);
    if (tokens.length === 0) return;

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { type, targetId: targetId || "" },
      android: {
        priority: "high",
        notification: { channelId: "my_home_ci_channel" },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });

    // Purge des jetons devenus invalides : sans cela, la liste enfle et
    // chaque envoi gaspille des appels sur des appareils desinstalles.
    const stale = [];
    response.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error?.code || "";
        if (
          code.includes("registration-token-not-registered") ||
          code.includes("invalid-argument")
        ) {
          stale.push(tokens[i]);
        }
      }
    });
    await Promise.all(
      stale.map((t) =>
        db.collection("users").doc(uid).collection("tokens").doc(t).delete()
      )
    );
  } catch (e) {
    console.error(`notifyUser(${uid}) :`, e.message);
  }
}

/** Notifie le destinataire d'un nouveau message. */
exports.onMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const convSnap = await db
      .collection("conversations").doc(event.params.conversationId).get();
    if (!convSnap.exists) return;

    const conv = convSnap.data();
    const recipient = (conv.participants || []).find((p) => p !== message.senderId);
    if (!recipient) return;

    const senderName = conv.participantNames?.[message.senderId] || "Un utilisateur";
    const preview =
      message.type === "image" ? "📷 Photo" : (message.text || "").slice(0, 120);

    await notifyUser(recipient, {
      type: "message",
      title: senderName,
      body: preview,
      targetId: event.params.conversationId,
    });
  }
);

// ══════════════════════════════════════════════════════════════════════════
//  MODERATION ET ALERTES
// ══════════════════════════════════════════════════════════════════════════

/**
 * Reagit au changement de statut d'une annonce : previent le proprietaire et,
 * a la validation, notifie les alertes de recherche correspondantes.
 */
exports.onPropertyStatusChanged = onDocumentUpdated(
  "properties/{propertyId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const propertyId = event.params.propertyId;

    if (after.status === "active" && before.status !== "active") {
      await db.collection("properties").doc(propertyId).update({
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await notifyUser(after.ownerId, {
        type: "propertyApproved",
        title: "Annonce publiee",
        body: `« ${after.title} » est maintenant visible par les locataires.`,
        targetId: propertyId,
      });
      await matchSearchAlerts(propertyId, after);
    }

    if (after.status === "rejected") {
      await notifyUser(after.ownerId, {
        type: "propertyRejected",
        title: "Annonce refusee",
        body: after.rejectionReason
          ? `« ${after.title} » : ${after.rejectionReason}`
          : `« ${after.title} » n'a pas ete validee. Consultez votre espace proprietaire.`,
        targetId: propertyId,
      });
    }
  }
);

/**
 * Notifie les alertes correspondant a une annonce nouvellement publiee.
 *
 * Le filtrage se fait en memoire apres une requete large sur le quartier :
 * Firestore ne sait pas comparer une valeur de document a une plage stockee
 * dans un autre document. Acceptable tant que le nombre d'alertes par
 * quartier reste modeste ; a revoir au-dela de quelques milliers.
 */
async function matchSearchAlerts(propertyId, property) {
  try {
    const snap = await db
      .collectionGroup("alerts")
      .where("isActive", "==", true)
      .where("quarter", "==", property.quarter)
      .limit(500)
      .get();

    const matches = snap.docs.filter((doc) => {
      const a = doc.data();
      if (a.type && a.type !== property.type) return false;
      if (a.minPrice != null && property.price < a.minPrice) return false;
      if (a.maxPrice != null && property.price > a.maxPrice) return false;
      if (a.minRooms != null && property.rooms < a.minRooms) return false;
      if (a.isFurnished != null && property.isFurnished !== a.isFurnished) return false;
      return true;
    });

    console.log(`${matches.length} alerte(s) correspondent a ${propertyId}.`);

    await Promise.all(
      matches.map(async (doc) => {
        // Le chemin est users/{uid}/alerts/{id} : on remonte de deux niveaux.
        const uid = doc.ref.parent.parent?.id;
        if (!uid || uid === property.ownerId) return;

        await doc.ref.update({
          lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          matchCount: admin.firestore.FieldValue.increment(1),
        });

        await notifyUser(uid, {
          type: "alertMatch",
          title: "Nouveau logement pour vous",
          body: `${property.title} — ${property.price.toLocaleString("fr-FR")} FCFA/mois`,
          targetId: propertyId,
        });
      })
    );
  } catch (e) {
    console.error("matchSearchAlerts :", e.message);
  }
}

/** Accorde le badge verifie et le role proprietaire apres validation admin. */
exports.onVerificationDecided = onDocumentUpdated(
  "verificationRequests/{userId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const uid = event.params.userId;

    if (after.status === "approved") {
      await db.collection("users").doc(uid).update({
        isVerified: true,
        role: after.requestedRole || "owner",
      });
      await notifyUser(uid, {
        type: "verificationApproved",
        title: "Profil verifie",
        body: "Votre badge « Proprietaire verifie » est actif. Vous pouvez publier vos annonces.",
      });
    }

    if (after.status === "rejected") {
      await notifyUser(uid, {
        type: "verificationRejected",
        title: "Verification refusee",
        body: after.adminNote || "Les documents fournis n'ont pas pu etre valides.",
      });
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════
//  COMPTE
// ══════════════════════════════════════════════════════════════════════════

/**
 * Suppression definitive du compte et de toutes ses donnees.
 *
 * Obligatoire pour la publication : Apple (5.1.1(v)) et Google Play exigent
 * une suppression accessible depuis l'application des lors qu'un compte peut
 * y etre cree. Une simple deconnexion ou un formulaire de contact ne suffit
 * pas et fait rejeter la soumission.
 *
 * L'ordre compte : on supprime d'abord les donnees, le compte Auth en dernier.
 * L'inverse laisserait des orphelins impossibles a rattacher si l'operation
 * echouait a mi-parcours.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = requireAuth(request);

  console.log(`Suppression du compte ${uid} demandee.`);

  // 1. Annonces et leurs images.
  const properties = await db.collection("properties").where("ownerId", "==", uid).get();
  const bucket = admin.storage().bucket();

  for (const doc of properties.docs) {
    try {
      await bucket.deleteFiles({ prefix: `properties/${uid}/${doc.id}/` });
    } catch (e) {
      console.warn(`Images de ${doc.id} non supprimees :`, e.message);
    }
    await doc.ref.delete();
  }

  // 2. Conversations : on anonymise plutot que de supprimer.
  //    Effacer le fil priverait l'autre participant d'un historique qui lui
  //    appartient aussi, et masquerait les echanges en cas de signalement.
  const conversations = await db
    .collection("conversations").where("participants", "array-contains", uid).get();

  for (const doc of conversations.docs) {
    const names = doc.data().participantNames || {};
    const photos = doc.data().participantPhotos || {};
    names[uid] = "Compte supprime";
    photos[uid] = null;
    await doc.ref.update({
      participantNames: names,
      participantPhotos: photos,
      isArchived: true,
    });
  }

  // 3. Sous-collections du profil.
  for (const sub of ["favorites", "alerts", "notifications", "tokens", "private"]) {
    const snap = await db.collection("users").doc(uid).collection(sub).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }

  // 4. Avatar, demande de verification, profil.
  try {
    await bucket.deleteFiles({ prefix: `avatars/${uid}/` });
    await bucket.deleteFiles({ prefix: `verifications/${uid}/` });
  } catch (e) {
    console.warn("Fichiers residuels non supprimes :", e.message);
  }
  await db.collection("verificationRequests").doc(uid).delete().catch(() => {});
  await db.collection("users").doc(uid).delete();

  // 5. Compte d'authentification, en dernier.
  await admin.auth().deleteUser(uid);

  console.log(`Compte ${uid} supprime.`);
  return { success: true };
});

/** Attribue ou retire le role administrateur. Reserve aux administrateurs. */
exports.setAdminRole = onCall(async (request) => {
  requireAdmin(request);
  const { targetUid, isAdmin } = request.data || {};
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Utilisateur cible manquant.");
  }

  await admin.auth().setCustomUserClaims(targetUid, { admin: isAdmin === true });
  await db.collection("users").doc(targetUid).update({
    role: isAdmin === true ? "admin" : "tenant",
  });

  return { success: true };
});

/**
 * Amorce du premier administrateur.
 *
 * Ne fonctionne qu'une seule fois : une fois qu'un administrateur existe,
 * elle refuse systematiquement. Sans ce verrou, n'importe qui pourrait
 * s'octroyer les droits en appelant la fonction.
 *
 * ⚠️ A supprimer de ce fichier une fois le premier admin cree.
 */
exports.bootstrapFirstAdmin = onCall(async (request) => {
  const uid = requireAuth(request);

  const existing = await db.collection("users").where("role", "==", "admin").limit(1).get();
  if (!existing.empty) {
    throw new HttpsError("permission-denied", "Un administrateur existe deja.");
  }

  await admin.auth().setCustomUserClaims(uid, { admin: true });
  await db.collection("users").doc(uid).update({ role: "admin" });

  console.log(`Premier administrateur : ${uid}`);
  return { success: true };
});


// ══════════════════════════════════════════════════════════════════════════
//  QUOTA DE PUBLICATION ET VISIBILITE
// ══════════════════════════════════════════════════════════════════════════

/**
 * Etat du quota, pour affichage dans l'application.
 *
 * Le client ne calcule rien : il annonce au proprietaire ce que le serveur
 * lui repond. Deux sources de verite divergeraient tot ou tard, et c'est
 * l'utilisateur qui decouvrirait l'ecart au moment de payer.
 */
exports.getPublicationQuota = onCall(async (request) => {
  const uid = requireAuth(request);
  const quota = await readQuota(uid);

  // Prix facultatif : sans lui, on renvoie le plancher, ce qui suffit a
  // afficher « a partir de 500 F ».
  const price = Number(request.data?.price || 0);

  return {
    ...quota,
    freeTotal: FREE_PUBLICATION_OPERATIONS,
    feeRate: PUBLICATION_FEE_RATE,
    feeMinimum: PUBLICATION_FEE_MINIMUM,
    visibilityDays: VISIBILITY_DAYS,
    requiresPayment:
      !quota.isPro && quota.freeRemaining === 0 && quota.paidCredits === 0,
    amountDue: publicationFee(price),
  };
});

/**
 * Ouvre une fenetre de visibilite et consomme une unite de quota.
 *
 * Le decompte se fait ici, jamais dans l'application : un compteur client
 * repartirait de zero a la reinstallation.
 *
 * Ne consomment rien : la creation d'un brouillon et ses retouches, ni les
 * modifications faites pendant une fenetre encore ouverte — c'est
 * precisement ce que le proprietaire a acquis.
 */
exports.onPropertyWritten = onDocumentWritten(
  "properties/{propertyId}",
  async (event) => {
    const after = event.data?.after?.data() || null;
    if (!after) return; // suppression

    const uid = after.ownerId;
    if (!uid) return;

    if (!EXPOSED_STATUSES.includes(after.status)) return;

    const maintenant = Date.now();
    const fenetre = after.visibleUntil?.toMillis?.() || 0;

    // Fenetre encore ouverte : modifications libres. C'est aussi la sortie
    // du second passage declenche par notre propre ecriture ci-dessous —
    // sans elle, le declencheur se rappellerait indefiniment.
    if (fenetre > maintenant) return;

    const propertyId = event.params.propertyId;
    const quota = await readQuota(uid);

    const expiration = admin.firestore.Timestamp.fromDate(
      new Date(maintenant + VISIBILITY_DAYS * 24 * 60 * 60 * 1000),
    );

    if (quota.isPro) {
      await db.collection("properties").doc(propertyId)
        .update({ visibleUntil: expiration });
      return;
    }

    const ref = db.collection("publicationQuotas").doc(uid);

    // Transaction : deux publications simultanees consommeraient sinon le
    // meme credit deux fois.
    const couvert = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const d = snap.exists ? snap.data() : {};
      const freeUsed = Number(d.freeUsed || 0);
      const paidCredits = Number(d.paidCredits || 0);

      if (freeUsed < FREE_PUBLICATION_OPERATIONS) {
        tx.set(ref, {
          freeUsed: freeUsed + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { ok: true, restant: FREE_PUBLICATION_OPERATIONS - freeUsed - 1 };
      }

      if (paidCredits > 0) {
        tx.set(ref, {
          paidCredits: paidCredits - 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { ok: true, restant: 0 };
      }

      return { ok: false, restant: 0 };
    });

    if (!couvert.ok) {
      // Les regles Firestore auraient du refuser l'ecriture. On renvoie
      // l'annonce en brouillon plutot que de la laisser exposee sans
      // contrepartie, et on le journalise : c'est le signe d'un
      // contournement ou de regles mal deployees.
      console.warn(
        `Publication sans couverture : ${uid}, annonce ${propertyId}.`);
      await db.collection("properties").doc(propertyId).update({
        status: "draft",
        visibleUntil: null,
      });
      await notifyUser(uid, {
        type: "publicationRefused",
        title: "Publication non aboutie",
        body: "Vos operations gratuites sont epuisees. Reglez les frais de " +
              "publication pour rendre cette annonce visible.",
        targetId: propertyId,
      });
      return;
    }

    await db.collection("properties").doc(propertyId)
      .update({ visibleUntil: expiration });

    if (couvert.restant === 0 && quota.freeRemaining > 0) {
      await notifyUser(uid, {
        type: "quotaExhausted",
        title: "Publications gratuites epuisees",
        body: `Vos ${FREE_PUBLICATION_OPERATIONS} operations gratuites sont ` +
              "utilisees. Les suivantes coutent 5 % du prix de l'annonce, " +
              `minimum ${PUBLICATION_FEE_MINIMUM} F.`,
      });
    }
  },
);

/**
 * Retire les annonces dont la fenetre de 30 jours est echue.
 *
 * Sans ce balayage, `visibleUntil` ne serait qu'indicatif : l'annonce
 * resterait `active` et continuerait de remonter dans les recherches, la
 * duree de visibilite n'ayant alors aucune portee reelle.
 *
 * Le statut retenu est `archived` et non `draft` : le proprietaire retrouve
 * son annonce complete et la republie d'un geste, ce qui consomme une
 * nouvelle unite de quota.
 */
exports.expireVisibleProperties = onSchedule("every 24 hours", async () => {
  const maintenant = admin.firestore.Timestamp.now();

  const snap = await db.collection("properties")
    .where("status", "==", "active")
    .where("visibleUntil", "<=", maintenant)
    .limit(400)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.docs.forEach((d) => batch.update(d.ref, { status: "archived" }));
  await batch.commit();

  await Promise.all(snap.docs.map((d) => notifyUser(d.data().ownerId, {
    type: "propertyExpired",
    title: "Annonce expiree",
    body: `« ${d.data().title} » n'est plus visible apres ` +
          `${VISIBILITY_DAYS} jours. Republiez-la pour la remettre en ligne.`,
    targetId: d.id,
  })));

  console.log(`${snap.size} annonce(s) expiree(s).`);
});

// ══════════════════════════════════════════════════════════════════════════
//  PUBLICITES VIDEO
// ══════════════════════════════════════════════════════════════════════════

/**
 * Active une publicite sans paiement, au titre du Pack Pro.
 *
 * Cote client, un abonne Pro n'a aucun ecran de paiement a franchir. Cette
 * activation ne peut donc pas etre laissee a l'application : elle verifierait
 * elle-meme un statut qu'elle a tout interet a s'accorder.
 */
exports.activateAdvertisement = onCall(async (request) => {
  const uid = requireAuth(request);
  const { adId } = request.data || {};
  if (!adId) {
    throw new HttpsError("invalid-argument", "Publicite non precisee.");
  }

  const ref = db.collection("advertisements").doc(adId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().ownerId !== uid) {
    throw new HttpsError("permission-denied", "Cette publicite ne vous appartient pas.");
  }

  const { isPro } = await readQuota(uid);
  if (!isPro) {
    throw new HttpsError(
      "failed-precondition",
      "La diffusion est payante hors Pack Pro.",
    );
  }

  const until = new Date(
    Date.now() + PRODUCTS.ad_video.durationDays * 24 * 60 * 60 * 1000);

  await ref.update({
    status: "active",
    visibleUntil: admin.firestore.Timestamp.fromDate(until),
    activatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    visibleUntil: until.toISOString(),
    durationDays: PRODUCTS.ad_video.durationDays,
  };
});

/**
 * Retire les publicites dont les 3 jours sont ecoules.
 *
 * Meme raison que pour les annonces : sans balayage, `visibleUntil` ne serait
 * qu'indicatif et la duree achetee n'aurait aucune portee.
 */
exports.expireAdvertisements = onSchedule("every 6 hours", async () => {
  const maintenant = admin.firestore.Timestamp.now();

  const snap = await db.collection("advertisements")
    .where("status", "==", "active")
    .where("visibleUntil", "<=", maintenant)
    .limit(400)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.docs.forEach((d) => batch.update(d.ref, { status: "expired" }));
  await batch.commit();

  console.log(`${snap.size} publicite(s) expiree(s).`);
});
