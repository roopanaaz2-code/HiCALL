# HiCALL first-release plan

## Goal and scope

Turn the current small Flutter calling MVP into an original, polished communication app with a familiar IMO-like information architecture, while keeping HiCALL's identity and not copying IMO branding, assets, or exact screens. Preserve the existing Supabase email/password accounts and Android email-confirmation deep link.

### First-release outcomes

1. **Communication-app navigation and visual redesign.** Provide a clean, familiar app shell with Chats, Contacts, Calls, and Me/Profile destinations; consistent profile avatars, readable conversation/contact rows, clear search and add-contact actions, and visible audio/video call controls. Support a polished light presentation with HiCALL cyan/blue accents and a matching dark theme. Keep the design accessible, fast, and original rather than a pixel-for-pixel IMO copy.
2. **Private phone number on profile.** Let each signed-in user add and manage their own SIM number in their profile. Store it outside public profile fields and restrict direct database access to that user. Never return or display the number in another user's profile, contact card, chat, or call screen.
3. **Safe number discovery and contact adding.** Allow exact phone-number or username search and an explicit Add Contact action. Normalize phone input to international format. Require SMS OTP verification before a phone number can be enabled for search, to prevent claiming another person's number, and keep discovery off until the owner explicitly enables it. A successful lookup returns only a public profile preview, never the phone number. The app will make it clear that searching an exact registered number can reveal that an account exists; use authentication, server-side rate limiting, and block checks.
4. **Direct messaging.** Add one-to-one text conversations with message history, timestamps, delivery/loading/error states, and Supabase Realtime updates. Do not include media attachments, group chats, stories, coins, livestreaming, or random matching in this first release.
5. **One-to-one audio and video calls.** Complete the direct call journey: outgoing/ringing state, incoming call prompt while the app is open, accept/decline/end, call duration/status, microphone and camera controls, local and remote video surfaces, reconnect/error handling, and call history. Keep LiveKit API secrets server-side; use short-lived tokens from the existing call-control Edge Function.
6. **Installable APK and honest readiness status.** Build an installable Android release-variant APK through the repository's CI workflow after code and available automated checks pass. Do not label it production-ready until real calls and privacy behavior have been tested on two Android devices with configured services. The current workflow's APK is test-signed unless a private release keystore is configured.

### Explicit dependencies and limits

- **LiveKit:** the existing `call-control` function returns a configuration error until `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` are set as protected Supabase Edge Function secrets. They must be entered directly in Supabase, never committed to Git or pasted into chat.
- **Phone verification:** searchable phone numbers require a Supabase-compatible SMS provider and its credentials. SMS delivery can have provider charges and country restrictions. If no SMS provider is configured, the UI can be implemented, but phone verification/discovery cannot be called live or secure.
- **Background incoming calls:** current incoming-call listening works only while HiCALL is open. Ringing while backgrounded or terminated needs Firebase Cloud Messaging and Android notification configuration; this requires a Firebase project/config from the owner. This is a follow-on setup unless those details are available for the first release.
- **Lookup privacy:** keeping a number hidden does not make number-based discovery anonymous; an authenticated person who enters the exact number may learn whether a HiCALL profile matches. Never expose the number itself, and throttle repeated searches.
- **No secret sharing in chat:** provider keys, app passwords, SMS credentials, and keystore passwords must be entered directly into their secure provider settings.

## Implementation approach

Keep the existing Flutter Android project and Supabase project; do not re-platform or replace the user's repository. Extend the current Flutter screens and services, add database migrations for private phone records, contacts, and direct message data with RLS, and use authenticated Edge Functions for phone lookup and rate-limited server-side actions. Continue using the existing server-mediated LiveKit call flow. Update the Android CI workflow only as needed for permissions, notification integration, and APK artifacts. Apply any database migration additively and preserve existing accounts, call records, and email-confirmation settings.

## Project structure

- `lib/app.dart`: app theme, authenticated navigation shell, and route selection.
- `lib/screens/`: authentication, chats, contacts/search, call history, profile/phone management, conversation, and active call screens.
- `lib/services/`: existing auth/call/profile services plus contact lookup, phone verification, and messaging services.
- `lib/config/`: Supabase project URL, publishable key, app identity, and email-confirmation deep-link constants.
- `supabase/migrations/`: additive private-phone, contact, and messaging schema, indexes, RLS policies, and grants.
- `supabase/functions/`: authenticated `search-users`, owner-only `manage-phone`, sanitized `call-history`, and the server-mediated `call-control` function.
- Generated `android/` platform files and `.github/workflows/android-ci.yml`: Android deep-link/permissions configuration and test APK build.
- `test/`: extend unit/widget tests for navigation, phone handling, and user-visible states.

## Design system

- **Design movement:** familiar, lightweight mobile messaging and calling UX, reinterpreted as HiCALL rather than copied.
- **Core principles:** conversation-first; phone privacy made understandable; one-tap calling; calm, readable states and accessibility.
- **Color philosophy:** airy neutral surfaces in light mode and deep navy in dark mode, with HiCALL cyan as a focused accent for calls and active states; red reserved for destructive/end-call actions.
- **Layout paradigm:** bottom navigation around Chats, Contacts, Calls, and Me; conversation-centric lists with compact avatars; prominent but uncluttered search and add-contact affordances.
- **Signature elements:** original cyan call-action treatment; clear audio/video icons; a subtle HiCALL waveform/ring motif.
- **Interaction and motion:** immediate tap feedback, restrained transitions, clear ringing/connected/reconnecting states, no decorative motion that obscures call controls.
- **Typography:** system sans-serif with clear title/body/caption hierarchy, large readable call status, and consistent spacing.
- **Brand essence:** private, dependable calls for people who want simple connections; personality: clear, warm, trustworthy.
- **Brand voice:** short, direct, reassuring. Examples: “Find people by username or number” and “Your number stays private.”
- **Wordmark and logo:** retain the existing HiCALL name/icon and refine its placement; do not use IMO logos or artwork.

## Project-specific facts

The repository is Flutter, and Supabase Auth signup plus `hicall://auth-callback` are wired. The additive migration now provides owner-only phone records, contacts, direct conversations, messages, rate limiting, and RLS. The three discovery/history functions are active, and `call-control` is deployed with saved-contact and block checks. SMS provider setup and the three protected LiveKit secrets remain prerequisites for live OTP and calls. Incoming-call Realtime handling is foreground-only; background delivery is deferred pending Firebase configuration.
