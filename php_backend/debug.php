<?php
/**
 * DateDash - SMTP Debug Tool
 * Open in browser to diagnose SMTP connection.
 * DELETE THIS FILE after debugging!
 */
require_once __DIR__ . '/config.php';

echo '<pre style="font-family:monospace;background:#111;color:#0f0;padding:20px;font-size:14px;">';
echo "=== DateDash SMTP Debug ===\n\n";

echo "PHP Version: " . phpversion() . "\n";
echo "Server:      " . ($_SERVER['SERVER_SOFTWARE'] ?? 'unknown') . "\n\n";

echo "--- Current Config ---\n";
echo "SMTP_HOST:   " . SMTP_HOST . "\n";
echo "SMTP_PORT:   " . SMTP_PORT . "\n";
echo "SMTP_SECURE: " . (SMTP_SECURE ?: '(none)') . "\n";
echo "SMTP_AUTH:   " . ((defined('SMTP_AUTH') && SMTP_AUTH) ? 'true' : 'false') . "\n";
echo "FROM_EMAIL:  " . FROM_EMAIL . "\n\n";

echo "--- PHPMailer Check ---\n";
$phpmailerPath = __DIR__ . '/phpmailer/src/PHPMailer.php';
echo "PHPMailer: " . (file_exists($phpmailerPath) ? "✅ Installed" : "❌ Not found — download from github.com/PHPMailer/PHPMailer/releases") . "\n\n";

echo "--- Socket Connection Tests ---\n";

$tests = [
    ['host' => 'localhost',              'prefix' => '',       'port' => 25,  'label' => 'localhost:25 (cPanel standard, no auth)'],
    ['host' => 'mail.apexspacemw.com', 'prefix' => '',       'port' => 587, 'label' => 'mail.apexspacemw.com:587 (TLS)'],
    ['host' => 'mail.apexspacemw.com', 'prefix' => 'ssl://', 'port' => 465, 'label' => 'mail.apexspacemw.com:465 (SSL)'],
];

$workingConfig = null;
foreach ($tests as $test) {
    $target = $test['prefix'] . $test['host'];
    $fp = @fsockopen($target, $test['port'], $errno, $errstr, 5);
    if ($fp) {
        echo "✅ " . $test['label'] . "\n";
        if (!$workingConfig) $workingConfig = $test;
        fclose($fp);
    } else {
        echo "❌ " . $test['label'] . " → [$errno] $errstr\n";
    }
}

echo "\n--- Recommendation ---\n";
if ($workingConfig) {
    $rec = $workingConfig;
    if ($rec['host'] === 'localhost') {
        echo "✅ Use OPTION A in config.php (localhost:25, no auth) — already set!\n";
    } else {
        echo "Use OPTION B in config.php:\n";
        echo "  SMTP_HOST: " . $rec['host'] . "\n";
        echo "  SMTP_PORT: " . $rec['port'] . "\n";
        echo "  SMTP_SECURE: " . ($rec['port'] == 465 ? 'ssl' : 'tls') . "\n";
    }
} else {
    echo "❌ No SMTP port is reachable. Contact your hosting provider.\n";
}

// Quick send test using PHP mail()
echo "\n--- PHP mail() Test ---\n";
$testSent = @mail(FROM_EMAIL, 'DateDash Debug Test', 'Test from debug.php', 'From: ' . FROM_EMAIL);
echo "mail() returned: " . ($testSent ? "✅ true (check your inbox at " . FROM_EMAIL . ")" : "❌ false") . "\n";

echo "\n=== End Debug ===\n";
echo '<span style="color:red">⚠ DELETE debug.php from your server after debugging!</span>';
echo '</pre>';
