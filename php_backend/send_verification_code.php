<?php
/**
 * Snellum - Send Email Verification Code via Resend
 *
 * Uses Resend (https://resend.com) — free tier: 3,000 emails/month.
 * Uses HTTPS API — no SMTP ports needed.
 *
 * Setup:
 *  1. Sign up at https://resend.com (free, no credit card)
 *  2. Go to API Keys → Create API Key
 *  3. Add your sending domain OR use the free onboarding address:
 *     From: onboarding@resend.dev  (works immediately for testing)
 *  4. Paste the key in config.php as RESEND_API_KEY
 */

@set_time_limit(20);

require_once __DIR__ . '/config.php';

// Only allow POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(405, 'Invalid request method. POST required.');
}

// Read JSON input
$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true);
if (!$data) $data = $_POST;

// Optional API Key check
if (defined('API_SECRET_KEY') && !empty(API_SECRET_KEY)) {
    $providedKey = $_SERVER['HTTP_X_API_KEY'] ?? ($data['api_key'] ?? '');
    if ($providedKey !== API_SECRET_KEY) {
        sendJsonResponse(403, 'Unauthorized. Invalid API Key.');
    }
}

// Validate input
$email = isset($data['email']) ? trim($data['email']) : '';
$code  = isset($data['code'])  ? trim($data['code'])  : '';

if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendJsonResponse(400, 'Valid email address is required.');
}
if (empty($code)) {
    sendJsonResponse(400, 'Verification code is required.');
}

// Check Resend key is configured
if (!defined('RESEND_API_KEY') || empty(RESEND_API_KEY) || RESEND_API_KEY === 'YOUR_RESEND_API_KEY_HERE') {
    sendJsonResponse(500, 'RESEND_API_KEY is not configured in config.php.');
}

// HTML Email Template
$htmlBody = '<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#111827;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f4f5f7;padding:24px 15px;">
    <tr>
      <td align="center">
        <table width="520" cellpadding="0" cellspacing="0" border="0"
          style="max-width:520px;width:100%;background:#ffffff;border:1px solid #e5e7eb;">

          <!-- Body -->
          <tr>
            <td style="padding:28px 28px 8px;">
              <p style="margin:0 0 20px;color:#111827;font-size:18px;font-weight:700;">' . htmlspecialchars(APP_NAME) . '</p>
              <h1 style="margin:0 0 12px;color:#111827;font-size:22px;font-weight:700;">Verify your email address</h1>
              <p style="margin:0 0 24px;color:#4b5563;font-size:15px;line-height:1.5;">
                Use the verification code below to finish setting up your ' . htmlspecialchars(APP_NAME) . ' account.
              </p>
            </td>
          </tr>

          <!-- Code -->
          <tr>
            <td style="padding:0 28px 24px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f9fafb;border:1px solid #e5e7eb;">
                <tr>
                  <td align="center" style="padding:18px 16px;">
                    <span style="font-family:\'Courier New\',Courier,monospace;font-size:32px;font-weight:700;color:#111827;letter-spacing:6px;display:inline-block;line-height:1;">' . htmlspecialchars($code) . '</span>
                  </td>
                </tr>
              </table>

              <p style="margin:18px 0 0;color:#4b5563;font-size:14px;line-height:1.5;">
                This code expires in <strong>15 minutes</strong>.
              </p>
              <p style="margin:18px 0 0;padding-top:18px;border-top:1px solid #e5e7eb;color:#6b7280;font-size:13px;line-height:1.5;">
                If you did not create a ' . htmlspecialchars(APP_NAME) . ' account, you can safely ignore this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>';

// ── Send via Resend API ───────────────────────────────────────────────────────
$payload = json_encode([
    'from'    => FROM_NAME . ' <' . FROM_EMAIL . '>',
    'to'      => [$email],
    'subject' => APP_NAME . ' - Your Verification Code: ' . $code,
    'html'    => $htmlBody,
    'text'    => 'Your ' . APP_NAME . ' verification code is: ' . $code . "\n\nIt expires in 15 minutes.\nIf you did not request this, ignore this message.",
]);

$ch = curl_init('https://api.resend.com/emails');
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => $payload,
    CURLOPT_TIMEOUT        => 15,
    CURLOPT_HTTPHEADER     => [
        'Authorization: Bearer ' . RESEND_API_KEY,
        'Content-Type: application/json',
    ],
]);

$response  = curl_exec($ch);
$httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($curlError) {
    sendJsonResponse(500, 'cURL error: ' . $curlError, ['email' => $email]);
}

$resData = json_decode($response, true);

if ($httpCode === 200 || $httpCode === 201) {
    sendJsonResponse(200, 'Verification code sent successfully to ' . $email, [
        'email'     => $email,
        'method'    => 'resend_api',
        'resend_id' => $resData['id'] ?? null,
    ]);
} else {
    sendJsonResponse(500, 'Resend API error [' . $httpCode . ']: ' . ($resData['message'] ?? $response), [
        'email'     => $email,
        'http_code' => $httpCode,
    ]);
}
