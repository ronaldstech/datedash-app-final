<?php
/**
 * DateDash - Send Email Verification Code via Resend
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
<body style="margin:0;padding:0;background:#0f0f14;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#0f0f14;padding:40px 15px;">
    <tr>
      <td align="center">
        <table width="520" cellpadding="0" cellspacing="0" border="0"
          style="max-width:520px;width:100%;background:#1a1a24;border-radius:20px;overflow:hidden;border:1px solid rgba(255,255,255,0.08);">

          <!-- Header -->
          <tr>
            <td align="center" style="padding:32px 24px 24px;background:linear-gradient(135deg,rgba(255,77,133,0.18),rgba(255,77,133,0.04));">
              <h1 style="margin:0;color:#FF4D85;font-size:30px;font-weight:900;letter-spacing:-0.5px;">' . htmlspecialchars(APP_NAME) . '</h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px 36px;">
              <h2 style="margin:0 0 12px;color:#ffffff;font-size:22px;font-weight:800;text-align:center;">Verify Your Email</h2>
              <p style="margin:0 0 28px;color:#a0a0b0;font-size:15px;line-height:1.65;text-align:center;">
                Welcome to ' . htmlspecialchars(APP_NAME) . '! Enter the 6-digit code below to activate your account.
              </p>

              <!-- OTP Box -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center"
                    style="background:linear-gradient(135deg,#FF4D85,#FF1A60);border-radius:16px;padding:22px 10px;">
                    <span style="font-family:\'Courier New\',Courier,monospace;font-size:42px;font-weight:900;
                      color:#ffffff;letter-spacing:14px;display:inline-block;line-height:1;">' . htmlspecialchars($code) . '</span>
                  </td>
                </tr>
              </table>

              <p style="margin:24px 0 0;color:#606075;font-size:13px;text-align:center;line-height:1.6;">
                This code expires in <strong style="color:#a0a0b0;">15 minutes</strong>.<br>
                If you did not create a ' . htmlspecialchars(APP_NAME) . ' account, you can safely ignore this email.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center"
              style="padding:18px 24px;background:#13131c;border-top:1px solid rgba(255,255,255,0.05);
                color:#505065;font-size:12px;line-height:1.5;">
              &copy; ' . date('Y') . ' ' . htmlspecialchars(APP_NAME) . '. All rights reserved.
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
