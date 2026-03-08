// ⚠️  IMPORTANT — Read before release
//
// Replace razorpayKeyId with your LIVE key before uploading to Play Store.
// LIVE keys start with: rzp_live_
// TEST keys start with: rzp_test_   ← NOT safe for production
//
// How to get your live key:
//   1. Log in to https://dashboard.razorpay.com
//   2. Settings → API Keys → Generate Live Key
//   3. Paste the key_id below (never the key_secret)
//
// ⚠️  NEVER hardcode razorpayKeySecret in the app.
//     Secrets must only live on your server/backend.
//     Razorpay will flag your account if a secret is found in an APK.

// TODO: Replace with your production key before Play Store upload.
// const String razorpayKeyId = 'rzp_live_XXXXXXXXXXXXXXXX';  // ← PROD key goes here

// Using test key for development only — MUST be swapped before release.
const String razorpayKeyId = String.fromEnvironment(
  'RAZORPAY_KEY_ID',
  defaultValue: 'rzp_live_REPLACE_BEFORE_RELEASE',
);
