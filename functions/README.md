# Snellum Email Verification Functions

These Firebase Cloud Functions send and verify 6-digit signup codes through Resend.

## Setup

Install dependencies from this folder:

```sh
npm install
```

Create the required Firebase secrets:

```sh
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set EMAIL_VERIFICATION_SECRET
```

Set the sender address with a Functions environment file. `onboarding@resend.dev` is useful for testing, but production should use a verified Resend domain.

```sh
echo EMAIL_FROM="Snellum <onboarding@resend.dev>" > .env.datedash-35789
```

For local development, you can also create `functions/.env`:

```sh
EMAIL_FROM="Snellum <onboarding@resend.dev>"
```

Deploy:

```sh
firebase deploy --only functions
```

The Flutter app defaults to:

```txt
https://us-central1-datedash-35789.cloudfunctions.net
```

Override it for emulators or another region with:

```sh
flutter run --dart-define=EMAIL_VERIFICATION_API_BASE_URL=http://127.0.0.1:5001/datedash-35789/us-central1
```
