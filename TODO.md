# HiCALL first-release outcomes

## Communication-app navigation and visual redesign
- [ ] The app presents an original, polished communication interface with familiar IMO-like navigation, not IMO logos, artwork, or a pixel-for-pixel copy.
- [ ] The app provides Chats, Contacts, Calls, and Me/Profile destinations, profile avatars, readable conversation/contact rows, search and add-contact actions, and visible audio/video calling controls.
- [ ] The interface supports a light presentation with HiCALL cyan/blue accents and a matching dark theme, with accessible readable states and clear actions.

## Profile pictures
- [ ] A signed-in user can pick a picture from the Android gallery, upload it as their HiCALL profile photo, and change it later without leaving the app.
- [ ] The app saves only the object path in `profiles.avatar_path`; avatar uploads are limited in size and supported image types, and the public URL is created from the HiCALL Storage bucket.
- [ ] Storage policies restrict upload and deletion to the authenticated user's UUID folder; public profile photos are readable by other HiCALL users, and the UI explains this visibility.
- [ ] The current photo appears in the owner's profile and in public profile surfaces such as search results, contacts, chats, and call surfaces, with initials as a fallback when no photo exists or loading fails.

## Private SIM number and safe contact discovery
- [ ] A signed-in user can add, view, change, and remove their own SIM number in their profile without receiving or entering an SMS code.
- [ ] A no-code number is clearly labeled unverified, stored outside public profile fields, and readable only by its owner; it is never represented as verified or used for search.
- [ ] Adding a no-code private number does not change whether a separate verified Auth number is searchable; Supabase Auth's account-security phone value is not erased by removing a HiCALL discovery entry.
- [ ] Exact phone-number or username search and an explicit Add Contact action are provided; phone input is normalized to international format.
- [ ] A phone number becomes searchable only after SMS OTP verification and explicit owner opt-in; unverified numbers are not searchable through the public client.
- [ ] Phone search returns only a public profile preview and never the queried number; the UI explains that an exact registered number can reveal that an account exists.
- [ ] Phone lookup is authenticated, server-side, rate-limited, and respects block relationships.
- [ ] SMS verification uses a Supabase-compatible SMS provider configured outside source control; until configured, the UI must not claim that phone verification or number lookup is live.

## One-to-one text messaging
- [ ] A user can open a direct one-to-one conversation with an added contact and send plain text messages.
- [ ] Conversations show message history, timestamps, loading/delivery/error states, and Realtime updates.
- [ ] Database access uses RLS so only conversation participants can read or send messages; group chats, stories, livestreaming, gifts/coins, random matching, and media attachments are outside this first release.

## One-to-one audio and video calling
- [ ] A user can start an audio or video call with a contact, see ringing/connecting/connected states, accept or decline an incoming call while HiCALL is open, and end the call.
- [ ] The active call screen provides call duration/status, microphone and camera controls, local and remote video surfaces, and reconnect/error handling.
- [ ] Call tokens and LiveKit secrets remain server-side; the existing `call-control` Edge Function issues short-lived tokens only to authorized participants.
- [ ] The HiCALL Supabase Edge Function has `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` set as protected secrets before live calling is claimed as functional; free-plan quotas and their hard caps are disclosed.
- [ ] Calls respect block relationships and are tested between two Android devices and networks before production readiness is claimed.
- [ ] Background/terminated-app incoming-call alerts are deferred until Firebase Cloud Messaging and Android notification configuration are supplied; current Realtime ringing is foreground-only.

## Installable APK and readiness disclosure
- [ ] The existing Flutter project and Supabase accounts are preserved; schema additions are additive and protect existing data.
- [ ] Android permissions, authentication deep-link `hicall://auth-callback`, and CI build behavior continue to work.
- [ ] The repository CI builds an installable Android release-variant APK after the available checks pass.
- [ ] The APK is described as a test build, not production-ready, until live OTP, two-device calling, privacy, and incoming-call behavior are verified; production signing requires a private release keystore.
