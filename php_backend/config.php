<?php
/**
 * DateDash - Email Verification Backend Configuration
 */

// Allow CORS for Flutter Web / Mobile apps
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Api-Key");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// ─── App Settings ────────────────────────────────────────────────────────────
define('APP_NAME', 'DateDash');

// ─── SMTP Settings ───────────────────────────────────────────────────────────
// cPanel shared hosting: use 'localhost' as host with port 25 (no auth needed)
// OR use your domain mail server on port 587 with TLS
//
// OPTION A (Recommended for cPanel) — localhost, no auth:
define('SMTP_HOST',     'localhost');
define('SMTP_PORT',     25);
define('SMTP_SECURE',   '');          // No encryption on localhost
define('SMTP_AUTH',     false);       // No auth needed for localhost on cPanel
define('SMTP_USERNAME', '');
define('SMTP_PASSWORD', '');

// OPTION B — Use these if localhost/25 doesn't work (swap comments with OPTION A):
// define('SMTP_HOST',     'mail.apexspacemw.com');
// define('SMTP_PORT',     587);
// define('SMTP_SECURE',   'tls');
// define('SMTP_AUTH',     true);
// define('SMTP_USERNAME', 'no-reply@apexspacemw.com'); // Must exist in cPanel
// define('SMTP_PASSWORD', 'YOUR_EMAIL_PASSWORD_HERE');

// ─── Resend API ──────────────────────────────────────────────────────────────
// Sign up free at https://resend.com (3,000 emails/month free, no credit card)
// Steps:
//  1. Create account at https://resend.com
//  2. Go to API Keys → Create API Key → copy it below
//  3. FROM_EMAIL options:
//     a) Use 'onboarding@resend.dev' to test instantly (sends only to your verified email)
//     b) Add & verify your own domain in Resend → Domains, then use any address on it
define('RESEND_API_KEY', 'YOUR_RESEND_API_KEY_HERE'); // ← Paste your key here

// From address:
// For testing: 'onboarding@resend.dev'
// For production: 'no-reply@apexspacemw.com' (after verifying domain in Resend)
define('FROM_EMAIL', 'onboarding@resend.dev');
define('FROM_NAME',  'DateDash Team');

// ─── Optional App API Key Security ───────────────────────────────────────────
define('API_SECRET_KEY', '');

/**
 * Return JSON response and exit
 */
function sendJsonResponse($status, $message, $extra = []) {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(array_merge([
        'success' => ($status >= 200 && $status < 300),
        'message' => $message,
    ], $extra));
    exit();
}
