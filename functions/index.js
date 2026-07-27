const crypto = require("crypto");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const { Resend } = require("resend");
const { RtcTokenBuilder, RtcRole } = require("agora-token");

initializeApp();

const db = getFirestore();

// -----------------------------------------------------------------------------
// Firebase Secrets & Config
// -----------------------------------------------------------------------------

const resendApiKey = defineSecret("RESEND_API_KEY");
const verificationSecret = defineSecret("EMAIL_VERIFICATION_SECRET");
const agoraAppCert = defineSecret("AGORA_APP_CERTIFICATE");

const emailFrom = defineString("EMAIL_FROM", {
  default: "Snellum <onboarding@resend.dev>",
});

// App ID is public information
const AGORA_APP_ID = "45fbe0e2e7b844bfab588523c914bfb2";

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
  res.set("Access-Control-Allow-Headers", "Content-Type");
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

// -----------------------------------------------------------------------------
// Generate Agora Token
// -----------------------------------------------------------------------------

exports.generateAgoraToken = onRequest(
  {
    secrets: [agoraAppCert],
  },
  async (req, res) => {
    setCors(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    const channelName = (
      req.body?.channelName ||
      req.query.channelName ||
      ""
    ).trim();

    const uid = parseInt(
      req.body?.uid || req.query.uid || "0",
      10
    );

    if (!channelName) {
      return sendJson(req, res, 400, {
        error: "channelName is required",
      });
    }

    try {
      const expireSeconds = 3600;

      const privilegeExpiredTs =
        Math.floor(Date.now() / 1000) + expireSeconds;

      const token = RtcTokenBuilder.buildTokenWithUid(
        AGORA_APP_ID,
        agoraAppCert.value(),
        channelName,
        uid,
        RtcRole.PUBLISHER,
        privilegeExpiredTs,
        privilegeExpiredTs
      );

      sendJson(req, res, 200, {
        token,
      });
    } catch (err) {
      console.error("Agora token generation failed:", err);

      sendJson(req, res, 500, {
        error: "Token generation failed",
      });
    }
  }
);