/// Central configuration for every external URL used across the app.
///
/// Edit a value here and it applies to every file that references it.
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // Media / image upload endpoints
  // ---------------------------------------------------------------------------

  /// Profile photo upload endpoint (used by the profile wizard and the
  /// edit-profile screen).
  static const String profileImageUploadUrl =
      'https://lynxtechmedia.com/ronaldstech/snellum/api/upload.php';

  /// Chat image / voice upload endpoint.
  static const String chatMediaUploadUrl =
      'https://lynxtechmedia.com/ronaldstech/snellum/api/upload2.php';

  // ---------------------------------------------------------------------------
  // Payment backend bridge (PayChangu)
  // ---------------------------------------------------------------------------

  static const String payChanguBaseUrl =
      'https://lynxtechmedia.com/ronaldstech/snellum/api/paychangu';

  static const String payChanguOperatorsUrl =
      '$payChanguBaseUrl/get_operators.php';
  static const String payChanguInitializeUrl =
      '$payChanguBaseUrl/initialize_payment.php';
  static const String payChanguVerifyUrl =
      '$payChanguBaseUrl/verify_payment.php';

  // ---------------------------------------------------------------------------
  // Telcomw SMS API & Custom Auth Token
  // ---------------------------------------------------------------------------

  /// Telcomw SMS API endpoint
  static const String telcomApiUrl = 'https://telcomw.com/api-v2/send';

  /// Telcomw API Key
  static const String telcomApiKey = String.fromEnvironment(
    'TELCOM_API_KEY',
    defaultValue: '',
  );

  /// Telcomw Password
  static const String telcomApiPassword = String.fromEnvironment(
    'TELCOM_API_PASSWORD',
    defaultValue: '',
  );

  /// Telcomw Sender ID
  static const String telcomSenderId = 'WGIT';

  /// Server endpoint to generate a Firebase Custom Token for verified UID
  static const String firebaseCustomTokenUrl = String.fromEnvironment(
    'FIREBASE_CUSTOM_TOKEN_URL',
    defaultValue:
        'https://lynxtechmedia.com/ronaldstech/snellum/api/custom_token.php',
  );

  // ---------------------------------------------------------------------------
  // Email verification backends
  // ---------------------------------------------------------------------------

  /// Hosting-server PHP fallback for sending verification codes.
  static const String emailVerificationPhpUrl =
      'https://apexspacemw.com/rt/php_backend/send_verification_code.php';

  /// Snellum Cloud Functions region base URL.
  static const String snellumCloudFunctionsUrl =
      'https://us-central1-snellum.cloudfunctions.net';

  /// Identity verification Cloud Functions region base URL.
  static const String datedashCloudFunctionsUrl =
      'https://us-central1-datedash-35789.cloudfunctions.net';

  /// Brevo (Sendinblue) Transactional API v3 endpoint.
  static const String brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';

  // ---------------------------------------------------------------------------
  // App update
  // ---------------------------------------------------------------------------

  /// Default Android APK download URL.
  static const String appApkDownloadUrl =
      'https://unimarket-mw.com/snellum/snellum.apk';

  // ---------------------------------------------------------------------------
  // Calls
  // ---------------------------------------------------------------------------

  /// Default Jitsi Meet server.
  static const String jitsiServerBase = 'https://meet.ffmuc.net';

  // ---------------------------------------------------------------------------
  // IP geolocation
  // ---------------------------------------------------------------------------

  static const String ipApiUrl = 'http://ip-api.com/json';
  static const String ipApiCoUrl = 'https://ipapi.co/json/';

  // ---------------------------------------------------------------------------
  // Referral links
  // ---------------------------------------------------------------------------

  static const String referralUrlPrefix = 'https://snellum.app/join?ref=';

  // ---------------------------------------------------------------------------
  // Placeholder imagery
  // ---------------------------------------------------------------------------

  /// Fallback avatar used when a profile has no photos.
  static const String defaultProfileImageUrl =
      'https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800';

  /// Explore category tile photos (same order as the categories on the
  /// explore screen).
  static const List<String> exploreCategoryPhotos = [
    'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?w=600&q=80',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=600&q=80',
    'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=600&q=80',
    'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600&q=80',
    'https://images.unsplash.com/photo-1536697246787-1f7ae568d89a?w=600&q=80',
    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=600&q=80',
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&q=80',
    'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600&q=80',
  ];
}
