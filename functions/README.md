# Snellum Firebase Functions

These Firebase Cloud Functions handle email verification, Agora call tokens, and Sumsub identity verification links/webhooks.

## Setup

Install dependencies from this folder:

```sh
npm install
```

Create the required Firebase secrets:

```sh
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set EMAIL_VERIFICATION_SECRET
firebase functions:secrets:set AGORA_APP_CERTIFICATE
firebase functions:secrets:set SUMSUB_APP_TOKEN
firebase functions:secrets:set SUMSUB_SECRET_KEY
firebase functions:secrets:set SUMSUB_WEBHOOK_SECRET
```

Set the sender address with a Functions environment file. `onboarding@resend.dev` is useful for testing, but production should use a verified Resend domain.

```sh
echo EMAIL_FROM="Snellum <onboarding@resend.dev>" > .env.datedash-35789
```

For local development, you can also create `functions/.env`:

```sh
EMAIL_FROM="Snellum <onboarding@resend.dev>"
SUMSUB_LEVEL_NAME="basic-kyc-level"
SUMSUB_BASE_URL="https://api.sumsub.com"
```

## Sumsub identity verification

Snellum uses Sumsub because it provides a hosted WebSDK verification link, supports government ID and liveness flows, and avoids storing national ID photos directly in the app.

In the Sumsub dashboard:

1. Create an individual verification level for government ID plus liveness.
2. Set `SUMSUB_LEVEL_NAME` to that exact level name.
3. Create an app token/secret pair and save them as `SUMSUB_APP_TOKEN` and `SUMSUB_SECRET_KEY`.
4. Create a webhook pointing to:

```txt
https://us-central1-datedash-35789.cloudfunctions.net/sumsubIdentityWebhook
```

Use the same webhook secret in Sumsub and `SUMSUB_WEBHOOK_SECRET`. Enable user verification webhooks, especially `applicantPending`, `applicantReviewed`, `applicantReset`, and `applicantDeleted`.

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
flutter run --dart-define=IDENTITY_VERIFICATION_API_BASE_URL=http://127.0.0.1:5001/datedash-35789/us-central1
```
