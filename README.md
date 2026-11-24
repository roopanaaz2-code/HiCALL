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
- Optional per-device incoming ringtone selected from a local audio file (while the app is open)
- Profile privacy-shield indicator and existing profile-picture upload/change/remove controls
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

- Incoming-call prompts and the selected custom ringtone work while the app is open and connected to Realtime. Background/terminated-app alerts still require Firebase Cloud Messaging, a Firebase Android app configuration, secure FCM sender credentials, and Android call-notification integration. These are not configured in this repository yet.
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


## Remote configuration (Supabase)

HiCALL reads JSON-only settings from `public.app_remote_config` at startup. If the request times out or Supabase is unreachable, local defaults remain in use and startup continues. The table grants read-only access to the app's public client roles under RLS; app clients cannot insert, update, or delete configuration. Never store credentials, private URLs, service-role keys, or executable code in this table.

To change a setting, use the Supabase SQL editor as a project administrator. Example:

```sql
update public.app_remote_config
set config_value = 'true'::jsonb, updated_at = now()
where config_key = 'maintenance_mode';

update public.app_remote_config
set config_value = '"Scheduled maintenance is in progress."'::jsonb,
    updated_at = now()
where config_key = 'announcement_text';
```

Current keys include `maintenance_mode`, `announcement_enabled`, `announcement_text`, `minimum_supported_version`, `feature_calls_enabled`, `feature_video_enabled`, and `feature_chat_enabled`. The app shell currently applies the maintenance and announcement settings; the feature flags are exposed through `RemoteConfigService` for feature screens to consume, but are not yet wired to disable individual screens. The minimum-version value is informational and is not yet an enforced upgrade gate. Values are exposed to the client and must be treated as public. Remote configuration changes values/flags only; it cannot add new Dart behavior by itself.

## Shorebird Code Push (Android)

Shorebird patches can update Dart code for an app installed from a Shorebird-enabled release. Existing APKs built with ordinary `flutter build` are not patchable; users must install the first Shorebird release APK once. Later Dart-only patches download in the background and take effect after the app is restarted. Native Android/plugin changes, manifest/permission changes, Gradle changes, Flutter engine upgrades, and bundled asset/image/font changes require a new signed APK.

### One-time setup

1. Create a Shorebird API key in the Shorebird Console and add it to GitHub repository Actions secrets as `SHOREBIRD_TOKEN`.
2. From GitHub Actions, run **HiCALL Shorebird Initialization** on `main`. If your Shorebird account has multiple organizations, supply the correct organization ID. The workflow creates the app ID and opens a PR with the generated `shorebird.yaml` and `pubspec.yaml` asset entry. Review and merge that PR; do not invent or copy another app's app ID.
3. Create one Android upload keystore and keep a secure offline backup. The same keystore must be used for this initial APK and all later full APK upgrades. Do not commit it.
4. Add these GitHub repository Actions secrets under Settings → Secrets and variables → Actions:
   - `SHOREBIRD_TOKEN` — Shorebird API key
   - `ANDROID_KEYSTORE_BASE64` — base64-encoded keystore file
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
5. The initial release workflow currently pins Flutter 3.50.1; keep that baseline for patches to this release. After the Shorebird app ID and secrets are ready and this change is merged to `main`, manually run **HiCALL Shorebird Initial Release**. It runs only from `main` and uploads a Shorebird-enabled APK artifact. Test/install that APK; it replaces the old non-Shorebird build.

### Publishing a Dart patch

After the initial Shorebird APK is installed by users, merge a tested Dart-only change to `main`, then manually run **HiCALL Shorebird Patch**. Enter the exact installed release version (currently `1.0.0+1`) and choose `staging` first. Test with a staging device, then publish to `stable` only after validation. Shorebird itself checks for native/asset changes and can reject an unsafe patch. Never use the patch workflow for native Android, plugin, permission, Gradle, or asset changes.

The release and patch workflows deliberately require the same persistent Android signing secrets. This keeps future full APK upgrades compatible with the first distributed APK. A CI success or uploaded patch is not a substitute for real-device call, notification, and upgrade testing.
