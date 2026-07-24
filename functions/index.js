const crypto = require("crypto");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
const {Resend} = require("resend");

initializeApp();

const resendApiKey = defineSecret("RESEND_API_KEY");
const verificationSecret = defineSecret("EMAIL_VERIFICATION_SECRET");
const emailFrom = defineString("EMAIL_FROM", {
  default: "Snellum <onboarding@resend.dev>",
});

const db = getFirestore();
const codeTtlMinutes = 10;
const maxAttempts = 5;

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

exports.requestEmailVerification = onRequest(
  {secrets: [resendApiKey, verificationSecret]},
  async (req, res) => {
    setCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      sendJson(req, res, 405, {error: "Method not allowed"});
      return;
    }

    const email = normalizeEmail(req.body && req.body.email);
    if (!isValidEmail(email)) {
      sendJson(req, res, 400, {error: "Enter a valid email address."});
      return;
    }

    const docRef = db.collection("emailVerificationCodes").doc(emailDocId(email));
    const existing = await docRef.get();
    const now = Timestamp.now();

    if (existing.exists) {
      const data = existing.data();
      const lastSentAt = data.lastSentAt;
      if (lastSentAt && now.toMillis() - lastSentAt.toMillis() < 60 * 1000) {
        sendJson(req, res, 429, {error: "Please wait before requesting another code."});
        return;
      }
    }

    const code = createCode();
    const expiresAt = Timestamp.fromMillis(Date.now() + codeTtlMinutes * 60 * 1000);

    await docRef.set({
      email,
      codeHash: hashCode(email, code, verificationSecret.value()),
      attempts: 0,
      createdAt: FieldValue.serverTimestamp(),
      lastSentAt: FieldValue.serverTimestamp(),
      expiresAt,
    });

    const resend = new Resend(resendApiKey.value());
    const emailResult = await resend.emails.send({
      from: emailFrom.value(),
      to: [email],
      subject: "Verify your Snellum account",
      text: `Your Snellum verification code is ${code}. It expires in ${codeTtlMinutes} minutes.`,
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.5;color:#222">
          <h2>Your Snellum verification code</h2>
          <p>Use this code to finish creating your account:</p>
          <p style="font-size:32px;font-weight:700;letter-spacing:6px">${code}</p>
          <p>This code expires in ${codeTtlMinutes} minutes.</p>
        </div>
      `,
    });

    if (emailResult.error) {
      throw new Error(emailResult.error.message || "Resend email failed.");
    }

    sendJson(req, res, 200, {ok: true});
  },
);

exports.verifyEmailCode = onRequest(
  {secrets: [verificationSecret]},
  async (req, res) => {
    setCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      sendJson(req, res, 405, {error: "Method not allowed"});
      return;
    }

    const email = normalizeEmail(req.body && req.body.email);
    const code = String((req.body && req.body.code) || "").trim();
    if (!isValidEmail(email) || !/^\d{6}$/.test(code)) {
      sendJson(req, res, 400, {error: "Enter the 6-digit verification code."});
      return;
    }

    const docRef = db.collection("emailVerificationCodes").doc(emailDocId(email));
    const doc = await docRef.get();
    if (!doc.exists) {
      sendJson(req, res, 400, {error: "Verification code not found. Request a new code."});
      return;
    }

    const data = doc.data();
    if (!data.expiresAt || data.expiresAt.toMillis() < Date.now()) {
      await docRef.delete();
      sendJson(req, res, 400, {error: "Verification code expired. Request a new code."});
      return;
    }

    if ((data.attempts || 0) >= maxAttempts) {
      await docRef.delete();
      sendJson(req, res, 429, {error: "Too many attempts. Request a new code."});
      return;
    }

    const expectedHash = data.codeHash;
    const actualHash = hashCode(email, code, verificationSecret.value());
    const isMatch = crypto.timingSafeEqual(
      Buffer.from(expectedHash, "hex"),
      Buffer.from(actualHash, "hex"),
    );

    if (!isMatch) {
      await docRef.update({attempts: FieldValue.increment(1)});
      sendJson(req, res, 400, {error: "Incorrect verification code."});
      return;
    }

    await docRef.delete();
    sendJson(req, res, 200, {ok: true});
  },
);
