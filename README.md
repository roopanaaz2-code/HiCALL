# HiCALL

HiCALL is an Android-first communication app with an original, IMO-inspired interface. It is not an IMO clone.

## Included scope

- Email/password registration and sign-in through Supabase Auth
- Username, display-name, and gallery-uploaded profile pictures (JPG/PNG/WebP, up to 5 MB)
- Exact username search and optional, verified private phone lookup
- A personal contact list and direct one-to-one plain-text conversations with Realtime updates
- One-to-one audio/video call screens and call history
- LiveKit room connection, local/remote video rendering, and microphone/camera controls
- Realtime call-session updates so either participant ending a call closes the other participant's call screen
- Screen-awake behavior during active calls and animated slide-to-answer / slide-to-hang-up controls
- Optional per-device incoming ringtone selected from a local audio file while HiCALL is open
- Profile privacy-shield indicator and profile-picture upload/change/remove controls
- Foreground incoming-call prompts using Supabase Realtime, with accept/decline/end actions
- Firebase Cloud Messaging device-token registration and background notification delivery integration
- Notification-tap routing to the relevant incoming call
- Private phone discovery that is explicitly opt-in and owner-controlled
- Custom neon-blue HiCALL brand icon

Out of scope: group chats, voice rooms, social feeds, stories, livestreaming, gifts/coins, random matching, and message attachments.

## Backend

A dedicated Supabase project has been provisioned for HiCALL in `ap-south-1` (Mumbai). The initial schema, row-level security policies, profile-on-signup trigger, and Realtime publication for call participants are applied. Additive migrations add verified-phone discovery, contacts, direct messages, message Realtime, a server-side search limiter, owner-only unverified phone entries, profile-picture storage, call-session Realtime, and per-device FCM tokens.

The `search-users`, `manage-phone`, `call-history`, `call-control`, and `send-incoming-call` Edge Functions are deployed with JWT verification. The `call-control` function checks saved-contact and block relationships before call start/join, issues short-lived LiveKit access tokens, and invokes the FCM sender for incoming calls. The FCM sender validates service-role invocation, reads recipient device tokens server-side, obtains a Google OAuth access token using the Firebase service-account credentials, and sends through the FCM HTTP v1 API.

The following Firebase credentials must remain in Supabase Edge Function secrets only:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

The Firebase Android client configuration is stored at `firebase/google-services.json` and copied into the generated Android project during CI. It is client configuration, not a service-account private key. Never commit the service-account JSON, expose the Supabase service-role key, or place either secret in the Android app.

The deployed `call-control` Edge Function issues short-lived LiveKit access tokens. It requires these protected server-side secrets:

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

These must belong to the dedicated HiCALL LiveKit project. Do not reuse another app's credentials or place LiveKit secrets in the Android app or GitHub source.

A SIM number may also be saved without an SMS code in a separate owner-only table. This entry is explicitly unverified and is never considered by phone search. Phone verification requires phone authentication and a Supabase-compatible SMS provider. Existing verified Auth phone values are kept hidden from discovery unless their owner explicitly enables search.

## Incoming calls: current behavior and limits

- While HiCALL is open, Supabase Realtime displays the incoming-call prompt and the locally selected ringtone can play.
- When HiCALL is backgrounded or its process is removed normally, FCM can display an incoming-call notification. Tapping it opens HiCALL and routes to the matching call.
- Android 13 and newer require the user to grant notification permission. Battery optimization, network state, OEM background restrictions, and notification settings can affect delivery.
- Android does not deliver FCM messages to an app that the user has explicitly force-stopped from system settings until the app is manually opened again.
- The local custom ringtone is currently an in-app/foreground preference. Background FCM notifications use the Android notification sound; a full-screen native call UI and custom background ringtone are not claimed as implemented.
- A successful CI build does not prove real-world push delivery. Test with two signed-in Android devices and verify foreground, background, process-removed, accept, decline, missed-call expiry, and notification-tap behavior.

## Email confirmation deep link

HiCALL sends Supabase signup confirmation emails back to the Android app using
`hicall://auth-callback`. The Android build registers this scheme/host and
`supabase_flutter` processes the returned auth callback to establish the verified
session. In Supabase Dashboard, add the exact URL
`hicall://auth-callback` under Authentication > URL Configuration > Redirect URLs.
Keep email confirmations enabled. Do not set the Site URL or email redirect to
`http://localhost:3000` for this Android app.

## Android CI

The GitHub Actions workflow `.github/workflows/android-ci.yml` generates Android platform files, configures Firebase, uses Google's Maven Central mirror to reduce HTTP 429 failures, analyzes and tests the Flutter code, and builds debug and release-variant APK artifacts. Build steps retry transient dependency/network failures. The release-variant artifact uses the generated Android project's debug signing configuration unless a private release keystore is configured; it is suitable for installation/testing, not Play Store production signing. Configure a private upload keystore through GitHub Actions secrets before publishing.

## Quality gates

A successful compile is not proof that calling works. Before a production release, test with at least two real Android devices and separate accounts:

1. Sign-up, email confirmation, sign-in, and session expiry
2. Username uniqueness and profile privacy
3. Audio/video permissions, denial, and recovery
4. Real two-way audio and video on separate networks
5. Incoming call, accept, decline, hang-up, and simultaneous calls
6. Bluetooth, speaker, earpiece, mute, camera switch, and echo handling
7. Wi-Fi/mobile-data changes, weak network, reconnect, and cleanup
8. Background FCM delivery, notification permission, tap-to-answer, and Android force-stop limitation
9. Database RLS, block enforcement, abuse controls, and server-side authorization
10. APK installation and regression checks on supported Android versions

Do not describe an APK as production-ready until these tests pass.
