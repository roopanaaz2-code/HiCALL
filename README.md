# HiCALL

HiCALL is an Android-first communication app with an original, IMO-inspired interface. It is not an IMO clone.

## Included scope

- Email/password registration and sign-in through Supabase Auth
- Username, display-name, and gallery-uploaded profile pictures (JPG/PNG/WebP, up to 5 MB)
- Exact username search and optional, verified private phone lookup
- A personal contact list and direct one-to-one plain-text conversations with Realtime updates
- One-to-one audio/video call screens and call history
- LiveKit room connection, local/remote video rendering, and microphone/camera controls
- Foreground incoming-call prompts using Supabase Realtime, with accept/decline/end actions
- Private phone discovery that is explicitly opt-in and owner-controlled
- Custom neon-blue HiCALL brand icon

Out of scope: group chats, voice rooms, social feeds, stories, livestreaming, gifts/coins, random matching, and message attachments.

## Backend

A dedicated Supabase project has been provisioned for HiCALL in `ap-south-1` (Mumbai). The initial schema, row-level security policies, profile-on-signup trigger, and Realtime publication for call participants are applied. The additive migrations add verified-phone discovery, contacts, direct messages, message Realtime, a server-side search limiter, an owner-only unverified phone-entry table, and profile-picture storage.

The `search-users`, `manage-phone`, and `call-history` Edge Functions are deployed with JWT verification. `call-control` is deployed at version 2 and checks saved-contact and block relationships before call start/join. These functions validate the user's Supabase session, limit phone searches, and keep service-role access server-side.

A SIM number may also be saved without an SMS code in a separate owner-only table. This entry is explicitly unverified and is never considered by phone search. Phone verification will not work until the project administrator enables phone authentication and configures a Supabase-compatible SMS provider. Existing verified Auth phone values are kept hidden from discovery unless their owner explicitly enables search. Supabase Auth may retain a phone value for account-security use when the owner pauses HiCALL lookup.

The deployed `call-control` Edge Function issues short-lived LiveKit access tokens. It requires these protected server-side secrets before calling can work:

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

These must belong to a separate HiCALL LiveKit project. LiveKit Cloud offers a free Build tier, but RTC use is metered and allowances are capped; verify current limits in the project dashboard. Until the administrator creates/configures that project and sets all three secrets, the call endpoint returns HTTP 503. Never reuse NightLink's credentials and never place LiveKit secrets or the Supabase service-role key in the Android app, chat, or GitHub source.

## Incoming calls and device readiness

- Incoming-call prompts work only while the app is open and connected to Realtime. Background/terminated-app alerts require Firebase Cloud Messaging and Android call-notification integration, which remain deferred.
- LiveKit calling cannot be claimed as functional until all three secrets are installed and calls are tested between two Android devices on separate networks.

## Email confirmation deep link

HiCALL sends Supabase signup confirmation emails back to the Android app using
`hicall://auth-callback`. The Android build registers this scheme/host and
`supabase_flutter` processes the returned auth callback to establish the verified
session. In Supabase Dashboard, add the exact URL
`hicall://auth-callback` under Authentication > URL Configuration > Redirect URLs.
Keep email confirmations enabled. Do not set the Site URL or email redirect to
`http://localhost:3000` for this Android app.

## Android CI

The GitHub Actions workflow `.github/workflows/android-ci.yml` generates Android platform files, formats, analyzes, tests, and builds debug and release-variant APK artifacts. The release-variant artifact uses the generated Android project's debug signing configuration unless a private release keystore is configured; it is suitable for installation/testing, not Play Store production signing. Configure a private upload keystore through GitHub Actions secrets before publishing.

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
