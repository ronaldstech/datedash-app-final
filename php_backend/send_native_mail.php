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

$htmlBody = '<!DOCTYPE html><html><body style="margin:0;padding:24px 16px;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#111827;">
  <table align="center" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px;background:#ffffff;border:1px solid #e5e7eb;">
    <tr>
      <td style="padding:28px 28px 8px;">
        <p style="margin:0 0 20px;color:#111827;font-size:18px;font-weight:700;">' . htmlspecialchars(APP_NAME) . '</p>
        <h1 style="margin:0 0 12px;color:#111827;font-size:22px;font-weight:700;">Verify your email address</h1>
        <p style="margin:0 0 24px;color:#4b5563;font-size:15px;line-height:1.5;">Use the verification code below to finish setting up your ' . htmlspecialchars(APP_NAME) . ' account.</p>
      </td>
    </tr>
    <tr>
      <td style="padding:0 28px 24px;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f9fafb;border:1px solid #e5e7eb;">
          <tr>
            <td align="center" style="padding:18px 16px;">
              <span style="font-family:\'Courier New\',Courier,monospace;font-size:32px;font-weight:700;color:#111827;letter-spacing:6px;">' . htmlspecialchars($code) . '</span>
            </td>
          </tr>
        </table>
        <p style="margin:18px 0 0;color:#4b5563;font-size:14px;line-height:1.5;">This code expires in <strong>15 minutes</strong>.</p>
        <p style="margin:18px 0 0;padding-top:18px;border-top:1px solid #e5e7eb;color:#6b7280;font-size:13px;line-height:1.5;">If you did not create a ' . htmlspecialchars(APP_NAME) . ' account, you can safely ignore this email.</p>
      </td>
    </tr>
  </table>
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
