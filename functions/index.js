const crypto = require("crypto");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const { Resend } = require("resend");

initializeApp();

const db = getFirestore();

// -----------------------------------------------------------------------------
// Firebase Secrets & Config
// -----------------------------------------------------------------------------

const resendApiKey = defineSecret("RESEND_API_KEY");
const verificationSecret = defineSecret("EMAIL_VERIFICATION_SECRET");
const sumsubAppToken = defineSecret("SUMSUB_APP_TOKEN");
const sumsubSecretKey = defineSecret("SUMSUB_SECRET_KEY");
const sumsubWebhookSecret = defineSecret("SUMSUB_WEBHOOK_SECRET");

const emailFrom = defineString("EMAIL_FROM", {
  default: "Snellum <onboarding@resend.dev>",
});

const sumsubLevelName = defineString("SUMSUB_LEVEL_NAME", {
  default: "basic-kyc-level",
});

const sumsubBaseUrl = defineString("SUMSUB_BASE_URL", {
  default: "https://api.sumsub.com",
});

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

const CODE_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

function setCors(req, res) {
  res.set("Access-Control-Allow-Origin", req.get("origin") || "*");
  res.set(
    "Access-Control-Allow-Headers",
    "Authorization, Content-Type, X-Payload-Digest, X-Payload-Digest-Alg"
  );
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

function sendJson(req, res, status, body) {
  setCors(req, res);
  res.status(status).json(body);
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function emailDocId(email) {
  return crypto.createHash("sha256").update(email).digest("hex");
}

function hashCode(email, code, secret) {
  return crypto
    .createHmac("sha256", secret)
    .update(`${email}:${code}`)
    .digest("hex");
}

function createCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

function parseBearerToken(req) {
  const header = req.get("authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

async function requireFirebaseUser(req) {
  const idToken = parseBearerToken(req);

  if (!idToken) {
    const err = new Error("Missing authorization token.");
    err.status = 401;
    throw err;
  }

  try {
    return await getAuth().verifyIdToken(idToken);
  } catch (error) {
    const err = new Error("Invalid authorization token.");
    err.status = 401;
    throw err;
  }
}

function sumsubSignature(method, pathWithQuery, body) {
  const ts = Math.floor(Date.now() / 1000).toString();
  const signature = crypto
    .createHmac("sha256", sumsubSecretKey.value())
    .update(ts + method.toUpperCase() + pathWithQuery + body)
    .digest("hex");

  return { ts, signature };
}

async function sumsubPost(pathWithQuery, payload) {
  const body = JSON.stringify(payload);
  const { ts, signature } = sumsubSignature("POST", pathWithQuery, body);
  const response = await fetch(`${sumsubBaseUrl.value()}${pathWithQuery}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-App-Token": sumsubAppToken.value(),
      "X-App-Access-Sig": signature,
      "X-App-Access-Ts": ts,
    },
    body,
  });

  const text = await response.text();
  let data = {};

  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { description: text };
  }

  if (!response.ok) {
    const message =
      data.description ||
      data.error ||
      "Identity verification provider request failed.";
    const err = new Error(message);
    err.status = response.status;
    throw err;
  }

  return data;
}

function safeTimingEqualHex(a, b) {
  if (!a || !b || a.length !== b.length) return false;

  try {
    return crypto.timingSafeEqual(Buffer.from(a, "hex"), Buffer.from(b, "hex"));
  } catch (_) {
    return false;
  }
}

function verifySumsubWebhook(req) {
  const digest = req.get("x-payload-digest");
  const digestAlg = req.get("x-payload-digest-alg") || "HMAC_SHA256_HEX";
  const algorithms = {
    HMAC_SHA1_HEX: "sha1",
    HMAC_SHA256_HEX: "sha256",
    HMAC_SHA512_HEX: "sha512",
  };
  const algorithm = algorithms[digestAlg];

  if (!digest || !algorithm || !req.rawBody) return false;

  const calculatedDigest = crypto
    .createHmac(algorithm, sumsubWebhookSecret.value())
    .update(req.rawBody)
    .digest("hex");

  return safeTimingEqualHex(digest, calculatedDigest);
}

// -----------------------------------------------------------------------------
// Identity Verification with Sumsub
// -----------------------------------------------------------------------------

exports.createIdentityVerificationLink = onRequest(
  {
    secrets: [sumsubAppToken, sumsubSecretKey],
  },
  async (req, res) => {
    setCors(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      return sendJson(req, res, 405, {
        error: "Method not allowed",
      });
    }

    try {
      const decodedToken = await requireFirebaseUser(req);
      const uid = decodedToken.uid;
      const email = normalizeEmail(req.body?.email || decodedToken.email);
      const phone = String(req.body?.phone || decodedToken.phone_number || "")
        .trim();

      const applicantIdentifiers = {};
      if (isValidEmail(email)) applicantIdentifiers.email = email;
      if (phone) applicantIdentifiers.phone = phone;

      const payload = {
        levelName: sumsubLevelName.value(),
        userId: uid,
        ttlInSecs: 1800,
      };

      if (Object.keys(applicantIdentifiers).length > 0) {
        payload.applicantIdentifiers = applicantIdentifiers;
      }

      const data = await sumsubPost(
        "/resources/sdkIntegrations/levels/-/websdkLink?lang=en&source=api",
        payload
      );

      if (!data.url) {
        throw new Error("Identity verification provider did not return a URL.");
      }

      await db.collection("users").doc(uid).set(
        {
          isVerified: false,
          verificationStatus: "pending",
          nationalId: "Sumsub",
          nationalIdUrl: data.url,
          identityProvider: "sumsub",
          identityExternalUserId: uid,
          identityVerificationUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      sendJson(req, res, 200, {
        url: data.url,
        provider: "sumsub",
      });
    } catch (err) {
      console.error("Create Sumsub verification link failed:", err);
      sendJson(req, res, err.status || 500, {
        error: err.message || "Could not start identity verification.",
      });
    }
  }
);

exports.sumsubIdentityWebhook = onRequest(
  {
    secrets: [sumsubWebhookSecret],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    if (!verifySumsubWebhook(req)) {
      res.status(401).json({ error: "Invalid webhook signature" });
      return;
    }

    const event = req.body || {};
    const uid = String(event.externalUserId || "").trim();

    if (!uid) {
      res.status(400).json({ error: "Missing externalUserId" });
      return;
    }

    const reviewAnswer = event.reviewResult?.reviewAnswer;
    let verificationStatus = "pending";
    let isVerified = false;

    if (
      event.type === "applicantDeleted" ||
      event.type === "applicantReset" ||
      reviewAnswer === "RED"
    ) {
      verificationStatus = "unverified";
    } else if (reviewAnswer === "GREEN") {
      verificationStatus = "verified";
      isVerified = true;
    }

    const update = {
      isVerified,
      verificationStatus,
      nationalId: "Sumsub",
      identityProvider: "sumsub",
      identityApplicantId: event.applicantId || null,
      identityInspectionId: event.inspectionId || null,
      identityReviewStatus: event.reviewStatus || null,
      identityReviewAnswer: reviewAnswer || null,
      identityWebhookType: event.type || null,
      identityVerificationUpdatedAt: FieldValue.serverTimestamp(),
    };

    if (event.reviewResult?.moderationComment) {
      update.identityModerationComment =
        event.reviewResult.moderationComment;
    }

    await db.collection("users").doc(uid).set(update, { merge: true });

    await db.collection("identityVerificationEvents").add({
      provider: "sumsub",
      uid,
      applicantId: event.applicantId || null,
      type: event.type || null,
      reviewStatus: event.reviewStatus || null,
      reviewAnswer: reviewAnswer || null,
      createdAtMs: event.createdAtMs || null,
      receivedAt: FieldValue.serverTimestamp(),
    });

    res.status(200).json({ ok: true });
  }
);

// -----------------------------------------------------------------------------
// Request Email Verification
// -----------------------------------------------------------------------------

exports.requestEmailVerification = onRequest(
  {
    secrets: [resendApiKey, verificationSecret],
  },
  async (req, res) => {
    setCors(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      return sendJson(req, res, 405, {
        error: "Method not allowed",
      });
    }

    const email = normalizeEmail(req.body?.email);

    if (!isValidEmail(email)) {
      return sendJson(req, res, 400, {
        error: "Enter a valid email address.",
      });
    }

    const docRef = db
      .collection("emailVerificationCodes")
      .doc(emailDocId(email));

    const existing = await docRef.get();
    const now = Timestamp.now();

    if (existing.exists) {
      const data = existing.data();

      if (
        data.lastSentAt &&
        now.toMillis() - data.lastSentAt.toMillis() < 60000
      ) {
        return sendJson(req, res, 429, {
          error: "Please wait before requesting another code.",
        });
      }
    }

    const code = createCode();

    const expiresAt = Timestamp.fromMillis(
      Date.now() + CODE_TTL_MINUTES * 60 * 1000
    );

    await docRef.set({
      email,
      codeHash: hashCode(email, code, verificationSecret.value()),
      attempts: 0,
      createdAt: FieldValue.serverTimestamp(),
      lastSentAt: FieldValue.serverTimestamp(),
      expiresAt,
    });

    const resend = new Resend(resendApiKey.value());

    const result = await resend.emails.send({
      from: emailFrom.value(),
      to: [email],
      subject: "Verify your Snellum account",
      text: `Your Snellum verification code is ${code}. It expires in ${CODE_TTL_MINUTES} minutes.`,
      html: `
        <div style="font-family:Arial,sans-serif">
          <h2>Your Snellum verification code</h2>
          <p>Use this code to complete your account registration.</p>
          <h1 style="letter-spacing:6px">${code}</h1>
          <p>This code expires in ${CODE_TTL_MINUTES} minutes.</p>
        </div>
      `,
    });

    if (result.error) {
      throw new Error(result.error.message || "Failed to send email.");
    }

    sendJson(req, res, 200, { ok: true });
  }
);

// -----------------------------------------------------------------------------
// Verify Email Code
// -----------------------------------------------------------------------------

exports.verifyEmailCode = onRequest(
  {
    secrets: [verificationSecret],
  },
  async (req, res) => {
    setCors(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      return sendJson(req, res, 405, {
        error: "Method not allowed",
      });
    }

    const email = normalizeEmail(req.body?.email);
    const code = String(req.body?.code || "").trim();

    if (!isValidEmail(email) || !/^\d{6}$/.test(code)) {
      return sendJson(req, res, 400, {
        error: "Enter the 6-digit verification code.",
      });
    }

    const docRef = db
      .collection("emailVerificationCodes")
      .doc(emailDocId(email));

    const doc = await docRef.get();

    if (!doc.exists) {
      return sendJson(req, res, 400, {
        error: "Verification code not found.",
      });
    }

    const data = doc.data();

    if (!data.expiresAt || data.expiresAt.toMillis() < Date.now()) {
      await docRef.delete();

      return sendJson(req, res, 400, {
        error: "Verification code expired.",
      });
    }

    if ((data.attempts || 0) >= MAX_ATTEMPTS) {
      await docRef.delete();

      return sendJson(req, res, 429, {
        error: "Too many attempts. Request a new code.",
      });
    }

    const expectedHash = data.codeHash;
    const actualHash = hashCode(
      email,
      code,
      verificationSecret.value()
    );

    const valid = crypto.timingSafeEqual(
      Buffer.from(expectedHash, "hex"),
      Buffer.from(actualHash, "hex")
    );

    if (!valid) {
      await docRef.update({
        attempts: FieldValue.increment(1),
      });

      return sendJson(req, res, 400, {
        error: "Incorrect verification code.",
      });
    }

    await docRef.delete();

    sendJson(req, res, 200, {
      ok: true,
    });
  }
);
