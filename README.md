# HiCALL

HiCALL is an Android-first calling app. Its scope is deliberately limited to communication calls.

## Product scope

- Secure account registration and sign-in
- User profile and username lookup
- One-to-one audio and video calls
- Group audio and video calls
- Incoming-call accept/decline notifications
- In-call microphone, camera, speaker, and camera-switch controls
- Call history and missed-call records
- Block/report controls
- Network-quality handling and call reconnection

Out of scope: chat rooms, voice rooms, social feeds, stories, livestreaming, gifts, coins, battles, random matching, and unrelated social features.

## Engineering approach

- Flutter Android client
- LiveKit/WebRTC-based real-time media with encrypted transport
- Authenticated server-side call signalling and authorization
- No API secrets embedded in the mobile application
- Database row-level security for user and call records
- Push notifications must contain only the minimum information needed to route an incoming call
- Runtime permissions requested only when the relevant call feature is used

The media provider and backend must be configured with a dedicated HiCALL project. Credentials from another app must not be copied into this repository.

## Quality gates

A release is not considered ready merely because it compiles. Before calling a build production-ready, verify:

1. Registration, login, logout, and session expiry
2. Permission denial and later permission recovery
3. Real audio and video between two separate devices/accounts
4. Incoming calls while foregrounded and backgrounded
5. Accept, decline, hang up, mute, speaker routing, and camera switching
6. Wi-Fi/mobile-data changes, weak networks, reconnect, and call cleanup
7. Group-call participant limits and media behavior
8. Block/report authorization and database access policies
9. Android installation, launch, and regression checks

## Current status

Repository initialized with the product scope and implementation/security gates. App source, backend configuration, and release workflow are not yet present. Do not treat this repository as a working calling app until the above functionality is implemented and tested.

## Build prerequisites

A dedicated HiCALL backend/media project and its public client configuration are required. Private signing keys and server secrets must be stored in GitHub Actions secrets or the backend secret store, never committed to source control.
