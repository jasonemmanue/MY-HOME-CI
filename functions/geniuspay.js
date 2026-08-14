// ══════════════════════════════════════════════════════════════════════════
//  Adaptateur REST GeniusPay (https://geniuspay.ci)
//  Point d'entree : https://geniuspay.ci/api/v1/merchant
//  Methodes Cote d'Ivoire : wave, orange_money, mtn_money, moov_money
//
//  Secrets Firebase requis :
//    firebase functions:secrets:set GENIUSPAY_API_KEY
//    firebase functions:secrets:set GENIUSPAY_SECRET_KEY
//    firebase functions:secrets:set GENIUSPAY_WEBHOOK_SECRET
// ══════════════════════════════════════════════════════════════════════════

const crypto = require("crypto");

const BASE_URL = "https://geniuspay.ci/api/v1/merchant";

/** Erreurs de passerelle transitoires : la sandbox renvoie des 5xx Cloudflare. */
const GATEWAY_ERRORS = [502, 503, 504, 522, 524];
const MAX_ATTEMPTS = 3;
const TIMEOUT_MS = 25000;

function credentials() {
  const apiKey = process.env.GENIUSPAY_API_KEY;
  const secretKey = process.env.GENIUSPAY_SECRET_KEY;
  const webhookSecret = process.env.GENIUSPAY_WEBHOOK_SECRET;
  if (!apiKey) {
    throw new Error(
      "GENIUSPAY_API_KEY absent. Configurez-le via `firebase functions:secrets:set`."
    );
  }
  return { apiKey, secretKey: secretKey || apiKey, webhookSecret: webhookSecret || "" };
}

function headers() {
  const { apiKey, secretKey } = credentials();
  return {
    "Content-Type": "application/json",
    // Sans cet en-tete, le backend Laravel de GeniusPay repond par une
    // redirection HTML (302) au lieu du JSON attendu.
    Accept: "application/json",
    "X-API-Key": apiKey,
    "X-API-Secret": secretKey,
  };
}

/**
 * Initie un paiement.
 * @returns {Promise<{paymentUrl: string, reference: string, transactionId: string, raw: object}>}
 */
async function createPayment({
  reference,
  amount,
  currency = "XOF",
  paymentMethod,
  description,
  customerEmail,
  customerPhone,
  metadata = {},
  callbackUrl,
  returnUrl,
  errorUrl,
}) {
  const body = {
    amount,
    currency,
    payment_method: paymentMethod,
    description: description || "Paiement My Home CI",
    customer: {
      email: customerEmail || "",
      ...(customerPhone ? { phone: customerPhone } : {}),
      country: "CI",
    },
    metadata: { ...metadata, internal_reference: reference },
    callback_url: callbackUrl,
    success_url: returnUrl || "",
    error_url: errorUrl || returnUrl || "",
  };

  let response;
  let json = {};

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

    try {
      response = await fetch(`${BASE_URL}/payments`, {
        method: "POST",
        headers: headers(),
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (e) {
      clearTimeout(timer);
      console.warn(`GeniusPay tentative ${attempt} : ${e.name} ${e.message}`);
      if (attempt === MAX_ATTEMPTS) {
        throw new Error("GeniusPay injoignable. Reessayez dans un instant.");
      }
      await new Promise((r) => setTimeout(r, 1500 * attempt));
      continue;
    }
    clearTimeout(timer);

    json = {};
    try {
      json = await response.json();
    } catch (_) {
      /* corps non JSON : traite comme une erreur ci-dessous */
    }

    if (GATEWAY_ERRORS.includes(response.status) && attempt < MAX_ATTEMPTS) {
      console.warn(
        `GeniusPay HTTP ${response.status} (${attempt}/${MAX_ATTEMPTS}), nouvel essai…`
      );
      await new Promise((r) => setTimeout(r, 1500 * attempt));
      continue;
    }
    break;
  }

  if (!response.ok) {
    if (GATEWAY_ERRORS.includes(response.status)) {
      throw new Error(
        `Le service de paiement est temporairement indisponible (HTTP ${response.status}).`
      );
    }
    throw new Error(
      `GeniusPay createPayment a echoue (HTTP ${response.status}) : ${JSON.stringify(json)}`
    );
  }

  const data = json.data || json;
  console.log("GeniusPay paiement cree :", data.reference, "→", data.payment_url);

  return {
    paymentUrl:
      data.payment_url ||
      data.paymentUrl ||
      data.checkout_url ||
      data.payment_link ||
      data.url ||
      data.link ||
      "",
    reference: data.reference || reference,
    transactionId: data.transaction_id || data.id || reference,
    raw: json,
  };
}

/**
 * Interroge le statut d'un paiement.
 *
 * C'est la source de verite : le webhook annonce un evenement, mais on
 * reverifie ici avant d'accorder quoi que ce soit. Un webhook peut etre
 * rejoue ou forge ; une lecture authentifiee de l'API ne l'est pas.
 *
 * @returns {Promise<{status: 'completed'|'failed'|'cancelled'|'pending', raw: object}>}
 */
async function checkPayment(reference) {
  const readStatus = (obj) => {
    if (!obj) return null;
    const v = obj.status ?? obj.state ?? obj.payment_status ?? obj.transaction_status;
    return v != null ? String(v).toLowerCase() : null;
  };

  // L'API expose le statut sous plusieurs formes selon la version : on essaie
  // les trois points d'entree connus plutot que d'en supposer un seul.
  const urls = [
    `${BASE_URL}/transactions/${reference}`,
    `${BASE_URL}/payments/${reference}`,
    `${BASE_URL}/payments?reference=${encodeURIComponent(reference)}`,
  ];

  let lastJson = {};
  for (const url of urls) {
    try {
      const res = await fetch(url, { method: "GET", headers: headers() });
      let json = {};
      try {
        json = await res.json();
      } catch (_) {
        continue;
      }
      lastJson = json;

      if (json && json.success === false) continue;

      let obj = json.data;
      if (Array.isArray(obj)) obj = obj[0];
      if (!obj) obj = json;

      const status = readStatus(obj);
      if (status) {
        console.log(`GeniusPay checkPayment ${reference} → ${status}`);
        return { status, raw: json };
      }
    } catch (e) {
      console.warn("checkPayment endpoint echoue :", url, e.message);
    }
  }

  return { status: "pending", raw: lastJson };
}

/**
 * Verifie la signature HMAC-SHA256 du webhook.
 *
 * Renvoie `false` si le secret est configure mais la signature absente ou
 * invalide. Si aucun secret n'est configure, on laisse passer en journalisant
 * un avertissement : refuser bloquerait totalement l'encaissement tant que le
 * secret n'est pas pose, ce qui est pire en pratique — mais cet etat ne doit
 * pas durer au-dela de la mise en production.
 */
function verifyWebhookSignature(rawBody, receivedSignature) {
  const { webhookSecret } = credentials();
  if (!webhookSecret) {
    console.warn(
      "⚠️ GENIUSPAY_WEBHOOK_SECRET non configure : signature du webhook non verifiee."
    );
    return true;
  }
  if (!receivedSignature) return false;

  const expected = crypto
    .createHmac("sha256", webhookSecret)
    .update(rawBody)
    .digest("hex");

  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, "hex"),
      Buffer.from(String(receivedSignature).replace(/^sha256=/, ""), "hex")
    );
  } catch (_) {
    return false;
  }
}

module.exports = { BASE_URL, createPayment, checkPayment, verifyWebhookSignature };
