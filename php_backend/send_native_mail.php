<?php
/**
 * Fallback: uses PHP native mail() with corrected headers.
 * This is used if phpmailer/src/ folder is not present.
 * NOTE: native mail() is unreliable on many hosts — use PHPMailer for best results.
 */

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(405, 'Invalid request method. POST required.');
}

$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true);
if (!$data) $data = $_POST;

$email = isset($data['email']) ? trim($data['email']) : '';
$code  = isset($data['code'])  ? trim($data['code'])  : '';

if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendJsonResponse(400, 'Valid email address is required.');
}
if (empty($code)) {
    sendJsonResponse(400, 'Verification code is required.');
}

$subject = APP_NAME . ' - Your Verification Code: ' . $code;

$htmlBody = '<!DOCTYPE html><html><body style="background:#0f0f14;font-family:Arial,sans-serif;color:#fff;padding:30px;">
  <div style="max-width:520px;margin:0 auto;background:#1a1a24;border-radius:20px;padding:30px;border:1px solid rgba(255,255,255,0.1);">
    <h1 style="color:#FF4D85;text-align:center;">' . htmlspecialchars(APP_NAME) . '</h1>
    <h2 style="text-align:center;">Verify Your Email</h2>
    <p style="color:#a0a0b0;text-align:center;">Your 6-digit verification code is:</p>
    <div style="background:linear-gradient(135deg,#FF4D85,#FF1A60);border-radius:16px;padding:20px;text-align:center;margin:20px 0;">
      <span style="font-size:38px;font-weight:bold;color:#fff;letter-spacing:10px;">' . htmlspecialchars($code) . '</span>
    </div>
    <p style="color:#808095;font-size:13px;text-align:center;">Expires in 15 minutes. If you did not request this, ignore it.</p>
    <p style="color:#606075;font-size:12px;text-align:center;">&copy; ' . date('Y') . ' ' . htmlspecialchars(APP_NAME) . '</p>
  </div>
</body></html>';

$headers  = "MIME-Version: 1.0\r\n";
$headers .= "Content-type: text/html; charset=UTF-8\r\n";
$headers .= "From: " . FROM_NAME . " <" . FROM_EMAIL . ">\r\n";
$headers .= "Reply-To: " . FROM_EMAIL . "\r\n";
$headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";

$sent = @mail($email, $subject, $htmlBody, $headers);

if ($sent) {
    sendJsonResponse(200, 'Verification code sent successfully to ' . $email . ' (native mail)', ['email' => $email]);
} else {
    sendJsonResponse(500, 'native mail() failed. Please install PHPMailer for SMTP support.', ['email' => $email]);
}
