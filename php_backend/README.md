# DateDash PHP Email Verification Backend

This PHP backend sends 6-digit email verification codes to users via **SMTP** (using PHPMailer) for reliable delivery on shared hosting.

---

## 📁 Files

| File | Purpose |
|---|---|
| `config.php` | SMTP credentials, app name, API key |
| `send_verification_code.php` | Main endpoint — sends emails via PHPMailer SMTP |
| `send_native_mail.php` | Fallback endpoint (used when PHPMailer is not installed) |
| `phpmailer/src/` | PHPMailer library (you must download this) |

---

## 🚀 Setup Steps

### 1. Download PHPMailer

Download PHPMailer from GitHub releases:
👉 https://github.com/PHPMailer/PHPMailer/releases/latest

Extract and copy the **`src/`** folder from the zip into your `php_backend/` folder so the structure looks like:
```
php_backend/
├── config.php
├── send_verification_code.php
├── send_native_mail.php
└── phpmailer/
    └── src/
        ├── PHPMailer.php
        ├── SMTP.php
        └── Exception.php
```

### 2. Configure `config.php`

Open `config.php` and fill in your hosting email credentials:

```php
define('SMTP_HOST',     'mail.lynxtechmedia.com');  // or mail.yourdomain.com
define('SMTP_PORT',     465);                         // 465 = SSL, 587 = TLS
define('SMTP_SECURE',   'ssl');                       // 'ssl' or 'tls'
define('SMTP_USERNAME', 'no-reply@lynxtechmedia.com'); // Must be a real inbox on your server
define('SMTP_PASSWORD', 'YOUR_EMAIL_PASSWORD_HERE');  // ← Put your email password here

define('FROM_EMAIL', 'no-reply@lynxtechmedia.com');
define('FROM_NAME',  'DateDash Team');
```

> ⚠️ The `FROM_EMAIL` **must** be a real email account that exists in your cPanel. Create it there first if you haven't already.

### 3. Upload to Server

Upload the entire `php_backend/` folder to:
```
https://lynxtechmedia.com/ronaldstech/snellum/api/emails/php_backend/
```

### 4. Set the URL in Flutter

In `lib/services/email_verification_service.dart`:
```dart
EmailVerificationService.phpApiUrl =
    'https://lynxtechmedia.com/ronaldstech/snellum/api/emails/php_backend/send_verification_code.php';
```

---

## 🧪 Test with cURL / Postman

```bash
curl -X POST https://lynxtechmedia.com/ronaldstech/snellum/api/emails/php_backend/send_verification_code.php \
  -H "Content-Type: application/json" \
  -d '{"email": "liwewejacob265@gmail.com", "code": "123456"}'
```

**Success response:**
```json
{
  "success": true,
  "message": "Verification code sent successfully to liwewejacob265@gmail.com",
  "email": "liwewejacob265@gmail.com"
}
```

**If you get a 500 error**, check that:
- `SMTP_PASSWORD` is correct in `config.php`
- The email account (`no-reply@lynxtechmedia.com`) exists in cPanel
- PHPMailer `src/` files are in the correct path

---

## ❓ Why was the email not arriving before?

PHP's built-in `mail()` returns `true` even when the email is silently dropped by the server. Most shared hosting servers **require** the sender email to be a real account on the server. PHPMailer connects directly via SMTP, authenticates with your credentials, and gives real error messages if something fails.
