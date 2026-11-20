# HiCALL

HiCALL is an Android-first app focused only on secure audio and video calling.

## Included scope

- Email/password registration and sign-in through Supabase Auth
- Username and display-name profiles
- Search for other registered users
- One-to-one audio and video call setup
- LiveKit room connection and microphone/camera controls
- Foreground incoming-call prompts using Supabase Realtime
- Accept, decline, and end call actions
- Database foundations for call history, blocking, and user reports
- Custom neon-blue HiCALL brand icon

Out of scope: chat rooms, voice rooms, social feeds, stories, livestreaming, gifts, coins, battles, random matching, and unrelated social features.

## Backend

A dedicated Supabase project has been provisioned for HiCALL in `ap-south-1` (Mumbai). The initial schema, row-level security policies, profile-on-signup trigger, and Realtime publication for call participants are applied.

The deployed `call-control` Edge Function verifies the user's Supabase session, checks block relationships, creates call records, and issues short-lived LiveKit access tokens. It requires these server-side secrets before call setup can work:

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

These must belong to a separate HiCALL LiveKit project. Never reuse NightLink's credentials and never place LiveKit secrets or the Supabase service-role key in the Android app or GitHub source.

## Current implementation limits

- Incoming-call prompts currently work only while the app is open and connected to Realtime. Background/terminated-app incoming calls still need Firebase Cloud Messaging and Android call-notification integration.
- The current UI supports direct one-to-one calls. Group calling, call history UI, profile editing, block/report UI, and full Android audio-routing/foreground-service handling remain to be implemented.
- The current call screen connects to LiveKit and toggles local microphone/camera. Remote video rendering and robust call-state recovery still need implementation and device testing.
- The call service returns a configuration error until the HiCALL LiveKit secrets are installed.

## Android CI

The GitHub Actions workflow `.github/workflows/android-ci.yml` formats, analyzes, tests, and builds both debug and release-variant APK artifacts. The release-variant artifact uses the generated Android project's debug signing configuration unless a private release keystore is configured; it is suitable for installation/testing but is not a Play Store production-signed release. Configure a private upload keystore through GitHub Actions secrets before publishing.

## Quality gates

A successful compile is not proof that calling works. Before a production release, test with at least two real Android devices and separate accounts:

1. Sign-up, email confirmation, sign-in, and session expiry
2. Username uniqueness and profile privacy
3. Audio/video permissions, denial, and recovery
4. Real two-way audio and video on separate networks
5. Incoming call, accept, decline, hang-up, and simultaneous calls
6. Bluetooth, speaker, earpiece, mute, camera switch, and echo handling
7. Wi-Fi/mobile-data changes, weak network, reconnect, and cleanup
8. Background/terminated incoming-call delivery and Android 13+ notifications
9. Database RLS, block enforcement, abuse controls, and server-side authorization
10. APK installation and regression checks on supported Android versions

Do not describe an APK as production-ready until these tests pass.
